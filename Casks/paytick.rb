cask "paytick" do
  version "1.4.0"
  sha256 "ef4c3537a31e8bcc64472bcdc56e5d51c98afdf0d0951e34c75cbc659221d83b"

  url "https://github.com/yueseqaz/PayTick/releases/download/v#{version}/PayTick-#{version}.dmg"
  name "PayTick"
  desc "macOS menu bar app that ticks your earnings in real time"
  homepage "https://github.com/yueseqaz/PayTick"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "PayTick.app"

  zap trash: [
    "~/Library/Preferences/com.sakura.paytick.plist",
    "~/Library/Application Support/com.sakura.paytick",
    "~/Library/Caches/com.sakura.paytick",
  ]
end
