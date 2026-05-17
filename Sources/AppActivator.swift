import AppKit

enum AppActivator {
    static func activate(url: String?, bundleId: String?) {
        if let url = url, !url.isEmpty {
            openURL(url)
        } else if let bundleId = bundleId, !bundleId.isEmpty {
            openApp(bundleId: bundleId)
        }
    }

    static func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    static func openApp(bundleId: String) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}
