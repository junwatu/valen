import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

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

    private let mpv = MPVClient()
    private let playbackStateStore = PlaybackStateStore()
    private var timer: Timer?
    private var keyMonitor: Any?
    private var pollCount = 0
    private var pendingRestoreState: SavedPlaybackState?
    private var didApplyRestoreState = false
    private weak var hostView: MPVHostView?

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
    }

    func openFilePanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.supportedMediaTypes

        if panel.runModal() == .OK, let url = panel.url {
            load(url)
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
                self?.load(url)
            }
        }

        return true
    }

    func load(_ url: URL) {
        do {
            savePlaybackState()
            currentFile = url
            isPaused = false
            audioTracks = []
            subtitleTracks = []
            selectedAudioID = nil
            selectedSubtitleID = nil
            pendingRestoreState = AppPreferences.resumePlayback ? playbackStateStore.state(for: url) : nil
            didApplyRestoreState = false
            log("Loading file: \(url.path)")
            if let pendingRestoreState {
                log("Found saved state: position=\(pendingRestoreState.position), audio=\(pendingRestoreState.audioTrackID.map(String.init) ?? "auto"), subtitle=\(pendingRestoreState.subtitleDescription), volume=\(pendingRestoreState.volume)")
            }
            try mpv.command(["loadfile", url.path])
            try mpv.setFlag("pause", value: false)
        } catch {
            errorMessage = error.localizedDescription
            log("Load failed: \(error.localizedDescription)")
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
        for line in mpv.drainEvents() {
            log(line)
        }

        guard currentFile != nil else {
            isPaused = true
            position = 0
            duration = 0
            return
        }

        position = mpv.getDouble("time-pos") ?? position
        duration = mpv.getDouble("duration") ?? duration
        isPaused = mpv.getFlag("pause") ?? isPaused
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
        guard !didApplyRestoreState, let state = pendingRestoreState, currentFile != nil else {
            return
        }

        guard duration > 0 else {
            return
        }

        do {
            if abs(volume - state.volume) > 0.5 {
                volume = state.volume
                try mpv.setDouble("volume", value: state.volume)
            }

            if let audioTrackID = state.audioTrackID {
                try mpv.setInt("aid", value: audioTrackID)
                selectedAudioID = audioTrackID
            }

            if state.subtitlesOff {
                try mpv.setString("sid", value: "no")
                selectedSubtitleID = nil
            } else if let subtitleTrackID = state.subtitleTrackID {
                try mpv.setInt("sid", value: subtitleTrackID)
                try mpv.setFlag("sub-visibility", value: true)
                selectedSubtitleID = subtitleTrackID
            }

            if state.position > 5, state.position < max(duration - 5, 0) {
                position = state.position
                try mpv.command(["seek", String(state.position), "absolute"])
            }

            didApplyRestoreState = true
            pendingRestoreState = nil
            log("Restored playback state.")
        } catch {
            didApplyRestoreState = true
            pendingRestoreState = nil
            log("Restore failed: \(error.localizedDescription)")
        }
    }

    private func savePlaybackState() {
        guard let currentFile, duration > 0 else {
            return
        }

        guard AppPreferences.resumePlayback else {
            return
        }

        guard didApplyRestoreState || pendingRestoreState == nil else {
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
            volume: volume,
            updatedAt: Date()
        )
        playbackStateStore.save(state, for: currentFile)
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

    private static let supportedMediaTypes: [UTType] = [
        .movie,
        .video,
        .audio,
        .audiovisualContent,
        .mpeg4Movie,
        .quickTimeMovie,
        .mp3,
        .wav,
        UTType(filenameExtension: "mkv")!,
        UTType(filenameExtension: "mka")!,
        UTType(filenameExtension: "webm")!,
        UTType(filenameExtension: "flac")!,
        UTType(filenameExtension: "ogg")!,
        UTType(filenameExtension: "avi")!
    ]

    private static func formatTime(_ seconds: Double) -> String {
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
    let volume: Double
    let updatedAt: Date

    var subtitleDescription: String {
        if subtitlesOff {
            return "off"
        }

        return subtitleTrackID.map(String.init) ?? "auto"
    }
}

private final class PlaybackStateStore {
    private let defaultsKey = "dev.valen.player.playbackState.v1"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

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
