cask "paytick" do
  version "1.1.0"
  sha256 "b211888f57696195d1e9d8a6cf0d6558a4070147ce9d872b056852a8add007e9"

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
