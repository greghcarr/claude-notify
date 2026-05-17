# CLAUDE.md

Guidance for Claude Code when working in this repository. For workflow (branching, commits, install, release), see [DEVELOPMENT.md](DEVELOPMENT.md).

## What this is

A macOS menu bar daemon that turns CLI invocations into native notifications, built for Claude Code hooks but useful for any CLI workflow.

One binary, two modes:

- **Daemon** (`--daemon`): runs as an `LSUIElement` menu bar app, owns notification delivery and history.
- **Client** (`-m <message>`): one-shot. If a daemon holds the lock, posts the message via IPC and exits. Otherwise it becomes the daemon and sends.

Single instance is enforced by `flock()` on `/tmp/claude-notify.lock`.

## Stack

- Swift 5.9+, Cocoa/AppKit, `UNUserNotificationCenter`
- macOS 13+ (Ventura)
- Zero SPM dependencies. Reach for a dep only when the in-house equivalent is clearly more expensive than the dep cost.

## Architecture invariants

These are load-bearing. Touch them carefully.

1. **The `.app` bundle is mandatory for delivery.** `UNUserNotificationCenter` will not deliver from a bare binary. The wrapper produced by [build.sh](build.sh) provides the required `Info.plist` and `LSUIElement` flag. Bare `swift run` is debug-only.
2. **IPC is the boundary between daemon and client.** They are two invocations of the same binary that only meet at `DistributedNotificationCenter` with name `com.claude.notify.send`. Any change to the payload must update both encode and decode sites in the same commit, and must remain parseable when an older client talks to a newer daemon.
3. **Sound is played via `afplay`, not `UNNotificationSound.default`.** The system path is unreliable; the shell-out is the workaround. Do not revert without testing on a real install. The inline comment in [Sources/main.swift](Sources/main.swift) is the canonical example of when a comment earns its keep.
4. **Lock file release is exit-bound.** The OS releases `flock` on process exit. The long-lived daemon never runs its singleton's `deinit`, so cleanup there is dead code, not a safety net.

## File map

- [Sources/main.swift](Sources/main.swift): app code.
- [Package.swift](Package.swift): SPM manifest.
- [build.sh](build.sh): release build and `.app` bundle assembly.
- [com.claude.notify.plist](com.claude.notify.plist): LaunchAgent for auto-start at login.
- [Formula/claude-notify.rb](Formula/claude-notify.rb): Homebrew formula (publication pending).
- [DEVELOPMENT.md](DEVELOPMENT.md): branching, commands, install, release, house rules.
- [README.md](README.md): user-facing documentation.

## Conventions

- No magic numbers or strings. Extract to named constants.
- Single-responsibility types. Split when a class crosses about 80 lines or owns more than one concern.
- No defensive error handling for cases the type system already prevents. Validate only at boundaries (CLI input, IPC decode).
- Default to no comments. Add one only when the *why* is non-obvious. The `afplay` workaround comment is the model.
- Markdown links for file references, not backtick paths.
- No em or en dashes anywhere.

See [DEVELOPMENT.md](DEVELOPMENT.md) for the full house rules and how-to recipes.

## Build (quick reference)

```
swift build                   # debug
./build.sh                    # release + .app bundle in .build/release/
```

Full install and release procedure lives in [DEVELOPMENT.md](DEVELOPMENT.md).
