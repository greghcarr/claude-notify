import Foundation

final class IPCListener: NSObject {
    private let onMessage: (IPCMessage) -> Void

    init(onMessage: @escaping (IPCMessage) -> Void) {
        self.onMessage = onMessage
        super.init()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handle(_:)),
            name: Constants.IPC.notificationName,
            object: nil
        )
    }

    @objc private func handle(_ notification: Notification) {
        guard let payload = notification.userInfo?[Constants.IPC.payloadKey] as? Data,
              let ipc = try? JSONDecoder().decode(IPCMessage.self, from: payload) else { return }
        onMessage(ipc)
    }
}
