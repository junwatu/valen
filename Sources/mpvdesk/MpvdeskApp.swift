import SwiftUI

@main
struct ValenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var player = PlayerModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(player)
                .frame(minWidth: 920, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .commands {
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
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
