import Foundation
import UserNotifications

enum Constants {
    enum IPC {
        static let notificationName = Notification.Name("com.claude.notify.send")
        static let lockFilePath = "/tmp/claude-notify.lock"
        static let payloadKey = "payload"
    }

    enum UNUserInfo {
        static let bundleIdKey = "bundleId"
        static let urlKey = "url"
    }

    enum Defaults {
        static let title = "Claude Code"
    }

    enum Icons {
        static let pending = "bubble.left.fill"
        static let idle = "bubble.left"
        static let accessibilityDescription = "Claude Notify"
    }

    enum Menu {
        static let maxVisibleHistory = 5
        static let messagePreviewLength = 40
        static let ellipsis = "..."
        static let emptyLabel = "No notifications"
        static let clearAllTitle = "Clear all"
        static let quitTitle = "Quit"
        static let countSuffix = "notification(s)"
    }

    enum Shortcuts {
        static let clearAll = "c"
        static let quit = "q"
    }

    enum Sound {
        static let binaryPath = "/usr/bin/afplay"
        static let defaultFile = "/System/Library/Sounds/Glass.aiff"
    }

    enum Startup {
        static let firstNotificationDelay: TimeInterval = 0.5
    }

    enum Auth {
        static let requestedOptions: UNAuthorizationOptions = [.alert, .sound, .badge]
    }
}
