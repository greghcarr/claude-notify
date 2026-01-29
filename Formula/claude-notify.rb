class ClaudeNotify < Formula
  desc "macOS menu bar notification daemon for Claude Code"
  homepage "https://github.com/armandsalle/claude-notify"
  url "https://github.com/armandsalle/claude-notify/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/claude-notify"
  end

  test do
    assert_match "Usage:", shell_output("#{bin}/claude-notify --help")
  end
end
