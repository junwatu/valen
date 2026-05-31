import SwiftUI

struct SettingsView: View {
    @AppStorage(AppPreferenceKeys.resumePlayback) private var resumePlayback = true
    @AppStorage(AppPreferenceKeys.rememberTrackSelection) private var rememberTrackSelection = true
    @AppStorage(AppPreferenceKeys.autoHideControls) private var autoHideControls = true
    @AppStorage(AppPreferenceKeys.autoHideDelay) private var autoHideDelay = 2.0
    @AppStorage(AppPreferenceKeys.keyboardSeekSeconds) private var keyboardSeekSeconds = 10.0
    @AppStorage(AppPreferenceKeys.defaultVolume) private var defaultVolume = 80.0

    var body: some View {
        Form {
            Section("Playback") {
                Toggle("Resume videos where I left off", isOn: $resumePlayback)
                Toggle("Remember audio and subtitle track per video", isOn: $rememberTrackSelection)

                Picker("Keyboard seek", selection: $keyboardSeekSeconds) {
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Default volume")
                    Slider(value: $defaultVolume, in: 0...100, step: 5)
                    Text("\(Int(defaultVolume))%")
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
            }

            Section("Controls") {
                Toggle("Hide overlay while using keyboard", isOn: $autoHideControls)

                HStack {
                    Text("Hide after")
                    Slider(value: $autoHideDelay, in: 1...5, step: 0.5)
                        .disabled(!autoHideControls)
                    Text("\(autoHideDelay, specifier: "%.1f")s")
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
    }
}
