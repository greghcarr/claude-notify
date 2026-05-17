import Foundation

enum CLIResult {
    case run(args: NotificationArgs, daemonMode: Bool)
    case printAndExit(String)
    case error(String)
}

enum CLIParser {
    static func parse(_ args: [String]) -> CLIResult {
        var notifArgs = NotificationArgs()
        var daemonMode = false
        var remaining = ArraySlice(args)

        // Bundled launches (Finder double-click, `open .app`, LaunchAgent without
        // ProgramArguments) pass zero args. Treat that as `--daemon` so the menu
        // bar app starts instead of exiting with the no-args error.
        if remaining.isEmpty {
            daemonMode = true
        }

        while let arg = remaining.first {
            remaining = remaining.dropFirst()
            switch arg {
            case "-d", "--daemon":
                daemonMode = true
            case "-t", "--title":
                notifArgs.title = remaining.first ?? notifArgs.title
                remaining = remaining.dropFirst()
            case "-m", "--message":
                notifArgs.message = remaining.first ?? ""
                remaining = remaining.dropFirst()
            case "--no-sound":
                notifArgs.sound = false
            case "-a", "--activate":
                notifArgs.activate = remaining.first
                remaining = remaining.dropFirst()
            case "-u", "--url":
                notifArgs.url = remaining.first
                remaining = remaining.dropFirst()
            case "--version":
                return .printAndExit(versionText)
            case "-h", "--help":
                return .printAndExit(helpText)
            default:
                if notifArgs.message.isEmpty {
                    notifArgs.message = arg
                }
            }
        }

        if daemonMode || !notifArgs.message.isEmpty {
            return .run(args: notifArgs, daemonMode: daemonMode)
        } else {
            return .error("Error: use --daemon or provide -m <message>")
        }
    }

    static var versionText: String {
        "claude-notify \(AppVersion.current)"
    }

    static var helpText: String {
        """
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
        """
    }
}
