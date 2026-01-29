# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build release binary
swift build -c release

# Build debug binary
swift build

# Run directly (debug)
swift run claude-notify --help
```

The release binary is located at `.build/arm64-apple-macosx/release/claude-notify`.

## Architecture

A macOS menu bar notification daemon for Claude Code, written in Swift using Cocoa/AppKit.

**Single-file design**: All code lives in `Sources/main.swift` (~300 lines).

**Two modes of operation**:
1. **Daemon mode** (`--daemon`): Runs as a menu bar app, listens for notifications via `DistributedNotificationCenter`
2. **Client mode** (`-m <message>`): Sends notification to running daemon, or starts daemon + sends if not running

**Key components in `main.swift`**:
- `AppDelegate`: NSApplicationDelegate managing menu bar UI, notification center, and IPC
- `NotificationArgs`: Simple struct for notification parameters
- CLI argument parsing at file bottom (no external dependencies)

**IPC**: Uses `DistributedNotificationCenter` with notification name `com.claude.notify.send` to communicate between client invocations and the daemon.

## Requirements

- macOS 13+ (Ventura)
- Swift 5.9+
