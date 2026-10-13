import AppKit
import CMpv
import Combine
import IOKit.pwr_mgt
import SwiftUI
import UniformTypeIdentifiers
#if SWIFT_PACKAGE
import ValenControl
#endif

@MainActor
final class PlayerModel: ObservableObject {
    @Published var currentFile: URL?
    @Published var isPaused = true
    @Published var position: Double = 0
    @Published var duration: Double = 0
    @Published var volume: Double = AppPreferences.defaultVolume
    @Published var audioTracks: [MediaTrack] = []
    @Published var subtitleTracks: [MediaTrack] = []
    @Published var selectedAudioID: Int?
    @Published var selectedSubtitleID: Int?
    @Published var debugLines: [String] = []
    @Published var isDebugVisible = false
    @Published var isFullscreen = false
    @Published var errorMessage: String?
    @Published private(set) var loadedExternalSubtitle: URL?

    private let mpv = MPVClient()
    private let playbackStateStore = PlaybackStateStore()
    private var timer: Timer?
    private var keyMonitor: Any?
    private var pollCount = 0
    private var pendingRestoreState: SavedPlaybackState?
    private var pendingSiblingSubtitle: URL?
    private var didApplyRestoreState = false
    private weak var hostView: MPVHostView?
    private var playbackActivity: NSObjectProtocol?
    private var displaySleepAssertionID = IOPMAssertionID(0)

    var hasError: Binding<Bool> {
        Binding(
            get: { self.errorMessage != nil },
            set: { if !$0 { self.errorMessage = nil } }
        )
    }

    var positionText: String {
        Self.formatTime(position)
    }

    var durationText: String {
        Self.formatTime(duration)
    }

    init() {
        AppPreferences.registerDefaults()
        volume = AppPreferences.defaultVolume

        do {
            try mpv.initialize()
            try mpv.setDouble("volume", value: volume)
            try mpv.setFlag("sub-visibility", value: true)
            try mpv.setString("sub-ass", value: "yes")
            try mpv.setString("embeddedfonts", value: "yes")
            log("Initialized mpv.")
            startPolling()
            startKeyboardShortcuts()
        } catch {
            errorMessage = error.localizedDescription
            log("Initialize failed: \(error.localizedDescription)")
        }
    }

    func attach(to view: MPVHostView) {
        guard hostView !== view else { return }
        hostView = view
        mpv.attachDrawable(view)
        updateMainWindowTitle()
    }

    /// The single player window hosting the mpv surface, if attached.
    var mainWindow: NSWindow? {
        hostView?.window
    }

    /// Bring the single player window forward (used for Finder open, MCP, dock reopen).
    func activateMainWindow() {
        NSApp.activate()
        if let window = mainWindow {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
        } else if let window = NSApp.windows.first(where: { $0.canBecomeKey && !$0.isSheet }) {
            window.makeKeyAndOrderFront(nil)
        }
        updateMainWindowTitle()
    }

    func updateMainWindowTitle() {
        mainWindow?.title = SinglePlayerPolicy.windowTitle(for: currentFile)
    }

    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = SupportedMediaTypes.contentTypes

        if panel.runModal() == .OK, let url = panel.url {
            load(url)
        }
    }

    func openSubtitleFilePanel() {
        guard currentFile != nil else {
            errorMessage = "Open a video before loading a subtitle file."
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = SupportedSubtitleTypes.contentTypes
        panel.prompt = "Load"

        if panel.runModal() == .OK, let url = panel.url {
            loadExternalSubtitle(url)
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }

            guard let url else { return }
            Task { @MainActor in
                guard let self else { return }
                switch SinglePlayerPolicy.openIntent(for: [url], hasCurrentFile: self.currentFile != nil) {
                case .loadMedia(let mediaURL):
                    self.load(mediaURL)
                case .loadSubtitle(let subtitleURL):
                    self.loadExternalSubtitle(subtitleURL)
                case .none:
                    break
                }
            }
        }

        return true
    }

    func load(_ url: URL) {
        savePlaybackState()

        let restoreState = AppPreferences.resumePlayback ? playbackStateStore.state(for: url) : nil
        let shouldTrySibling = AppPreferences.autoLoadMatchingSubtitle && {
            guard let state = restoreState else { return true }
            return state.externalSubtitlePath == nil
                && state.subtitleTrackID == nil
                && !state.subtitlesOff
        }()
        let siblingSubtitle = shouldTrySibling
            ? SupportedSubtitleTypes.matchingSubtitleURL(for: url)
            : nil

        log("Loading file: \(url.path)")
        if let restoreState {
            log("Found saved state: position=\(restoreState.position), audio=\(restoreState.audioTrackID.map(String.init) ?? "auto"), subtitle=\(restoreState.subtitleDescription), volume=\(restoreState.volume)")
        }

        do {
            mpv.noteLoadStarted()
            try mpv.command(["loadfile", url.path])
            try mpv.setFlag("pause", value: false)

            currentFile = url
            isPaused = false
            audioTracks = []
            subtitleTracks = []
            selectedAudioID = nil
            selectedSubtitleID = nil
            loadedExternalSubtitle = nil
            pendingRestoreState = restoreState
            pendingSiblingSubtitle = siblingSubtitle
            didApplyRestoreState = false
            updateMainWindowTitle()
            updatePlaybackActivity()
        } catch {
            errorMessage = error.localizedDescription
            log("Load failed: \(error.localizedDescription)")
            isPaused = mpv.getFlag("pause") ?? true
            updatePlaybackActivity()
        }
    }

    func toggleFullscreen() {
        guard let window = hostView?.window ?? NSApp.keyWindow ?? NSApp.mainWindow else {
            log("Fullscreen toggle ignored: no active window.")
            return
        }

        log(window.styleMask.contains(.fullScreen) ? "Exiting fullscreen." : "Entering fullscreen.")
        window.toggleFullScreen(nil)
    }

    func togglePlayPause() {
        guard currentFile != nil else {
            isPaused = true
            return
        }

        setPaused(!isPaused)
    }

    func setPaused(_ paused: Bool) {
        guard currentFile != nil else {
            isPaused = true
            return
        }

        do {
            isPaused = paused
            try mpv.setFlag("pause", value: paused)
            updatePlaybackActivity()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func seek(relativeSeconds: Double) {
        guard currentFile != nil else { return }

        do {
            try mpv.command(["seek", String(relativeSeconds), "relative"])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scrub(to seconds: Double) {
        guard currentFile != nil else { return }

        position = seconds
        do {
            try mpv.command(["seek", String(seconds), "absolute"])
            savePlaybackState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setVolume(_ value: Double) {
        do {
            try mpv.setDouble("volume", value: value)
            savePlaybackState()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setSpeed(_ value: Double) {
        do {
            try mpv.setDouble("speed", value: value)
            log("Speed: \(value)x")
        } catch {
            errorMessage = error.localizedDescription
            log("Set speed failed: \(error.localizedDescription)")
        }
    }

    func snapshot() -> ControlState {
        let speed = mpv.getDouble("speed") ?? 1.0
        let sid = mpv.getString("sid")
        let subtitlesVisible = currentFile != nil
            && sid != "no"
            && (mpv.getFlag("sub-visibility") ?? true)
        let subtitleText = mpv.getString("sub-text")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let activeSubtitleText = subtitleText?.isEmpty == false ? subtitleText : nil

        return ControlState(
            currentFile: currentFile?.path,
            isPaused: isPaused,
            position: position,
            duration: duration,
            volume: volume,
            speed: speed,
            selectedAudioID: selectedAudioID,
            selectedSubtitleID: selectedSubtitleID,
            subtitlesVisible: subtitlesVisible,
            activeSubtitleText: activeSubtitleText,
            audioTracks: audioTracks.map(\.controlInfo),
            subtitleTracks: subtitleTracks.map(\.controlInfo)
        )
    }

    func logControlAction(_ method: String, detail: String? = nil) {
        if let detail, !detail.isEmpty {
            log("[control] \(method) \(detail)")
        } else {
            log("[control] \(method)")
        }
    }

    func selectAudioTrack(_ track: MediaTrack) {
        do {
            selectedAudioID = track.id
            log("Selecting audio: \(track.displayName) id=\(track.id)")
            try mpv.setInt("aid", value: track.id)
            savePlaybackState()
        } catch {
            errorMessage = error.localizedDescription
            log("Audio select failed: \(error.localizedDescription)")
        }
    }

    func selectSubtitleTrack(_ track: MediaTrack?) {
        do {
            loadedExternalSubtitle = nil
            selectedSubtitleID = track?.id
            if let track {
                log("Selecting subtitle: \(track.displayName) id=\(track.id)")
                try mpv.setInt("sid", value: track.id)
                try mpv.setFlag("sub-visibility", value: true)
            } else {
                log("Turning subtitles off.")
                try mpv.setString("sid", value: "no")
            }
            savePlaybackState()
        } catch {
            errorMessage = error.localizedDescription
            log("Subtitle select failed: \(error.localizedDescription)")
        }
    }

    func loadExternalSubtitle(_ url: URL) {
        guard currentFile != nil else {
            errorMessage = "Open a video before loading a subtitle file."
            return
        }

        guard SupportedSubtitleTypes.supports(url: url) else {
            errorMessage = "Unsupported subtitle format: \(url.pathExtension)"
            return
        }

        do {
            try attachExternalSubtitle(url)
            log("Loaded external subtitle: \(url.lastPathComponent)")
        } catch {
            errorMessage = error.localizedDescription
            log("External subtitle load failed: \(error.localizedDescription)")
        }
    }

    func prepareForTermination() {
        savePlaybackState()
        endPlaybackActivity()
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollState()
            }
        }
    }

    private func startKeyboardShortcuts() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }

            let modifiers = event.modifierFlags.intersection([.command, .option, .control])
            if event.keyCode == 3, modifiers == [.command, .control] {
                self.toggleFullscreen()
                return nil
            }

            guard modifiers.isEmpty else { return event }

            switch event.keyCode {
            case 49:
                self.togglePlayPause()
                return nil
            case 123:
                self.seek(relativeSeconds: -AppPreferences.keyboardSeekSeconds)
                return nil
            case 124:
                self.seek(relativeSeconds: AppPreferences.keyboardSeekSeconds)
                return nil
            case 53:
                if self.isFullscreen {
                    self.toggleFullscreen()
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }

    private func pollState() {
        let events = mpv.drainEvents()
        for line in events.logLines {
            log(line)
        }
        if let endFile = events.endFile {
            handlePlaybackEnded(endFile)
        }

        guard currentFile != nil else {
            isPaused = true
            position = 0
            duration = 0
            updatePlaybackActivity()
            return
        }

        position = mpv.getDouble("time-pos") ?? position
        duration = mpv.getDouble("duration") ?? duration
        isPaused = mpv.getFlag("pause") ?? isPaused
        updatePlaybackActivity()
        refreshTracks()
        applyPendingRestoreIfReady()

        pollCount += 1
        if pollCount % 4 == 0 {
            log("Subtitle diagnostics: \(mpv.subtitleDiagnostics())")
        }

        if pollCount % 8 == 0 {
            savePlaybackState()
        }
    }

    private func refreshTracks() {
        let tracks = mpv.getTracks()
        let audio = tracks.filter { $0.kind == .audio }
        let subtitles = tracks.filter { $0.kind == .subtitle }

        if audioTracks != audio {
            audioTracks = audio
            log("Audio tracks: \(audio.map(\.debugDescription).joined(separator: " | "))")
        }

        if subtitleTracks != subtitles {
            subtitleTracks = subtitles
            log("Subtitle tracks: \(subtitles.map(\.debugDescription).joined(separator: " | "))")
        }

        selectedAudioID = audio.first(where: \.isSelected)?.id
        selectedSubtitleID = subtitles.first(where: \.isSelected)?.id
    }

    private func applyPendingRestoreIfReady() {
        guard !didApplyRestoreState, currentFile != nil, mpv.isMediaReadyForRestore, duration > 0 else {
            return
        }

        if let state = pendingRestoreState {
            restoreSavedState(state)
            return
        }

        applyPendingSiblingSubtitleIfReady()
        didApplyRestoreState = true
    }

    private func restoreSavedState(_ state: SavedPlaybackState) {
        if abs(volume - state.volume) > 0.5 {
            do {
                volume = state.volume
                try mpv.setDouble("volume", value: state.volume)
            } catch {
                log("Restore volume failed: \(error.localizedDescription)")
            }
        }

        if let audioTrackID = state.audioTrackID {
            do {
                try mpv.setInt("aid", value: audioTrackID)
                selectedAudioID = audioTrackID
            } catch {
                log("Restore audio track failed: \(error.localizedDescription)")
            }
        }

        restoreSubtitleSelection(from: state)

        if PlaybackStatePolicy.shouldRestorePosition(state.position, duration: duration) {
            do {
                position = state.position
                try mpv.command(["seek", String(state.position), "absolute"])
            } catch {
                log("Restore position failed: \(error.localizedDescription)")
            }
        }

        didApplyRestoreState = true
        pendingRestoreState = nil
        log("Restored playback state.")
    }

    private func restoreSubtitleSelection(from state: SavedPlaybackState) {
        if state.subtitlesOff {
            do {
                try mpv.setString("sid", value: "no")
                selectedSubtitleID = nil
                pendingSiblingSubtitle = nil
            } catch {
                log("Restore subtitles-off failed: \(error.localizedDescription)")
            }
            return
        }

        if let externalPath = state.externalSubtitlePath,
           FileManager.default.fileExists(atPath: externalPath) {
            do {
                try attachExternalSubtitle(URL(fileURLWithPath: externalPath))
            } catch {
                log("Restore external subtitle failed: \(error.localizedDescription)")
            }
            return
        }

        if let sibling = pendingSiblingSubtitle {
            pendingSiblingSubtitle = nil
            do {
                try attachExternalSubtitle(sibling)
                log("Auto-loaded matching subtitle: \(sibling.lastPathComponent)")
            } catch {
                log("Auto-load matching subtitle failed: \(error.localizedDescription)")
            }
            return
        }

        if let subtitleTrackID = state.subtitleTrackID {
            do {
                try mpv.setInt("sid", value: subtitleTrackID)
                try mpv.setFlag("sub-visibility", value: true)
                selectedSubtitleID = subtitleTrackID
                pendingSiblingSubtitle = nil
            } catch {
                log("Restore subtitle track failed: \(error.localizedDescription)")
            }
            return
        }

        pendingSiblingSubtitle = nil
    }

    private func handlePlaybackEnded(_ signal: MPVEndFileSignal) {
        switch signal.reason {
        case MPV_END_FILE_REASON_STOP, MPV_END_FILE_REASON_REDIRECT:
            return
        case MPV_END_FILE_REASON_ERROR:
            savePlaybackState()
            if signal.error < 0, let message = mpvErrorDescription(signal.error) {
                errorMessage = message
            }
            isPaused = true
            updatePlaybackActivity()
        case MPV_END_FILE_REASON_EOF:
            savePlaybackState()
            isPaused = true
            updatePlaybackActivity()
        default:
            savePlaybackState()
            isPaused = true
            updatePlaybackActivity()
        }
    }

    private func mpvErrorDescription(_ code: Int32) -> String? {
        guard let message = mpv_error_string(code) else { return nil }
        return String(cString: message)
    }

    private func applyPendingSiblingSubtitleIfReady() {
        guard let sibling = pendingSiblingSubtitle else {
            return
        }

        pendingSiblingSubtitle = nil

        do {
            try attachExternalSubtitle(sibling)
            log("Auto-loaded matching subtitle: \(sibling.lastPathComponent)")
        } catch {
            log("Auto-load subtitle failed: \(error.localizedDescription)")
        }
    }

    private func savePlaybackState() {
        guard let currentFile else {
            return
        }

        guard PlaybackStatePolicy.canSave(
            duration: duration,
            resumeEnabled: AppPreferences.resumePlayback,
            didApplyRestoreState: didApplyRestoreState,
            hasPendingRestoreState: pendingRestoreState != nil
        ) else {
            return
        }

        let sid = mpv.getString("sid")
        let shouldRememberTracks = AppPreferences.rememberTrackSelection
        let state = SavedPlaybackState(
            position: position,
            duration: duration,
            audioTrackID: shouldRememberTracks ? selectedAudioID : nil,
            subtitleTrackID: shouldRememberTracks ? selectedSubtitleID : nil,
            subtitlesOff: shouldRememberTracks && sid == "no",
            externalSubtitlePath: shouldRememberTracks ? loadedExternalSubtitle?.path : nil,
            volume: volume,
            updatedAt: Date()
        )
        playbackStateStore.save(state, for: currentFile)
    }

    private func updatePlaybackActivity() {
        let shouldPreventIdleDisplay = currentFile != nil && !isPaused
        if shouldPreventIdleDisplay {
            beginPlaybackActivity()
        } else {
            endPlaybackActivity()
        }
    }

    private func beginPlaybackActivity() {
        guard playbackActivity == nil else { return }

        playbackActivity = ProcessInfo.processInfo.beginActivity(
            options: [
                .userInitiated,
                .idleSystemSleepDisabled,
                .idleDisplaySleepDisabled
            ],
            reason: "Valen is playing media"
        )

        if displaySleepAssertionID == 0 {
            let result = IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Valen is playing media" as CFString,
                &displaySleepAssertionID
            )
            if result != kIOReturnSuccess {
                displaySleepAssertionID = 0
                log("Could not create display sleep assertion: \(result).")
            }
        }

        log("Preventing display sleep while media is playing.")
    }

    private func endPlaybackActivity() {
        if let playbackActivity {
            ProcessInfo.processInfo.endActivity(playbackActivity)
            self.playbackActivity = nil
        }

        if displaySleepAssertionID != 0 {
            IOPMAssertionRelease(displaySleepAssertionID)
            displaySleepAssertionID = 0
        }
    }

    private func attachExternalSubtitle(_ url: URL) throws {
        let standardized = url.standardizedFileURL
        try mpv.command(["sub-add", standardized.path, "select"])
        try mpv.setFlag("sub-visibility", value: true)
        loadedExternalSubtitle = standardized
        refreshTracks()
        selectedSubtitleID = subtitleTracks.first(where: \.isSelected)?.id
        savePlaybackState()
    }

    private func log(_ message: String) {
        let timestamp = Self.logTimeFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        NSLog("[valen] \(message)")
        debugLines.append(line)
        if debugLines.count > 220 {
            debugLines.removeFirst(debugLines.count - 220)
        }
    }

    private static let logTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    static func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "00:00" }
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }

        return String(format: "%02d:%02d", minutes, secs)
    }
}

enum MediaTrackKind {
    case audio
    case subtitle
}

extension MediaTrack {
    var controlInfo: ControlTrackInfo {
        ControlTrackInfo(
            id: id,
            kind: kind == .audio ? "audio" : "subtitle",
            title: title,
            language: language,
            codec: codec,
            isDefault: isDefault,
            isForced: isForced,
            isSelected: isSelected,
            displayName: displayName
        )
    }
}

struct MediaTrack: Identifiable, Equatable {
    let id: Int
    let kind: MediaTrackKind
    let title: String?
    let language: String?
    let codec: String?
    let isDefault: Bool
    let isForced: Bool
    let isSelected: Bool

    var displayName: String {
        var parts: [String] = ["Track \(id)"]

        if let title, !title.isEmpty {
            parts.append(title)
        }

        if let language, !language.isEmpty {
            parts.append("metadata lang: \(language.uppercased())")
        }

        if isDefault {
            parts.append("default")
        }

        if isForced {
            parts.append("forced")
        }

        return parts.joined(separator: " - ")
    }

    var debugDescription: String {
        "id=\(id), kind=\(kind), title=\(title ?? "nil"), lang=\(language ?? "nil"), codec=\(codec ?? "nil"), default=\(isDefault), forced=\(isForced), selected=\(isSelected)"
    }
}

struct SavedPlaybackState: Codable {
    let position: Double
    let duration: Double
    let audioTrackID: Int?
    let subtitleTrackID: Int?
    let subtitlesOff: Bool
    let externalSubtitlePath: String?
    let volume: Double
    let updatedAt: Date

    var subtitleDescription: String {
        if subtitlesOff {
            return "off"
        }

        if let externalSubtitlePath {
            return URL(fileURLWithPath: externalSubtitlePath).lastPathComponent
        }

        return subtitleTrackID.map(String.init) ?? "auto"
    }
}

final class PlaybackStateStore {
    private let defaultsKey: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaultsKey: String = "dev.valen.player.playbackState.v1") {
        self.defaultsKey = defaultsKey
    }

    func state(for url: URL) -> SavedPlaybackState? {
        states()[key(for: url)]
    }

    func save(_ state: SavedPlaybackState, for url: URL) {
        var allStates = states()
        allStates[key(for: url)] = state

        if let data = try? encoder.encode(allStates) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private func states() -> [String: SavedPlaybackState] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let states = try? decoder.decode([String: SavedPlaybackState].self, from: data) else {
            return [:]
        }

        return states
    }

    private func key(for url: URL) -> String {
        url.standardizedFileURL.path
    }
}
