cask "moshi-zenmap" do
  version "7.98"
  sha256 "461bb256780aa8c5e76f95010b780e5fd58743dd74432b17c97a1ca525722b7b"

  url "https://nmap.org/dist/nmap-#{version}.dmg"
  name "Zenmap"
  desc "Multi-platform graphical interface for official Nmap Security Scanner"
  homepage "https://nmap.org/zenmap/"

  livecheck do
    url "https://nmap.org/dist/"
    regex(/nmap[._-]v?(\d+(?:\.\d+)+)\.dmg/i)
  end

  conflicts_with cask: "zenmap"

  pkg "nmap-#{version}.mpkg"

  uninstall quit:    "org.insecure.Zenmap",
            pkgutil: [
              "org.insecure.nmap",
              "org.insecure.nmap.ncat",
              "org.insecure.nmap.nping",
              "org.insecure.nmap.zenmap",
            ],
            delete:  "/Applications/Zenmap.app"

  zap trash: [
    "~/.zenmap",
    "~/Library/Preferences/org.insecure.Zenmap.plist",
    "~/Library/Saved Application State/org.insecure.Zenmap.savedState",
  ]

  caveats do
    requires_rosetta
    <<~EOS
      Zenmap is bundled inside the Nmap #{version} installer but currently
      reports its own version as 7.97 in the About dialog. This is expected
      and due to upstream not updating Zenmap’s internal version string.
    EOS
  end
end
