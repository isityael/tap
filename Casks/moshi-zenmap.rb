cask "moshi-zenmap" do
  version "7.98"
  sha256 "461bb256780aa8c5e76f95010b780e5fd58743dd74432b17c97a1ca525722b7b"

  url "https://nmap.org/dist/nmap-#{version}.dmg"
  name "Zenmap"
  desc "Multi-platform graphical interface for official Nmap Security Scanner"
  homepage "https://nmap.org/zenmap/"

  livecheck do
    url "https://nmap.org/download"
    regex(/href=['"]?[^'">]*nmap[._-]v?(\d+(?:\.\d+)+)\.dmg/i)
  end

  conflicts_with cask: "zenmap"

  pkg "nmap-#{version}.mpkg"

  uninstall pkgutil: [
              "org.nmap.ncat",
              "org.nmap.ndiff",
              "org.nmap.nmap",
              "org.nmap.nping",
              "org.nmap.zenmap",
            ],
            delete:  "/Applications/Zenmap.app"

  zap trash: [
    "~/.zenmap",
    "~/Library/Preferences/org.nmap.zenmap.plist",
    "~/Library/Saved Application State/org.nmap.zenmap.savedState",
  ]

  caveats do
    requires_rosetta
  end
  caveats <<~EOS
    Zenmap is bundled inside the Nmap #{version} installer but currently
    reports its own version as 7.97 in the About dialog. This is expected
    and due to upstream not updating Zenmap’s internal version string.
  EOS
end
