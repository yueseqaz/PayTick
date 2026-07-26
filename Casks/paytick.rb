cask "paytick" do
  version "1.0.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256_AFTER_RELEASE"

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
