cask "moshi-exifcleaner" do
  version "3.6.0"
  sha256 "459b296b000a7cd614713772e9b4ecf1604d3bb10926ab2346e8ea88e44df323"

  url "https://github.com/szTheory/exifcleaner/releases/download/v#{version}/ExifCleaner-#{version}.dmg",
      verified: "github.com/szTheory/exifcleaner/"
  name "ExifCleaner"
  desc "GUI to remove metadata from images, videos, and PDFs"
  homepage "https://exifcleaner.com/"

  livecheck do
    url :url
    strategy :github_latest
  end

  conflicts_with cask: "exifcleaner"
  # Upstream ships Intel-only; Apple Silicon users need Rosetta.
  depends_on macos: ">= :el_capitan"

  app "ExifCleaner.app"

  postflight do
    target = "#{appdir}/ExifCleaner.app"
    if File.exist?(target)
      system_command "/usr/bin/xattr",
                     args: ["-dr", "com.apple.quarantine", target],
                     print_stdout: true, print_stderr: true
    end
  end

  uninstall quit: "com.exifcleaner.ExifCleaner"

  zap trash: [
    "~/Library/Application Support/ExifCleaner",
    "~/Library/Preferences/com.exifcleaner.ExifCleaner.plist",
    "~/Library/Saved Application State/com.exifcleaner.ExifCleaner.savedState",
  ]

  caveats do
    requires_rosetta
    <<~EOS
      This app is not notarized upstream. The cask runs
      `xattr -dr com.apple.quarantine` automatically after install
      to allow launching. If you prefer Apple’s standard Gatekeeper
      flow, comment out the `postflight` stanza and right-click → Open.
    EOS
  end
end
