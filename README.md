# claude-notify

A lightweight macOS menu bar app for sending native notifications from the command line. Built for [Claude Code](https://claude.ai/code) hooks but works with any CLI workflow.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- Native macOS notifications with sound
- Menu bar icon with notification history
- Click notification to activate any app (by bundle ID)
- Auto-starts daemon on first notification
- Zero dependencies, single binary

## Installation

### Build from source

```bash
swift build -c release
cp .build/arm64-apple-macosx/release/claude-notify /usr/local/bin/
```

### Grant permissions

On first run, macOS will prompt for notification permissions. Allow them in **System Settings → Notifications → claude-notify**.

## Usage

```bash
# Send a notification
claude-notify -m "Build complete!"

# With custom title
claude-notify -m "Done" -t "My Task"

# Open an app when clicked
claude-notify -m "Ready" -a com.apple.Terminal

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
| `--no-sound` | Disable notification sound |
| `-d, --daemon` | Run as menu bar daemon |

## Claude Code Integration

Add to your Claude Code hooks (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "claude-notify -m 'Claude finished' -a com.apple.Terminal"
          }
        ]
      }
    ]
  }
}
```

## How it works

1. First invocation starts a background daemon (menu bar app)
2. Subsequent calls send messages to the daemon via `DistributedNotificationCenter`
3. Daemon displays native notifications and tracks history in menu bar

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
