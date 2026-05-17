#!/bin/bash
#
# Claude Code notification hook. Picks the right activation target for the
# terminal Claude Code is running inside, with IDE workspaces preferred over
# bare app activation when the URL scheme is available.
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
#       ]
#     }
#   }
#
# Adjust CLI_PATH below if claude-notify is installed elsewhere.

set -u

CLI_PATH="/Applications/ClaudeNotify.app/Contents/MacOS/ClaudeNotify"
MESSAGE="${1:-Claude finished}"

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
