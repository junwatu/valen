import SwiftUI

@main
struct ValenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var updater = SparkleUpdaterController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.player)
                .frame(minWidth: 480, minHeight: 280)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Valen") {
                    AboutPanelPresenter.show()
                }
            }

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

    override init() {
        super.init()
        AppPreferences.registerDefaults()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let server = ControlServer(player: player)
        do {
            try server.start()
            controlServer = server
        } catch {
            NSLog("[valen] control server failed to start: \(error.localizedDescription)")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        player.prepareForTermination()
        controlServer?.stop()
        controlServer = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
