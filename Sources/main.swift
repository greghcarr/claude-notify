import Cocoa
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let history = NotificationHistory()
    private let soundPreference = SoundPreference()
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
            soundPreference: soundPreference,
            onItemClick: { [weak self] notif in self?.handleClick(notif) },
            onClearAll: { [weak self] in self?.history.clear() },
            onToggleSound: { [weak self] in self?.soundPreference.toggle() },
            onQuit: { NSApplication.shared.terminate(nil) }
        )

        history.onChange = { [weak self] in
            DispatchQueue.main.async { self?.menuBar.refresh() }
        }

        soundPreference.onChange = { [weak self] in
            DispatchQueue.main.async { self?.menuBar.refresh() }
        }

        dispatcher = NotificationDispatcher(
            history: history,
            soundPlayer: soundPlayer,
            soundPreference: soundPreference,
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

switch CLIParser.parse(Array(CommandLine.arguments.dropFirst())) {
case .printAndExit(let output):
    print(output)
    exit(0)

case .error(let message):
    print(message)
    exit(1)

case .run(let notifArgs, let daemonMode):
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

    if !notifArgs.message.isEmpty {
        // Send notification after the app finishes launching.
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.Startup.firstNotificationDelay) {
            delegate.send(args: notifArgs)
        }
    }

    app.run()
}
