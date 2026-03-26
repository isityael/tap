cask "headlamp" do
  version "0.41.0"

  on_arm do
    sha256 "bb109455be76ca5e9839ef692caf8079cc3cf08abd159de5acec079a6b60ce58"

    url "https://github.com/kubernetes-sigs/headlamp/releases/download/v#{version}/Headlamp-#{version}-mac-arm64.dmg",
        verified: "github.com/kubernetes-sigs/headlamp/"
  end
  on_intel do
    sha256 "9b8d8762e0b23ca93abea88412d5f0f250030b094cabe4c7a25cfe90fa63d2ce"

    url "https://github.com/kubernetes-sigs/headlamp/releases/download/v#{version}/Headlamp-#{version}-mac-x64.dmg",
        verified: "github.com/kubernetes-sigs/headlamp/"
  end

  name "Headlamp"
  desc "Kubernetes cluster management GUI"
  homepage "https://headlamp.dev/"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "Headlamp.app"

  uninstall quit: "dev.headlamp.app"

  zap trash: [
    "~/Library/Application Support/Headlamp",
    "~/Library/Preferences/dev.headlamp.app.plist",
    "~/Library/Saved Application State/dev.headlamp.app.savedState",
  ]
end
