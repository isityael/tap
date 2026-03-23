cask "yoursecurecloud-drive" do
  version "3.0.18"
  sha256 :no_check

  url "https://www.yoursecurecloud.de/client/latest/ysc_drive_client_latest.pkg",
      verified: "yoursecurecloud.de/client/"
  name "YourSecureCloud Drive"
  desc "Virtual drive client for YourSecureCloud (SeaDrive-based)"
  homepage "https://www.securecloud.de/"

  # No livecheck — download URL is versionless (/latest/), no release feed.
  # Version discovered from PKG Distribution metadata.
  # To check for updates: pkgutil --expand the PKG and inspect Distribution XML.

  conflicts_with cask: "seadrive"
  depends_on macos: ">= :catalina"

  pkg "ysc_drive_client_latest.pkg"

  uninstall launchctl:  "com.seafile.seadrive.helper",
            quit:       [
              "com.seafile.seadrive",
              "com.seafile.seadrive.fprovider",
            ],
            login_item: "SeaDrive",
            pkgutil:    "com.seafile.SeaDrive",
            delete:     "/Applications/SeaDrive.app"

  zap trash: [
    "~/.seadrive",
    "~/Library/Application Scripts/*.com.seafile.seadrive",
    "~/Library/Application Scripts/com.seafile.seadrive.findersync",
    "~/Library/Application Scripts/com.seafile.seadrive.fprovider",
    "~/Library/Containers/com.seafile.seadrive.findersync",
    "~/Library/Containers/com.seafile.seadrive.fprovider",
    "~/Library/Group Containers/*.com.seafile.seadrive",
    "~/Library/Group Containers/com.seafile.seadrive.findersync",
    "~/SeaDrive",
  ]
end
