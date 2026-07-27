cask "paytick" do
  version "1.3.0"
  sha256 "bed41ddd0fe3b2ef5cdb411dd768f579ba906e1a24023974e246636689398532"

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
