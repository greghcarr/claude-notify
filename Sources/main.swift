import Cocoa
import UserNotifications

let CATEGORY_ID = "CLAUDE_ACTION"
let ACTION_ID = "OPEN_APP"
let NOTIF_NAME = Notification.Name("com.claude.notify.send")
let APP_ID = "com.claude.notify"

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var pendingNotifications: [(id: String, message: String, bundleId: String?)] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupNotificationCenter()
        listenForCommands()
    }

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateIcon(hasPending: false)
        }

        updateMenu()
    }

    func updateIcon(hasPending: Bool) {
        if let button = statusItem.button {
            let symbolName = hasPending ? "bubble.left.fill" : "bubble.left"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Claude Notify")
            button.image?.isTemplate = true
        }
    }

    func updateMenu() {
        let menu = NSMenu()

        if pendingNotifications.isEmpty {
            let item = NSMenuItem(title: "Aucune notification", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            menu.addItem(NSMenuItem(title: "\(pendingNotifications.count) notification(s)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())

            for notif in pendingNotifications.prefix(5) {
                let truncated = String(notif.message.prefix(40)) + (notif.message.count > 40 ? "..." : "")
                let item = NSMenuItem(title: truncated, action: #selector(openFromMenu(_:)), keyEquivalent: "")
                item.representedObject = notif
                item.target = self
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Tout effacer", action: #selector(clearAll), keyEquivalent: "c"))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quitter", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    func updateBadge() {
        updateIcon(hasPending: !pendingNotifications.isEmpty)
        updateMenu()
    }

    @objc func openFromMenu(_ sender: NSMenuItem) {
        guard let notif = sender.representedObject as? (id: String, message: String, bundleId: String?) else { return }

        if let bundleId = notif.bundleId, !bundleId.isEmpty {
            openApp(bundleId: bundleId)
        }

        pendingNotifications.removeAll { $0.id == notif.id }
        updateBadge()
    }

    @objc func clearAll() {
        pendingNotifications.removeAll()
        updateBadge()
    }

    @objc func quit() {
        NSApplication.shared.terminate(nil)
    }

    func listenForCommands() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleCommand(_:)),
            name: NOTIF_NAME,
            object: nil
        )
    }

    @objc func handleCommand(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let message = userInfo["message"] as? String else { return }

        let title = userInfo["title"] as? String ?? "Claude Code"
        let bundleId = userInfo["activate"] as? String
        let sound = userInfo["sound"] as? Bool ?? true

        let args = NotificationArgs(title: title, message: message, sound: sound, activate: bundleId)
        sendNotification(args: args)
    }

    func setupNotificationCenter() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let action = UNNotificationAction(
            identifier: ACTION_ID,
            title: "Ouvrir",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: CATEGORY_ID,
            actions: [action],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])

        // Request auth on startup
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func sendNotification(args: NotificationArgs) {
        let content = UNMutableNotificationContent()
        content.title = args.title
        content.body = args.message
        content.sound = args.sound ? .default : nil
        content.categoryIdentifier = CATEGORY_ID
        content.userInfo = ["bundleId": args.activate ?? ""]

        let id = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: nil
        )

        pendingNotifications.append((id: id, message: args.message, bundleId: args.activate))
        DispatchQueue.main.async { self.updateBadge() }

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
            }
        }
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

    // Handle notification response
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let notifId = response.notification.request.identifier

        if let index = pendingNotifications.firstIndex(where: { $0.id == notifId }) {
            let notif = pendingNotifications.remove(at: index)
            if let bundleId = notif.bundleId, !bundleId.isEmpty {
                openApp(bundleId: bundleId)
            }
            DispatchQueue.main.async { self.updateBadge() }
        }

        completionHandler()
    }
}

struct NotificationArgs {
    var title = "Claude Code"
    var message = ""
    var sound = true
    var activate: String?
}

// Check if daemon is already running
func isDaemonRunning() -> Bool {
    let runningApps = NSWorkspace.shared.runningApplications
    let myPid = ProcessInfo.processInfo.processIdentifier
    return runningApps.contains { app in
        app.bundleIdentifier == APP_ID && app.processIdentifier != myPid
    }
}

// Send command to running daemon
func sendToDaemon(args: NotificationArgs) {
    var userInfo: [String: Any] = [
        "message": args.message,
        "title": args.title,
        "sound": args.sound
    ]
    if let activate = args.activate {
        userInfo["activate"] = activate
    }

    DistributedNotificationCenter.default().postNotificationName(
        NOTIF_NAME,
        object: nil,
        userInfo: userInfo,
        deliverImmediately: true
    )
}

// Parse arguments
var notifArgs = NotificationArgs()
var daemonMode = false

var args = CommandLine.arguments.dropFirst()
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
    case "-h", "--help":
        print("""
        Usage:
          claude-notify --daemon              Start menu bar daemon
          claude-notify -m <msg> [-a <app>]   Send notification

        Options:
          -d, --daemon         Run as menu bar daemon
          -t, --title <text>   Notification title (default: "Claude Code")
          -m, --message <text> Notification message
          -a, --activate <id>  Bundle ID to activate on click
          --no-sound           Disable sound
        """)
        exit(0)
    default:
        if notifArgs.message.isEmpty {
            notifArgs.message = arg
        }
    }
}

if daemonMode {
    // Start as menu bar app
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
} else if !notifArgs.message.isEmpty {
    // Send to daemon if running, otherwise start daemon and send
    if isDaemonRunning() {
        sendToDaemon(args: notifArgs)
        exit(0)
    } else {
        // Start daemon and send notification
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate

        // Send notification after app starts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            delegate.sendNotification(args: notifArgs)
        }
        app.run()
    }
} else {
    print("Error: use --daemon or provide -m <message>")
    exit(1)
}
