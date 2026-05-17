# Development

## Branches

- `main`: releasable, tagged.
- `dev`: daily work, merges to `main` on release.

Day-to-day work happens on `dev` or short-lived feature branches off `dev`. `main` only advances when a release is cut.

## Commands

```
swift build                                    # debug build
swift build -c release                         # release binary
./build.sh                                     # release binary + .app bundle in .build/release/
swift test                                     # run unit tests (once a Tests/ target exists)
```

## Install locally

```
./build.sh
cp -r .build/release/ClaudeNotify.app /Applications/
codesign --force --deep --sign - /Applications/ClaudeNotify.app
```

Add a CLI shim to `~/.zshrc`:

```
alias claude-notify='/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify'
```

## Auto-start at login

```
cp com.claude.notify.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.claude.notify.plist
```

Unload before reinstalling a new build, otherwise the old daemon keeps the lock:

```
launchctl unload ~/Library/LaunchAgents/com.claude.notify.plist
```

## Adding a CLI flag

1. Add the parser case in the argument loop in [Sources/main.swift](Sources/main.swift).
2. Add the field to `NotificationArgs` (or its successor request struct) with a sensible default.
3. If the flag affects the daemon, propagate it through `sendToDaemon` -> `handleCommand`. Both ends of the IPC contract must agree.
4. Update the `--help` text and the README options table.

## Adding a notification feature

1. Decide whether it lives in the client (one-shot CLI) or daemon (menu bar, history, IPC handler). Most new features are daemon-side.
2. If it changes the IPC payload, update the shared message contract and both encode/decode sites in one commit. Old clients sending an older payload should still parse.
3. If it adds a tunable value, add a named constant. No magic numbers or strings.

## House rules

- No em dashes or en dashes anywhere (code, comments, docs). Use commas, parentheses, colons, or separate sentences.
- No magic numbers or strings. Extract to named constants in a single `Constants` namespace (or a focused enum per concern).
- Single-responsibility types. If a class crosses about 80 lines or owns more than one concern, split it.
- No defensive error handling for impossible cases. Trust the type system. Only validate at boundaries (CLI input, IPC payload decode).
- Default to no comments. Add one only when the *why* is non-obvious (workarounds for platform bugs, hidden invariants). Self-documenting names over commentary.

## Versioning

Format: `MAJOR.MINOR.PATCH[-pre-alpha|-alpha|-beta]`.

The version is stored in `Package.swift` (or a sibling `Version.swift` constant) and surfaced by `claude-notify --version`. The `.app` bundle's `CFBundleShortVersionString` in `Info.plist` must match. Keep them in sync; bumping one without the other is a release blocker.

Bump on user-visible changes, not on every commit to `dev`.

## Commit pattern

Single units of work per commit. A commit that touches the IPC contract on both ends is one unit. A commit that adds a flag, updates the help text, and updates the README is one unit. A commit that does two unrelated refactors is two commits.

Commit messages: imperative mood, one-line summary, body only if the *why* is not obvious from the diff.

## Release

1. Bump version in `Package.swift` and `Info.plist` template in [build.sh](build.sh) in one commit on `dev`.
2. Update `CHANGELOG.md` in the same commit.
3. Merge `dev` into `main`.
4. Tag `vX.Y.Z` on `main`, push the tag.
5. If publishing the Homebrew formula, update the `url` and `sha256` in [Formula/claude-notify.rb](Formula/claude-notify.rb) on `main` after the tag exists.
