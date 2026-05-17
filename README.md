# claude-notify

A lightweight macOS menu bar app for sending native notifications from the command line. Built for [Claude Code](https://claude.ai/code) hooks but works with any CLI workflow.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- Native macOS notifications with sound
- Menu bar icon with notification history
- Click notification to activate any app (by bundle ID) or open a URL (`vscode://`, `cursor://`, `https://`, etc.)
- Single instance (lock file prevents duplicates)
- Auto-start at login via LaunchAgent
- Zero dependencies, single binary

## Installation

### Build from source

```bash
./build.sh
cp -r .build/release/ClaudeNotify.app /Applications/
codesign --force --deep --sign - /Applications/ClaudeNotify.app
```

### Add CLI alias

Add to `~/.zshrc`:

```bash
alias claude-notify='/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify'
```

### Auto-start at login (optional)

```bash
cp com.claude.notify.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.claude.notify.plist
```

### Grant permissions

On first notification, macOS will prompt for notification permissions. Allow them in **System Settings → Notifications → ClaudeNotify**.

## Usage

```bash
# Send a notification
claude-notify -m "Build complete!"

# With custom title
claude-notify -m "Done" -t "My Task"

# Open an app when clicked
claude-notify -m "Ready" -a com.apple.Terminal

# Open the specific VS Code workspace when clicked (overrides -a)
claude-notify -m "Build complete" -u "vscode://file//Users/me/projects/myrepo"

# Open a web link when clicked
claude-notify -m "PR ready" -u "https://github.com/me/repo/pull/42"

# Silent notification
claude-notify -m "Background task done" --no-sound

# Run as daemon only (menu bar)
claude-notify --daemon
```

### Options

| Flag | Description |
|------|-------------|
| `-m, --message <text>` | Notification message (required) |
| `-t, --title <text>` | Notification title (default: "Claude Code") |
| `-a, --activate <bundle-id>` | App to activate on click |
| `-u, --url <url>` | URL to open on click (overrides `-a`; supports `vscode://`, `cursor://`, `https://`, etc.) |
| `--no-sound` | Disable notification sound |
| `-d, --daemon` | Run as menu bar daemon |
| `--version` | Print version and exit |

## Claude Code Integration

### Basic (hardcoded app)

Add to your Claude Code hooks (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "claude-notify -m 'Claude finished' -a com.todesktop.230313mzl4w4u92"
          }
        ]
      }
    ]
  }
}
```

### Auto-detect terminal (recommended)

A ready-made hook script lives at [examples/claude-code-notify.sh](examples/claude-code-notify.sh). It detects which terminal Claude Code is running inside and picks the best click target:

- **VS Code or Cursor**: opens the *specific workspace window* via `vscode://file/<workspace>` or `cursor://file/<workspace>`, not just whichever IDE window happened to be frontmost.
- **Ghostty, Terminal, iTerm2**: activates the app by bundle ID.
- **Anything else**: falls back to the `__CFBundleIdentifier` environment variable, then to no click target if that is also missing.

The notification body comes from Claude Code's hook payload: for `Notification` events it surfaces the actual prompt (e.g. "Claude needs your permission to use Bash"), for `Stop` events it shows "Claude finished".

Install:

```bash
mkdir -p ~/.claude/hooks
cp examples/claude-code-notify.sh ~/.claude/hooks/notify.sh
chmod +x ~/.claude/hooks/notify.sh
```

Wire into Claude Code (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/notify.sh"
          }
        ]
      }
    ]
  }
}
```

## How it works

1. First invocation starts a background daemon (menu bar app)
2. Lock file (`/tmp/claude-notify.lock`) ensures single instance
3. Subsequent calls send messages to the daemon via `DistributedNotificationCenter`
4. Daemon displays native notifications and tracks history in menu bar
5. Sound played via `afplay` for reliability

## LaunchAgent commands

```bash
# Stop daemon
launchctl unload ~/Library/LaunchAgents/com.claude.notify.plist

# Start daemon
launchctl load ~/Library/LaunchAgents/com.claude.notify.plist

# Check status
launchctl list | grep claude
```

## Common Bundle IDs

| App | Bundle ID |
|-----|-----------|
| Terminal | `com.apple.Terminal` |
| iTerm2 | `com.googlecode.iterm2` |
| VS Code | `com.microsoft.VSCode` |
| Cursor | `com.todesktop.230313mzl4w4u92` |
| Warp | `dev.warp.Warp-Stable` |

Find any app's bundle ID:
```bash
osascript -e 'id of app "AppName"'
```

## License

MIT
