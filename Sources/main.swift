import Cocoa
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let history = NotificationHistory()
    private let soundPlayer: SoundPlayer = AfplaySoundPlayer(
        binaryPath: Constants.Sound.binaryPath,
        soundFile: Constants.Sound.defaultFile
    )
    private var menuBar: MenuBarController!
    private var dispatcher: NotificationDispatcher!
    private var ipcListener: IPCListener!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent macOS from auto-terminating the app
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar daemon")

        menuBar = MenuBarController(
            history: history,
            onItemClick: { [weak self] notif in self?.handleClick(notif) },
            onClearAll: { [weak self] in self?.history.clear() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )

        history.onChange = { [weak self] in
            DispatchQueue.main.async { self?.menuBar.refresh() }
        }

        dispatcher = NotificationDispatcher(
            history: history,
            soundPlayer: soundPlayer,
            onClick: { [weak self] notif in self?.handleClick(notif) },
            onClickFallback: { url, bundleId in
                AppActivator.activate(url: url, bundleId: bundleId)
            }
        )

        ipcListener = IPCListener(onMessage: { [weak self] ipc in
            self?.dispatch(ipc)
        })
    }

    func send(args: NotificationArgs) {
        dispatcher.send(args)
    }

    private func dispatch(_ ipc: IPCMessage) {
        let args = NotificationArgs(
            title: ipc.title,
            message: ipc.message,
            sound: ipc.sound,
            activate: ipc.activate,
            url: ipc.url
        )
        dispatcher.send(args)
    }

    private func handleClick(_ notif: StoredNotification) {
        AppActivator.activate(url: notif.url, bundleId: notif.bundleId)
        history.remove(id: notif.id)
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
    let canStartDaemon = singleInstance.tryLock()

    if !canStartDaemon {
        // Another daemon is running
        if !notifArgs.message.isEmpty {
            sendToDaemon(args: notifArgs)
        }
        exit(0)
    }

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate()
    app.delegate = delegate

    if !daemonMode && !notifArgs.message.isEmpty {
        // Send notification after app starts
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Startup.firstNotificationDelay) {
            delegate.send(args: notifArgs)
        }
    }

    app.run()
} else {
    print("Error: use --daemon or provide -m <message>")
    exit(1)
}
