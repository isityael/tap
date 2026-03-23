cask "yoursecurecloud" do
  version "9.0.2"
  sha256 :no_check

  url "https://www.yoursecurecloud.de/client/latest/ysc_osx.dmg",
      verified: "yoursecurecloud.de/client/"
  name "YourSecureCloud"
  desc "Cloud sync client for YourSecureCloud (Seafile-based)"
  homepage "https://www.securecloud.de/"

  # No livecheck — download URL is versionless (/latest/), no release feed.
  # Version discovered from CFBundleShortVersionString in the DMG.
  # To check for updates: mount the DMG and inspect Info.plist.

  conflicts_with cask: "seafile-client"

  app "YourSecureCloud.app"

  uninstall quit: "com.seafile.seafile-client"

  zap trash: [
    "~/.ccnet",
    "~/Library/Application Support/Seafile",
    "~/Library/Preferences/com.seafile.seafile-client.plist",
    "~/Library/Saved Application State/com.seafile.seafile-client.savedState",
  ]
end
