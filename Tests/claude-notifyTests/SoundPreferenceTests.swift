import XCTest
@testable import claude_notify

final class SoundPreferenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "claude-notify.tests.SoundPreference"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testDefaultsToEnabledWhenUnset() {
        let pref = SoundPreference(defaults: defaults, key: "sound")
        XCTAssertTrue(pref.isEnabled)
    }

    func testToggleFlipsValue() {
        let pref = SoundPreference(defaults: defaults, key: "sound")
        pref.toggle()
        XCTAssertFalse(pref.isEnabled)
        pref.toggle()
        XCTAssertTrue(pref.isEnabled)
    }

    func testValuePersistsAcrossInstances() {
        let first = SoundPreference(defaults: defaults, key: "sound")
        first.isEnabled = false

        let second = SoundPreference(defaults: defaults, key: "sound")
        XCTAssertFalse(second.isEnabled)
    }

    func testOnChangeFiresWhenSettingValue() {
        let pref = SoundPreference(defaults: defaults, key: "sound")
        var callCount = 0
        pref.onChange = { callCount += 1 }

        pref.isEnabled = false
        XCTAssertEqual(callCount, 1)

        pref.toggle()
        XCTAssertEqual(callCount, 2)
    }
}
