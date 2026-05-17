# Changelog

All notable changes to this fork.

## 1.1.3

### Added
- Prebuilt `.app` bundle attached to each GitHub release. No Xcode required to install.
- Homebrew Cask at `Casks/claude-notify.rb` distributed via a separate tap repo. Install with `brew install --cask greghcarr/tap/claude-notify`.
- Troubleshooting section in the README covering the macOS Show Previews gotcha, the ad-hoc-signed Gatekeeper warning, notification permissions, and the LaunchAgent KeepAlive respawn behavior.

### Removed
- The old source-build `Formula/claude-notify.rb` (was never functional: a Homebrew Formula installs the bare binary to `bin/`, but the app needs the `.app` bundle wrapper for `UNUserNotificationCenter` to deliver notifications). Replaced by the Cask, which installs the prebuilt `.app` directly into `/Applications/`.

## 1.1.2

### Changed
- Hook script (`examples/claude-code-notify.sh`) sets the notification title to the workspace folder name so users with multiple Claude Code sessions can identify the source at a glance.
- Hook script detects VS Code and Cursor via `VSCODE_PID` and `VSCODE_IPC_HOOK` in addition to `TERM_PROGRAM` and `CURSOR_TRACE_ID`. Claude Code's hook subprocess does not inherit `TERM_PROGRAM`; previously this caused hook-fired notifications to fall through to the bare-fallback branch with no `-u` URL, so click-to-activate did nothing.
- Hook script prefers `CLAUDE_PROJECT_DIR` over `$PWD` for both title and URL path, since `$PWD` inside a hook is not always the workspace root.

## 1.1.1

### Changed
- Hook script reads Claude Code's JSON event payload on stdin and uses the actual `message` field as the notification body. Previously it always said "Claude finished" regardless of event. Falls back to event-appropriate defaults when the payload is missing or has no message. Manual invocation with a positional arg (e.g. `notify.sh "Test"`) still uses the arg and skips stdin parsing.

## 1.1.0

### Added
- `-u, --url <url>` flag: open a URL on notification click. Supports `vscode://file/<path>`, `cursor://file/<path>`, web links, and any other URL scheme registered on the system. Overrides `-a` when both are provided. Targets a specific window for IDE workspaces (no more "just bring VS Code to front and hope it picks the right window").
- `--version` flag: prints the current version and exits.
- App icon: the Claude logomark on a warm cream rounded square, baked into the bundle's `.icns` so it shows on notification banners, in Notification Center, and in Finder.
- Ships [examples/claude-code-notify.sh](examples/claude-code-notify.sh): a ready-made Claude Code hook script that auto-detects the host terminal (VS Code, Cursor, Ghostty, Terminal, iTerm2) and constructs a workspace-targeting URL when running inside an IDE.
- GitHub Actions CI: `swift build`, `swift test`, `./build.sh`, and Info.plist validation on every push to `main`/`dev` and on PRs.

### Changed
- Default no-argument launch (`open /Applications/ClaudeNotify.app`, Finder double-click, LaunchAgent without `ProgramArguments`) now starts the menu bar daemon instead of exiting silently with an error.
- Info.plist is now a versioned file at [Resources/Info.plist](Resources/Info.plist) instead of being heredoc-emitted by `build.sh`. Future plist changes are reviewable plist diffs.
- IPC payload between the CLI client and the daemon is a single Codable struct serialized to JSON, replacing the previous stringly-typed `[String: Any]` dictionary. Adding a field is a one-line schema change.

### Internal
- `AppDelegate` decomposed into focused types: `NotificationHistory`, `MenuBarController`, `IPCListener`, `NotificationDispatcher`, `SoundPlayer` (protocol + `AfplaySoundPlayer` default impl), and `AppActivator`. `main.swift` drops from a 380-line god class to a ~50-line wiring delegate plus a CLI parser.
- CLI parser extracted to a pure function returning a `CLIResult` enum; covered by 19 unit tests.
- Test target with XCTest covering `NotificationHistory`, `IPCMessage` round-tripping (including unicode and decode-failure paths), and the CLI parser (34 tests total).
- Magic values consolidated into a single `Constants` namespace.
- `DEVELOPMENT.md` documents branching, commit cadence, versioning, and how-to recipes for adding flags or notification features.
