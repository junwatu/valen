import AppKit
import SwiftUI

private enum ControlPopover: Equatable {
    case audio
    case subtitles
}

struct ContentView: View {
    @EnvironmentObject private var player: PlayerModel
    @AppStorage(AppPreferenceKeys.autoHideControls) private var autoHideControls = true
    @AppStorage(AppPreferenceKeys.autoHideDelay) private var autoHideDelay = 2.0
    @State private var isDropTarget = false
    @State private var isPointerInside = false
    @State private var isPointerActive = true
    @State private var isCursorHidden = false
    @State private var activeControlPopover: ControlPopover?
    @State private var hideControlsTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            VideoSurfaceView()
                .environmentObject(player)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    player.toggleFullscreen()
                }

            WindowStateReader()
                .environmentObject(player)
                .frame(width: 0, height: 0)

            if player.currentFile == nil {
                EmptyPlayerView(isDropTarget: isDropTarget) {
                    player.openFilePanel()
                }
            }

            VStack(spacing: 12) {
                Spacer()

                if player.isDebugVisible {
                    DebugLogPanel()
                        .environmentObject(player)
                        .frame(maxWidth: 980)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if player.currentFile != nil {
                    FloatingPlaybackControls(activePopover: $activeControlPopover)
                        .environmentObject(player)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: minControlPanelWidth, alignment: .center)
                        .opacity(shouldShowControls ? 1 : 0)
                        .offset(y: shouldShowControls ? 0 : 10)
                        .animation(.easeOut(duration: 0.18), value: shouldShowControls)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onHover { inside in
            isPointerInside = inside
            if inside {
                showControlsTemporarily()
            } else {
                hideControlsTask?.cancel()
                isPointerActive = false
                revealCursorIfNeeded()
            }
        }
        .onContinuousHover { phase in
            if case .active = phase {
                showControlsTemporarily()
            }
        }
        .onChange(of: player.isPaused) { _, isPaused in
            if isPaused {
                hideControlsTask?.cancel()
                isPointerActive = true
            } else if isPointerInside {
                showControlsTemporarily()
            } else {
                isPointerActive = false
                hideControlsTask?.cancel()
            }
        }
        .onChange(of: player.currentFile) { _, _ in
            showControlsTemporarily()
        }
        .onChange(of: activeControlPopover) { _, activePopover in
            if activePopover == nil {
                showControlsTemporarily()
            } else {
                hideControlsTask?.cancel()
                isPointerActive = true
            }
        }
        .onChange(of: shouldShowControls) { _, _ in
            updateCursorVisibility()
        }
        .onChange(of: player.isPaused) { _, _ in
            updateCursorVisibility()
        }
        .onChange(of: player.currentFile) { _, _ in
            updateCursorVisibility()
        }
        .onDisappear {
            revealCursorIfNeeded()
        }
        .onDrop(of: [.fileURL, .movie, .audio], isTargeted: $isDropTarget) { providers in
            player.handleDrop(providers)
        }
        .onOpenURL { url in
            player.load(url)
        }
        .alert("mpv error", isPresented: player.hasError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(player.errorMessage ?? "Unknown error")
        }
    }

    private var shouldShowControls: Bool {
        player.isPaused || player.currentFile == nil || player.isDebugVisible || activeControlPopover != nil || isPointerActive
    }

    private var minControlPanelWidth: CGFloat {
        player.currentFile == nil ? ValenLayoutMetrics.overlayWidthWithoutMedia : ValenLayoutMetrics.overlayWidthWithMedia
    }

    private func showControlsTemporarily() {
        isPointerActive = true
        hideControlsTask?.cancel()

        guard autoHideControls, !player.isPaused, player.currentFile != nil, !player.isDebugVisible, activeControlPopover == nil else {
            return
        }

        hideControlsTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(autoHideDelay))
            guard !Task.isCancelled else { return }
            isPointerActive = false
            updateCursorVisibility()
        }
    }

    private func updateCursorVisibility() {
        let pointerCanBeHidden = player.isFullscreen || isPointerInside
        let shouldHideCursor = pointerCanBeHidden && player.currentFile != nil && !player.isPaused && !shouldShowControls

        if shouldHideCursor, !isCursorHidden {
            NSCursor.hide()
            isCursorHidden = true
        } else if !shouldHideCursor {
            revealCursorIfNeeded()
        }
    }

    private func revealCursorIfNeeded() {
        guard isCursorHidden else { return }
        NSCursor.unhide()
        isCursorHidden = false
    }
}

private struct WindowStateReader: NSViewRepresentable {
    @EnvironmentObject private var player: PlayerModel

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view, player: player)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.attach(to: nsView, player: player)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator {
        private weak var view: NSView?
        private weak var player: PlayerModel?
        private nonisolated(unsafe) var observers: [NSObjectProtocol] = []

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func attach(to view: NSView, player: PlayerModel) {
            self.view = view
            self.player = player

            DispatchQueue.main.async { [weak self] in
                self?.observeWindowIfNeeded()
            }
        }

        private func observeWindowIfNeeded() {
            guard observers.isEmpty, let window = view?.window else { return }

            player?.isFullscreen = window.styleMask.contains(.fullScreen)

            let didEnter = NotificationCenter.default.addObserver(
                forName: NSWindow.didEnterFullScreenNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.player?.isFullscreen = true
                }
            }

            let didExit = NotificationCenter.default.addObserver(
                forName: NSWindow.didExitFullScreenNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.player?.isFullscreen = false
                }
            }

            observers = [didEnter, didExit]
        }
    }
}

private struct DebugLogPanel: View {
    @EnvironmentObject private var player: PlayerModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    player.isDebugVisible.toggle()
                } label: {
                    Label("Logs", systemImage: "chevron.down")
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(player.debugLines.count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if player.isDebugVisible {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(player.debugLines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                    .id(index)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                    }
                    .frame(height: 130)
                    .onChange(of: player.debugLines.count) { _, newValue in
                        if newValue > 0 {
                            proxy.scrollTo(newValue - 1, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color.black.opacity(0.60), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.16))
        }
    }
}

private struct EmptyPlayerView: View {
    let isDropTarget: Bool
    let openAction: () -> Void

    var body: some View {
        VStack(spacing: ValenLayoutMetrics.emptyStateSpacing) {
            Image(systemName: ValenLayoutMetrics.emptyStateIcon)
                .font(.system(size: ValenLayoutMetrics.emptyStateIconSize, weight: .regular))
                .foregroundStyle(.white.opacity(isDropTarget ? 0.78 : 0.56))
                .scaleEffect(isDropTarget ? 1.05 : 1)
                .animation(.easeOut(duration: 0.18), value: isDropTarget)

            VStack(spacing: ValenLayoutMetrics.emptyStateTextSpacing) {
                Text(isDropTarget ? ValenLayoutMetrics.emptyStateDropTitle : ValenLayoutMetrics.emptyStateTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.94))

                Text(ValenLayoutMetrics.emptyStateSubtitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button(ValenLayoutMetrics.emptyStateButtonTitle, action: openAction)
                .buttonStyle(.borderedProminent)
        }
        .padding(ValenLayoutMetrics.emptyStatePadding)
    }
}

private struct FloatingPlaybackControls: View {
    @EnvironmentObject private var player: PlayerModel
    @Binding var activePopover: ControlPopover?

    var body: some View {
        VStack(spacing: 10) {
            if let filename = player.currentFile?.lastPathComponent {
                Text(filename)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.white.opacity(0.94))
                    .frame(width: 520)
            }

            HStack(spacing: 12) {
                Text(player.positionText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 58, alignment: .leading)

                Slider(
                    value: Binding(
                        get: { player.position },
                        set: { player.scrub(to: $0) }
                    ),
                    in: 0...max(player.duration, 1)
                )
                .frame(width: 430)
                .disabled(player.duration <= 0)

                Text(player.durationText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(width: 58, alignment: .trailing)
            }

            HStack(spacing: 14) {
                Button {
                    player.togglePlayPause()
                } label: {
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(player.currentFile == nil)
                .help(playPauseHelp)

                Divider()
                    .frame(height: 20)
                    .overlay(.white.opacity(0.22))

                Image(systemName: ValenLayoutMetrics.volumeIcon)
                    .foregroundStyle(.white.opacity(0.78))

                Slider(value: $player.volume, in: 0...100)
                    .frame(width: 128)
                    .onChange(of: player.volume) { _, newValue in
                        player.setVolume(newValue)
                    }

                Divider()
                    .frame(height: 20)
                    .overlay(.white.opacity(0.22))

                Button {
                    activePopover = activePopover == .audio ? nil : .audio
                } label: {
                    Image(systemName: ValenLayoutMetrics.audioTracksIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .disabled(player.audioTracks.isEmpty)
                .help("Audio tracks")
                .popover(isPresented: popoverBinding(.audio), arrowEdge: .top) {
                    AudioTrackPopover(activePopover: $activePopover)
                        .environmentObject(player)
                }

                Button {
                    activePopover = activePopover == .subtitles ? nil : .subtitles
                } label: {
                    Image(systemName: subtitleIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .help("Subtitles")
                .popover(isPresented: popoverBinding(.subtitles), arrowEdge: .top) {
                    SubtitleTrackPopover(activePopover: $activePopover)
                        .environmentObject(player)
                }

                Button {
                    player.openFilePanel()
                } label: {
                    Image(systemName: ValenLayoutMetrics.openFileIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 26, height: 26)
                }
                .help("Open file")
            }
            .buttonStyle(.quickTimeOverlay)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: ValenLayoutMetrics.overlayCornerRadius)
                    .fill(Color.black.opacity(ValenLayoutMetrics.overlayOpacity))

                RoundedRectangle(cornerRadius: ValenLayoutMetrics.overlayCornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.08),
                                .white.opacity(0.02),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        )
        .overlay {
            RoundedRectangle(cornerRadius: ValenLayoutMetrics.overlayCornerRadius)
                .stroke(.white.opacity(0.18))
        }
        .shadow(color: .black.opacity(0.45), radius: 20, x: 0, y: 10)
    }

    private var playPauseIcon: String {
        guard player.currentFile != nil else { return "play.fill" }
        return player.isPaused ? "play.fill" : "pause.fill"
    }

    private var playPauseHelp: String {
        guard player.currentFile != nil else { return "Open a file to play" }
        return player.isPaused ? "Play" : "Pause"
    }

    private var subtitleIcon: String {
        player.selectedSubtitleID == nil ? ValenLayoutMetrics.subtitlesInactiveIcon : ValenLayoutMetrics.subtitlesActiveIcon
    }

    private func popoverBinding(_ popover: ControlPopover) -> Binding<Bool> {
        Binding(
            get: { activePopover == popover },
            set: { isPresented in
                activePopover = isPresented ? popover : nil
            }
        )
    }
}

private struct AudioTrackPopover: View {
    @EnvironmentObject private var player: PlayerModel
    @Binding var activePopover: ControlPopover?

    var body: some View {
        TrackPopoverContainer(title: "Audio Tracks") {
            if player.audioTracks.isEmpty {
                Text("No audio tracks")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            } else {
                ForEach(player.audioTracks) { track in
                    TrackOptionButton(
                        title: track.displayName,
                        isSelected: player.selectedAudioID == track.id
                    ) {
                        player.selectAudioTrack(track)
                        activePopover = nil
                    }
                }
            }
        }
    }
}

private struct SubtitleTrackPopover: View {
    @EnvironmentObject private var player: PlayerModel
    @Binding var activePopover: ControlPopover?

    var body: some View {
        TrackPopoverContainer(title: "Subtitles") {
            TrackOptionButton(
                title: "Off",
                isSelected: player.selectedSubtitleID == nil
            ) {
                player.selectSubtitleTrack(nil)
                activePopover = nil
            }

            if !player.subtitleTracks.isEmpty {
                Divider()
                    .padding(.vertical, 4)
            }

            ForEach(player.subtitleTracks) { track in
                TrackOptionButton(
                    title: track.displayName,
                    isSelected: player.selectedSubtitleID == track.id
                ) {
                    player.selectSubtitleTrack(track)
                    activePopover = nil
                }
            }
        }
    }
}

private struct TrackPopoverContainer<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    content
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 260)
        }
        .frame(width: 340)
    }
}

private struct TrackOptionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)

                Text(title)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .font(.callout)
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
        }
        .buttonStyle(.plain)
    }
}

private struct QuickTimeOverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.68 : 0.94))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.white.opacity(configuration.isPressed ? 0.16 : 0.10))
            )
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.10))
            )
    }
}

private extension ButtonStyle where Self == QuickTimeOverlayButtonStyle {
    static var quickTimeOverlay: QuickTimeOverlayButtonStyle {
        QuickTimeOverlayButtonStyle()
    }
}
