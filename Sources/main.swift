import Cocoa
import UserNotifications

let NOTIF_NAME = Notification.Name("com.claude.notify.send")
let BUNDLE_ID = "com.claude.notify"
let LOCK_FILE = "/tmp/claude-notify.lock"

// Single instance lock using file lock
class SingleInstance {
    private var fileDescriptor: Int32 = -1

    func tryLock() -> Bool {
        fileDescriptor = open(LOCK_FILE, O_CREAT | O_RDWR, 0o644)
        if fileDescriptor == -1 { return false }

        var lock = flock()
        lock.l_start = 0
        lock.l_len = 0
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)

        if fcntl(fileDescriptor, F_SETLK, &lock) == -1 {
            close(fileDescriptor)
            fileDescriptor = -1
            return false
        }

        // Write PID to file
        ftruncate(fileDescriptor, 0)
        let pid = "\(getpid())"
        write(fileDescriptor, pid, pid.count)

        return true
    }

    deinit {
        if fileDescriptor != -1 {
            close(fileDescriptor)
            unlink(LOCK_FILE)
        }
    }
}

let singleInstance = SingleInstance()

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    var statusItem: NSStatusItem!
    var history: [(id: String, message: String, title: String, bundleId: String?)] = []

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
            let symbolName = hasPending ? "bubble.left.fill" : "bubble.left"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Claude Notify")
            button.image?.isTemplate = true
        }
    }

    func updateMenu() {
        let menu = NSMenu()

        if history.isEmpty {
            let item = NSMenuItem(title: "No notifications", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else {
            menu.addItem(NSMenuItem(title: "\(history.count) notification(s)", action: nil, keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())

            for notif in history.prefix(5) {
                let truncated = String(notif.message.prefix(40)) + (notif.message.count > 40 ? "..." : "")
                let item = NSMenuItem(title: truncated, action: #selector(openFromMenu(_:)), keyEquivalent: "")
                item.representedObject = notif
                item.target = self
                menu.addItem(item)
            }

            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Clear all", action: #selector(clearAll), keyEquivalent: "c"))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    func updateBadge() {
        updateIcon(hasPending: !history.isEmpty)
        updateMenu()
    }

    @objc func openFromMenu(_ sender: NSMenuItem) {
        guard let notif = sender.representedObject as? (id: String, message: String, title: String, bundleId: String?) else { return }

        if let bundleId = notif.bundleId, !bundleId.isEmpty {
            openApp(bundleId: bundleId)
        }

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

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
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
        content.userInfo = ["bundleId": args.activate ?? ""]

        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)

        history.insert((id: id, message: args.message, title: args.title, bundleId: args.activate), at: 0)
        DispatchQueue.main.async { self.updateBadge() }

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }

        // Play sound directly (UNNotificationSound.default doesn't always work)
        if args.sound {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/afplay")
            task.arguments = ["/System/Library/Sounds/Glass.aiff"]
            try? task.run()
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

    // Handle notification click
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let notifId = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo

        if let index = history.firstIndex(where: { $0.id == notifId }) {
            let notif = history.remove(at: index)
            if let bundleId = notif.bundleId, !bundleId.isEmpty {
                openApp(bundleId: bundleId)
            }
            DispatchQueue.main.async { self.updateBadge() }
        } else if let bundleId = userInfo["bundleId"] as? String, !bundleId.isEmpty {
            openApp(bundleId: bundleId)
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

// Send command to running daemon via DistributedNotificationCenter
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            delegate.sendNotification(args: notifArgs)
        }
    }

    app.run()
} else {
    print("Error: use --daemon or provide -m <message>")
    exit(1)
}
