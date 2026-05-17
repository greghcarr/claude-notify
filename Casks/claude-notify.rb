cask "claude-notify" do
  version "1.1.4"
  sha256 "dfece21feecf4ff2aca824ee168f235d04c172f9304979677f5450506951fde8"

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
