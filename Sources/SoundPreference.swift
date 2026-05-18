import Foundation

final class SoundPreference {
    private let defaults: UserDefaults
    private let key: String
    var onChange: (() -> Void)?

    init(defaults: UserDefaults = .standard, key: String = Constants.Preferences.soundEnabledKey) {
        self.defaults = defaults
        self.key = key
    }

    var isEnabled: Bool {
        get {
            // Default to enabled when no value has been written yet.
            guard defaults.object(forKey: key) != nil else { return true }
            return defaults.bool(forKey: key)
        }
        set {
            defaults.set(newValue, forKey: key)
            onChange?()
        }
    }

    func toggle() {
        isEnabled.toggle()
    }
}
