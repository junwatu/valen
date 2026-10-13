import AppKit
import SwiftUI

@main
struct ValenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var updater = SparkleUpdaterController()

    var body: some Scene {
        // Single fixed window — not WindowGroup — so Valen never multi-windows.
        Window(SinglePlayerPolicy.mainWindowTitle, id: SinglePlayerPolicy.mainWindowID) {
            ContentView()
                .environmentObject(appDelegate.player)
                .frame(minWidth: 480, minHeight: 280)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .defaultSize(width: 960, height: 540)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Valen") {
                    AboutPanelPresenter.show()
                }
            }

            // Replace New Item / New Window with Open File only.
            CommandGroup(replacing: .newItem) {
                Button("Open File...") {
                    appDelegate.player.openFilePanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("Subtitles") {
                Button("Load External Subtitle...") {
                    appDelegate.player.openSubtitleFilePanel()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(appDelegate.player.currentFile == nil)
            }

            CommandMenu("Playback") {
                Button(appDelegate.player.isPaused ? "Play" : "Pause") {
                    appDelegate.player.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Seek Back 10 Seconds") {
                    appDelegate.player.seek(relativeSeconds: -10)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Seek Forward 10 Seconds") {
                    appDelegate.player.seek(relativeSeconds: 10)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Button(appDelegate.player.isFullscreen ? "Exit Full Screen" : "Enter Full Screen") {
                    appDelegate.player.toggleFullscreen()
                }
                .keyboardShortcut("f", modifiers: [.command, .control])

                Button(appDelegate.player.isDebugVisible ? "Hide Logs" : "Show Logs") {
                    appDelegate.player.isDebugVisible.toggle()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }

            CommandGroup(after: .appInfo) {
                if updater.isAvailable {
                    Button("Check for Updates...") {
                        updater.checkForUpdates()
                    }
                }
            }
        }

        Settings {
            SettingsView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let player = PlayerModel()
    private var controlServer: ControlServer?
    private var windowObserver: NSObjectProtocol?
    private var workspaceObservers: [NSObjectProtocol] = []
    private var isDuplicateInstance = false

    override init() {
        super.init()
        AppPreferences.registerDefaults()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Hand off to an already-running Valen; quit after the launch event queue drains.
        isDuplicateInstance = activateExistingInstanceIfNeeded()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if isDuplicateInstance {
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return
        }

        enforceSinglePlayerWindow()
        windowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.enforceSinglePlayerWindow()
            }
        }

        registerWorkspaceSleepObservers()

        let server = ControlServer(player: player)
        do {
            try server.start()
            controlServer = server
        } catch {
            NSLog("[valen] control server failed to start: \(error.localizedDescription)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let windowObserver {
            NotificationCenter.default.removeObserver(windowObserver)
            self.windowObserver = nil
        }
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        workspaceObservers.removeAll()
        player.prepareForTermination()
        controlServer?.stop()
        controlServer = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        player.activateMainWindow()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !isDuplicateInstance else { return }
        openURLsInSinglePlayer(urls)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        guard !isDuplicateInstance else { return true }
        openURLsInSinglePlayer([URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard !isDuplicateInstance else {
            NSApp.reply(toOpenOrPrint: .success)
            return
        }
        openURLsInSinglePlayer(filenames.map { URL(fileURLWithPath: $0) })
        NSApp.reply(toOpenOrPrint: .success)
    }

    private func openURLsInSinglePlayer(_ urls: [URL]) {
        switch SinglePlayerPolicy.openIntent(for: urls, hasCurrentFile: player.currentFile != nil) {
        case .loadMedia(let url):
            player.load(url)
            player.activateMainWindow()
        case .loadSubtitle(let url):
            player.loadExternalSubtitle(url)
            player.activateMainWindow()
        case .none:
            player.activateMainWindow()
        }
    }

    /// If another Valen process with the same bundle ID is already running, activate it and quit.
    private func activateExistingInstanceIfNeeded() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier, !bundleID.isEmpty else {
            return false
        }

        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { !$0.isTerminated && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        guard let existing = others.first else {
            return false
        }

        existing.activate()
        NSLog("[valen] single-instance: activated existing process \(existing.processIdentifier)")
        return true
    }

    /// Safety net: close any extra player surfaces if a second window appears.
    private func enforceSinglePlayerWindow() {
        let playerWindows = NSApp.windows.filter { window in
            containsMPVHostView(window.contentView)
        }

        guard playerWindows.count > 1 else { return }

        let main = player.mainWindow ?? playerWindows.first
        for window in playerWindows where window !== main {
            let shouldClose = SinglePlayerPolicy.shouldCloseAsExtraPlayerWindow(
                isVisible: window.isVisible,
                isMiniaturized: window.isMiniaturized,
                isFloatingOrModalPanel: window.level != .normal || window.isSheet,
                hasMPVHostView: true,
                isMainPlayerWindow: false
            )
            if shouldClose {
                NSLog("[valen] single-window: closing extra player window")
                window.close()
            }
        }
    }

    private func containsMPVHostView(_ view: NSView?) -> Bool {
        guard let view else { return false }
        if view is MPVHostView { return true }
        return view.subviews.contains { containsMPVHostView($0) }
    }

    private func registerWorkspaceSleepObservers() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers = [
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.player.handleSystemWillSleep()
                }
            },
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.player.handleSystemDidWake()
                }
            },
            center.addObserver(
                forName: NSWorkspace.screensDidSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.player.handleScreensDidSleep()
                }
            },
            center.addObserver(
                forName: NSWorkspace.screensDidWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.player.handleScreensDidWake()
                }
            },
        ]
    }
}
