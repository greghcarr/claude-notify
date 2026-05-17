#!/bin/bash
#
# Claude Code notification hook. Picks the right activation target for the
# terminal Claude Code is running inside, with IDE workspaces preferred over
# bare app activation when the URL scheme is available.
#
# When invoked by Claude Code, parses the JSON event payload on stdin and
# uses its "message" field as the notification body. Falls back to
# event-appropriate defaults if the payload is missing or has no message.
#
# When invoked manually with `notify.sh "Some message"`, uses the positional
# argument as the message body (useful for testing).
#
# Install:
#   mkdir -p ~/.claude/hooks
#   cp examples/claude-code-notify.sh ~/.claude/hooks/notify.sh
#   chmod +x ~/.claude/hooks/notify.sh
#
# Wire into Claude Code by adding to ~/.claude/settings.json:
#
#   {
#     "hooks": {
#       "Notification": [
#         { "hooks": [ { "type": "command", "command": "~/.claude/hooks/notify.sh" } ] }
#       ],
#       "Stop": [
#         { "hooks": [ { "type": "command", "command": "~/.claude/hooks/notify.sh" } ] }
#       ]
#     }
#   }
#
# Adjust CLI_PATH below if claude-notify is installed elsewhere.

set -u

CLI_PATH="/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify"

if [ -n "${1:-}" ]; then
    MESSAGE="$1"
else
    MESSAGE=$(/usr/bin/python3 -c '
import sys, json
try:
    data = json.load(sys.stdin)
except Exception:
    print("Claude Code event")
    sys.exit()
event = data.get("hook_event_name", "")
msg = data.get("message", "")
if msg:
    print(msg)
elif event == "Stop":
    print("Claude finished")
elif event == "Notification":
    print("Claude needs your input")
else:
    print(event or "Claude Code event")
')
fi

# vscode:// and cursor:// expect file:// style absolute paths. Encode the
# space character so paths like /Users/me/Visual Studio Code/repo work.
ENCODED_PWD="${PWD// /%20}"

if [[ -n "${CURSOR_TRACE_ID:-}" ]]; then
    "$CLI_PATH" -m "$MESSAGE" -u "cursor://file/${ENCODED_PWD}" &
elif [[ "${TERM_PROGRAM:-}" == "vscode" ]]; then
    "$CLI_PATH" -m "$MESSAGE" -u "vscode://file/${ENCODED_PWD}" &
elif [[ "${TERM_PROGRAM:-}" == "ghostty" ]]; then
    "$CLI_PATH" -m "$MESSAGE" -a com.mitchellh.ghostty &
elif [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]]; then
    "$CLI_PATH" -m "$MESSAGE" -a com.apple.Terminal &
elif [[ "${TERM_PROGRAM:-}" == "iTerm.app" ]]; then
    "$CLI_PATH" -m "$MESSAGE" -a com.googlecode.iterm2 &
elif [[ -n "${__CFBundleIdentifier:-}" ]]; then
    "$CLI_PATH" -m "$MESSAGE" -a "$__CFBundleIdentifier" &
else
    "$CLI_PATH" -m "$MESSAGE" &
fi
