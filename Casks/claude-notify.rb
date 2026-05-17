cask "claude-notify" do
  version "1.1.3"
  sha256 "57805144f6672383b21fa65335c7715cbfef902761b4277f94b9b3b21b2e0d1a"

  url "https://github.com/greghcarr/claude-notify/releases/download/v#{version}/ClaudeNotify-#{version}.zip"
  name "Claude Notify"
  desc "macOS menu bar notification daemon for Claude Code"
  homepage "https://github.com/greghcarr/claude-notify"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "ClaudeNotify.app"

  uninstall quit: "com.claude.notify"

  zap trash: [
    "~/Library/LaunchAgents/com.claude.notify.plist",
    "/tmp/claude-notify.lock",
  ]
end
