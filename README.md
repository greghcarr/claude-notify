# claude-notify

A lightweight macOS menu bar app for sending native notifications from the command line. Built for [Claude Code](https://claude.ai/code) hooks but works with any CLI workflow.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- Native macOS notifications with sound
- Menu bar icon with notification history
- Click notification to activate any app (by bundle ID)
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
            "command": "claude-notify -m 'Claude finished' -a com.todesktop.230313mzl4w4u92"
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
