import SwiftUI

@main
struct ValenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var player = PlayerModel()
    @StateObject private var updater = SparkleUpdaterController()
    @State private var controlServer: ControlServer?

    init() {
        AppPreferences.registerDefaults()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .frame(minWidth: 920, minHeight: 560)
                .task {
                    if controlServer == nil {
                        let server = ControlServer(player: player)
                        do {
                            try server.start()
                            controlServer = server
                        } catch {
                            NSLog("[valen] control server failed to start: \(error.localizedDescription)")
                        }
                    }
                }
                .onDisappear {
                    controlServer?.stop()
                    controlServer = nil
                }
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
                    player.openFilePanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("Playback") {
                Button(player.isPaused ? "Play" : "Pause") {
                    player.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Seek Back 10 Seconds") {
                    player.seek(relativeSeconds: -10)
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Button("Seek Forward 10 Seconds") {
                    player.seek(relativeSeconds: 10)
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Button(player.isFullscreen ? "Exit Full Screen" : "Enter Full Screen") {
                    player.toggleFullscreen()
                }
                .keyboardShortcut("f", modifiers: [.command, .control])

                Button(player.isDebugVisible ? "Hide Logs" : "Show Logs") {
                    player.isDebugVisible.toggle()
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
