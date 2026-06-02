@testable import Valen
import XCTest

final class AppPreferencesTests: XCTestCase {
    override func setUp() {
        super.setUp()
        [
            AppPreferenceKeys.resumePlayback,
            AppPreferenceKeys.rememberTrackSelection,
            AppPreferenceKeys.autoHideControls,
            AppPreferenceKeys.autoHideDelay,
            AppPreferenceKeys.keyboardSeekSeconds,
            AppPreferenceKeys.defaultVolume
        ].forEach(UserDefaults.standard.removeObject)
    }

    func testRegisteredDefaultsMatchExpectedPlayerBehavior() {
        AppPreferences.registerDefaults()

        XCTAssertTrue(AppPreferences.resumePlayback)
        XCTAssertTrue(AppPreferences.rememberTrackSelection)
        XCTAssertTrue(AppPreferences.autoHideControls)
        XCTAssertEqual(AppPreferences.autoHideDelay, 2.0)
        XCTAssertEqual(AppPreferences.keyboardSeekSeconds, 10.0)
        XCTAssertEqual(AppPreferences.defaultVolume, 80.0)
    }

    func testExplicitPreferenceValuesOverrideDefaults() {
        UserDefaults.standard.set(false, forKey: AppPreferenceKeys.resumePlayback)
        UserDefaults.standard.set(false, forKey: AppPreferenceKeys.rememberTrackSelection)
        UserDefaults.standard.set(false, forKey: AppPreferenceKeys.autoHideControls)
        UserDefaults.standard.set(3.5, forKey: AppPreferenceKeys.autoHideDelay)
        UserDefaults.standard.set(15.0, forKey: AppPreferenceKeys.keyboardSeekSeconds)
        UserDefaults.standard.set(55.0, forKey: AppPreferenceKeys.defaultVolume)

        AppPreferences.registerDefaults()

        XCTAssertFalse(AppPreferences.resumePlayback)
        XCTAssertFalse(AppPreferences.rememberTrackSelection)
        XCTAssertFalse(AppPreferences.autoHideControls)
        XCTAssertEqual(AppPreferences.autoHideDelay, 3.5)
        XCTAssertEqual(AppPreferences.keyboardSeekSeconds, 15.0)
        XCTAssertEqual(AppPreferences.defaultVolume, 55.0)
    }

    func testSettingsOptionsStayWithinExpectedBounds() {
        XCTAssertEqual(AppPreferenceOptions.keyboardSeekSeconds, [5.0, 10.0, 30.0])
        XCTAssertEqual(AppPreferenceOptions.autoHideDelayRange.lowerBound, 1.0)
        XCTAssertEqual(AppPreferenceOptions.autoHideDelayRange.upperBound, 5.0)
        XCTAssertEqual(AppPreferenceOptions.autoHideDelayStep, 0.5)
        XCTAssertEqual(AppPreferenceOptions.defaultVolumeRange.lowerBound, 0.0)
        XCTAssertEqual(AppPreferenceOptions.defaultVolumeRange.upperBound, 100.0)
        XCTAssertEqual(AppPreferenceOptions.defaultVolumeStep, 5.0)
    }

    func testPreferenceKeysStayStableForExistingUsers() {
        XCTAssertEqual(AppPreferenceKeys.resumePlayback, "dev.valen.preferences.resumePlayback")
        XCTAssertEqual(AppPreferenceKeys.rememberTrackSelection, "dev.valen.preferences.rememberTrackSelection")
        XCTAssertEqual(AppPreferenceKeys.autoHideControls, "dev.valen.preferences.autoHideControls")
        XCTAssertEqual(AppPreferenceKeys.autoHideDelay, "dev.valen.preferences.autoHideDelay")
        XCTAssertEqual(AppPreferenceKeys.keyboardSeekSeconds, "dev.valen.preferences.keyboardSeekSeconds")
        XCTAssertEqual(AppPreferenceKeys.defaultVolume, "dev.valen.preferences.defaultVolume")
    }
}
