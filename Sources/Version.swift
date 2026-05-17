// Single source of truth for the app version.
// Must match CFBundleShortVersionString and CFBundleVersion in Resources/Info.plist.
// Bumping one without the other is a release blocker; see DEVELOPMENT.md.
enum AppVersion {
    static let current = "1.1.3"
}
