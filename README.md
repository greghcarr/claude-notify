# claude-notify

A lightweight macOS menu bar app for sending native notifications from the command line. Built for [Claude Code](https://claude.ai/code) hooks but works with any CLI workflow.

[![CI](https://github.com/greghcarr/claude-notify/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/greghcarr/claude-notify/actions/workflows/ci.yml)
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

### Homebrew (recommended)

```bash
brew install --cask greghcarr/tap/claude-notify
```

That downloads the prebuilt `.app` from the latest release and installs it to `/Applications`. macOS will block the first launch with a "developer cannot be verified" warning because the binary is ad-hoc signed; see [Troubleshooting](#troubleshooting).

### Download the prebuilt .app

Grab `ClaudeNotify-1.1.3.zip` from the [latest release](https://github.com/greghcarr/claude-notify/releases/latest) and drop `ClaudeNotify.app` into `/Applications/`.

### Build from source

Needs Xcode command-line tools (Swift 5.9+).

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

**Verified terminals:** the VS Code Claude Code extension (the maintainer's daily driver). The Cursor / Ghostty / Apple Terminal / iTerm2 / `__CFBundleIdentifier` branches are constructed by analogy but not personally tested. Issues and PRs welcome if a branch isn't routing correctly in your setup.

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

## Troubleshooting

### Banner shows "Claude Notify" / "Notification" instead of the real content

macOS's notification privacy setting is hiding the content. Open **System Settings → Notifications → ClaudeNotify**, find **Show Previews**, and set it to **Always**. The default "When Unlocked" replaces the title and body with the bundle name + the literal word "Notification" in some Focus and lock states.

### First launch is blocked: "ClaudeNotify cannot be opened because the developer cannot be verified"

The `.app` is signed ad-hoc, not notarized. Right-click the `.app` in Finder and choose **Open** (instead of double-clicking) the first time; macOS gives you an Open button in the dialog. After that first allow, it launches normally.

### No notifications appear at all

Open **System Settings → Notifications → ClaudeNotify** and confirm **Allow Notifications** is on. If ClaudeNotify isn't in the list at all, the app hasn't been registered yet — launch it once via `open /Applications/ClaudeNotify.app` (or by sending a notification) and accept the permission prompt.

### Clicking a notification doesn't focus the right VS Code window

The hook script needs the env vars Claude Code sets in its hook subprocess (`VSCODE_PID` or `CLAUDE_PROJECT_DIR`). If you wrote a custom hook and click-to-activate isn't routing correctly, use the bundled [examples/claude-code-notify.sh](examples/claude-code-notify.sh) which has the detection wired up.

### Two daemons running / changes don't take effect after rebuild

The LaunchAgent's `KeepAlive: true` setting respawns the daemon as soon as you `killall ClaudeNotify`, and the respawn loads whichever binary was on disk at that moment. To install a new build, unload the agent first:

```bash
launchctl unload ~/Library/LaunchAgents/com.claude.notify.plist
killall ClaudeNotify 2>/dev/null
cp -r .build/release/ClaudeNotify.app /Applications/
codesign --force --deep --sign - /Applications/ClaudeNotify.app
launchctl load ~/Library/LaunchAgents/com.claude.notify.plist
```

## License

MIT
