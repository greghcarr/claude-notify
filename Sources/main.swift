import Cocoa
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var history: [StoredNotification] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent macOS from auto-terminating the app
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar daemon")

        setupMenuBar()
        setupNotificationCenter()
        listenForCommands()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if statusItem.button != nil {
            updateIcon(hasPending: false)
        }

        updateMenu()
    }

    func updateIcon(hasPending: Bool) {
        if let button = statusItem.button {
            let symbolName = hasPending ? Constants.Icons.pending : Constants.Icons.idle
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: Constants.Icons.accessibilityDescription)
            button.image?.isTemplate = true
        }
    }

    func updateMenu() {
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
                let item = NSMenuItem(title: truncated, action: #selector(openFromMenu(_:)), keyEquivalent: "")
                item.representedObject = notif
                item.target = self
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: Constants.Menu.clearAllTitle, action: #selector(clearAll), keyEquivalent: Constants.Shortcuts.clearAll))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: Constants.Menu.quitTitle, action: #selector(quit), keyEquivalent: Constants.Shortcuts.quit))

        statusItem.menu = menu
    }

    func updateBadge() {
        updateIcon(hasPending: !history.isEmpty)
        updateMenu()
    }

    @objc func openFromMenu(_ sender: NSMenuItem) {
        guard let notif = sender.representedObject as? StoredNotification else { return }

        activate(url: notif.url, bundleId: notif.bundleId)

        history.removeAll { $0.id == notif.id }
        updateBadge()
    }

    @objc func clearAll() {
        history.removeAll()
        updateBadge()
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func listenForCommands() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleCommand(_:)),
            name: Constants.IPC.notificationName,
            object: nil
        )
    }

    @objc func handleCommand(_ notification: Notification) {
        guard let payload = notification.userInfo?[Constants.IPC.payloadKey] as? Data,
              let ipc = try? JSONDecoder().decode(IPCMessage.self, from: payload) else { return }

        let args = NotificationArgs(
            title: ipc.title,
            message: ipc.message,
            sound: ipc.sound,
            activate: ipc.activate,
            url: ipc.url
        )
        sendNotification(args: args)
    }

    func setupNotificationCenter() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        center.requestAuthorization(options: Constants.Auth.requestedOptions) { granted, error in
            if let error = error {
                print("Notification auth error: \(error)")
            }
        }
    }

    func sendNotification(args: NotificationArgs) {
        let content = UNMutableNotificationContent()
        content.title = args.title
        content.body = args.message
        content.sound = args.sound ? .default : nil
        content.userInfo = [
            Constants.UNUserInfo.bundleIdKey: args.activate ?? "",
            Constants.UNUserInfo.urlKey: args.url ?? ""
        ]

        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)

        history.insert(
            StoredNotification(
                id: id,
                title: args.title,
                message: args.message,
                bundleId: args.activate,
                url: args.url
            ),
            at: 0
        )
        DispatchQueue.main.async { self.updateBadge() }

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }

        // Play sound directly (UNNotificationSound.default doesn't always work)
        if args.sound {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: Constants.Sound.binaryPath)
            task.arguments = [Constants.Sound.defaultFile]
            try? task.run()
        }
    }

    func activate(url: String?, bundleId: String?) {
        if let url = url, !url.isEmpty {
            openURL(url)
        } else if let bundleId = bundleId, !bundleId.isEmpty {
            openApp(bundleId: bundleId)
        }
    }

    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }

    func openApp(bundleId: String) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    // Show notification even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    // Handle notification click
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let notifId = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo

        if let index = history.firstIndex(where: { $0.id == notifId }) {
            let notif = history.remove(at: index)
            activate(url: notif.url, bundleId: notif.bundleId)
            DispatchQueue.main.async { self.updateBadge() }
        } else {
            let url = userInfo[Constants.UNUserInfo.urlKey] as? String
            let bundleId = userInfo[Constants.UNUserInfo.bundleIdKey] as? String
            activate(url: url, bundleId: bundleId)
        }

        completionHandler()
    }
}

// Send command to running daemon via DistributedNotificationCenter
func sendToDaemon(args: NotificationArgs) {
    let ipc = IPCMessage(
        title: args.title,
        message: args.message,
        sound: args.sound,
        activate: args.activate,
        url: args.url
    )
    guard let payload = try? JSONEncoder().encode(ipc) else { return }

    DistributedNotificationCenter.default().postNotificationName(
        Constants.IPC.notificationName,
        object: nil,
        userInfo: [Constants.IPC.payloadKey: payload],
        deliverImmediately: true
    )
}

// Parse arguments
var notifArgs = NotificationArgs()
var daemonMode = false

var args = CommandLine.arguments.dropFirst()

// Bundled launches (Finder double-click, `open .app`, LaunchAgent without
// ProgramArguments) pass zero args. Treat that as `--daemon` so the menu
// bar app starts instead of exiting with the no-args error.
if args.isEmpty {
    daemonMode = true
}

while let arg = args.first {
    args = args.dropFirst()
    switch arg {
    case "-d", "--daemon":
        daemonMode = true
    case "-t", "--title":
        notifArgs.title = args.first ?? notifArgs.title
        args = args.dropFirst()
    case "-m", "--message":
        notifArgs.message = args.first ?? ""
        args = args.dropFirst()
    case "--no-sound":
        notifArgs.sound = false
    case "-a", "--activate":
        notifArgs.activate = args.first
        args = args.dropFirst()
    case "-u", "--url":
        notifArgs.url = args.first
        args = args.dropFirst()
    case "--version":
        print("claude-notify \(AppVersion.current)")
        exit(0)
    case "-h", "--help":
        print("""
        Usage:
          claude-notify --daemon              Start menu bar daemon
          claude-notify -m <msg> [-a <app>]   Send notification

        Options:
          -d, --daemon         Run as menu bar daemon
          -t, --title <text>   Notification title (default: "\(Constants.Defaults.title)")
          -m, --message <text> Notification message
          -a, --activate <id>  Bundle ID to activate on click
          -u, --url <url>      URL to open on click (overrides -a)
          --no-sound           Disable sound
          --version            Print version and exit
        """)
        exit(0)
    default:
        if notifArgs.message.isEmpty {
            notifArgs.message = arg
        }
    }
}

if daemonMode || !notifArgs.message.isEmpty {
    // Try to acquire lock (single instance)
    let canStartDaemon = singleInstance.tryLock()

    if !canStartDaemon {
        // Another daemon is running
        if !notifArgs.message.isEmpty {
            sendToDaemon(args: notifArgs)
        }
        exit(0)
    }

    // Start as menu bar app
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate

    if !daemonMode && !notifArgs.message.isEmpty {
        // Send notification after app starts
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Startup.firstNotificationDelay) {
            delegate.sendNotification(args: notifArgs)
        }
    }

    app.run()
} else {
    print("Error: use --daemon or provide -m <message>")
    exit(1)
}
