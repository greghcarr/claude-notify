import AppKit
import UserNotifications

final class NotificationDispatcher: NSObject, UNUserNotificationCenterDelegate {
    private let history: NotificationHistory
    private let soundPlayer: SoundPlayer
    private let soundPreference: SoundPreference
    private let onClick: (StoredNotification) -> Void
    private let onClickFallback: (_ url: String?, _ bundleId: String?) -> Void

    init(history: NotificationHistory,
         soundPlayer: SoundPlayer,
         soundPreference: SoundPreference,
         onClick: @escaping (StoredNotification) -> Void,
         onClickFallback: @escaping (_ url: String?, _ bundleId: String?) -> Void) {
        self.history = history
        self.soundPlayer = soundPlayer
        self.soundPreference = soundPreference
        self.onClick = onClick
        self.onClickFallback = onClickFallback
        super.init()

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: Constants.Auth.requestedOptions) { _, error in
            if let error = error {
                print("Notification auth error: \(error)")
            }
        }
    }

    func send(_ args: NotificationArgs) {
        let soundEnabled = args.sound && soundPreference.isEnabled
        let content = UNMutableNotificationContent()
        content.title = args.title
        content.body = args.message
        content.sound = soundEnabled ? .default : nil
        content.userInfo = [
            Constants.UNUserInfo.bundleIdKey: args.activate ?? "",
            Constants.UNUserInfo.urlKey: args.url ?? ""
        ]

        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)

        history.add(StoredNotification(
            id: id,
            title: args.title,
            message: args.message,
            bundleId: args.activate,
            url: args.url
        ))

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }

        if soundEnabled { soundPlayer.play() }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let notifId = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo

        if let stored = history.find(id: notifId) {
            onClick(stored)
        } else {
            let url = userInfo[Constants.UNUserInfo.urlKey] as? String
            let bundleId = userInfo[Constants.UNUserInfo.bundleIdKey] as? String
            onClickFallback(url, bundleId)
        }

        completionHandler()
    }
}
