import Foundation

enum AppPreferenceKeys {
    static let resumePlayback = "dev.valen.preferences.resumePlayback"
    static let rememberTrackSelection = "dev.valen.preferences.rememberTrackSelection"
    static let autoHideControls = "dev.valen.preferences.autoHideControls"
    static let autoHideDelay = "dev.valen.preferences.autoHideDelay"
    static let keyboardSeekSeconds = "dev.valen.preferences.keyboardSeekSeconds"
    static let defaultVolume = "dev.valen.preferences.defaultVolume"
    static let autoLoadMatchingSubtitle = "dev.valen.preferences.autoLoadMatchingSubtitle"
}

enum AppPreferences {
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            AppPreferenceKeys.resumePlayback: true,
            AppPreferenceKeys.rememberTrackSelection: true,
            AppPreferenceKeys.autoHideControls: true,
            AppPreferenceKeys.autoHideDelay: 2.0,
            AppPreferenceKeys.keyboardSeekSeconds: 10.0,
            AppPreferenceKeys.defaultVolume: 80.0,
            AppPreferenceKeys.autoLoadMatchingSubtitle: true
        ])
    }

    static var resumePlayback: Bool {
        UserDefaults.standard.bool(forKey: AppPreferenceKeys.resumePlayback)
    }

    static var rememberTrackSelection: Bool {
        UserDefaults.standard.bool(forKey: AppPreferenceKeys.rememberTrackSelection)
    }

    static var autoHideControls: Bool {
        UserDefaults.standard.bool(forKey: AppPreferenceKeys.autoHideControls)
    }

    static var autoHideDelay: Double {
        UserDefaults.standard.object(forKey: AppPreferenceKeys.autoHideDelay) as? Double ?? 2.0
    }

    static var keyboardSeekSeconds: Double {
        UserDefaults.standard.object(forKey: AppPreferenceKeys.keyboardSeekSeconds) as? Double ?? 10.0
    }

    static var defaultVolume: Double {
        UserDefaults.standard.object(forKey: AppPreferenceKeys.defaultVolume) as? Double ?? 80.0
    }

    static var autoLoadMatchingSubtitle: Bool {
        UserDefaults.standard.bool(forKey: AppPreferenceKeys.autoLoadMatchingSubtitle)
    }
}

enum AppPreferenceOptions {
    static let keyboardSeekSeconds = [5.0, 10.0, 30.0]
    static let autoHideDelayRange = 1.0...5.0
    static let autoHideDelayStep = 0.5
    static let defaultVolumeRange = 0.0...100.0
    static let defaultVolumeStep = 5.0
}
