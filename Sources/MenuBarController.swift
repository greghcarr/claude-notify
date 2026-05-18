import AppKit

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem!
    private let history: NotificationHistory
    private let soundPreference: SoundPreference
    private let onItemClick: (StoredNotification) -> Void
    private let onClearAll: () -> Void
    private let onToggleSound: () -> Void
    private let onQuit: () -> Void

    init(history: NotificationHistory,
         soundPreference: SoundPreference,
         onItemClick: @escaping (StoredNotification) -> Void,
         onClearAll: @escaping () -> Void,
         onToggleSound: @escaping () -> Void,
         onQuit: @escaping () -> Void) {
        self.history = history
        self.soundPreference = soundPreference
        self.onItemClick = onItemClick
        self.onClearAll = onClearAll
        self.onToggleSound = onToggleSound
        self.onQuit = onQuit
        super.init()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        refresh()
    }

    func refresh() {
        updateIcon()
        rebuildMenu()
    }

    private func updateIcon() {
        guard let button = statusItem.button else { return }
        let symbol = history.isEmpty ? Constants.Icons.idle : Constants.Icons.pending
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: Constants.Icons.accessibilityDescription)
        button.image?.isTemplate = true
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        if history.isEmpty {
            let item = NSMenuItem(title: Constants.Menu.emptyLabel, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            menu.addItem(NSMenuItem(title: "\(history.count) \(Constants.Menu.countSuffix)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())

            for notif in history.prefix(Constants.Menu.maxVisibleHistory) {
                let truncated = String(notif.message.prefix(Constants.Menu.messagePreviewLength)) + (notif.message.count > Constants.Menu.messagePreviewLength ? Constants.Menu.ellipsis : "")
                let item = NSMenuItem(title: truncated, action: #selector(itemClicked(_:)), keyEquivalent: "")
                item.representedObject = notif
                item.target = self
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
            let clearItem = NSMenuItem(title: Constants.Menu.clearAllTitle, action: #selector(clearAllClicked), keyEquivalent: Constants.Shortcuts.clearAll)
            clearItem.target = self
            menu.addItem(clearItem)
        }

        menu.addItem(NSMenuItem.separator())

        let soundItem = NSMenuItem(title: Constants.Menu.soundToggleTitle, action: #selector(toggleSoundClicked), keyEquivalent: Constants.Shortcuts.toggleSound)
        soundItem.target = self
        soundItem.state = soundPreference.isEnabled ? .on : .off
        menu.addItem(soundItem)

        let quitItem = NSMenuItem(title: Constants.Menu.quitTitle, action: #selector(quitClicked), keyEquivalent: Constants.Shortcuts.quit)
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func itemClicked(_ sender: NSMenuItem) {
        guard let notif = sender.representedObject as? StoredNotification else { return }
        onItemClick(notif)
    }

    @objc private func clearAllClicked() {
        onClearAll()
    }

    @objc private func toggleSoundClicked() {
        onToggleSound()
    }

    @objc private func quitClicked() {
        onQuit()
    }
}
