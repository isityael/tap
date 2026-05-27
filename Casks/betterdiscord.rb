cask "betterdiscord" do
  version "1.3.0"
  sha256 "85bdd7b44f9624f7740af4d26682f21730c47a643fde009f2ad766afa19356b8"

  url "https://github.com/BetterDiscord/Installer/releases/download/v#{version}/BetterDiscord-Mac.zip",
      verified: "github.com/BetterDiscord/Installer/"
  name "BetterDiscord"
  desc "Installer for BetterDiscord"
  homepage "https://betterdiscord.app/"

  # Keep tracking upstream releases
  livecheck do
    url :url
    strategy :github_latest
  end

  conflicts_with cask: "betterdiscord-installer"
  depends_on :macos

  app "BetterDiscord.app"

  preflight do
    editions = [
      "/Applications/Discord.app",
      "/Applications/Discord PTB.app",
      "/Applications/Discord Canary.app",
      "#{Dir.home}/Applications/Discord.app",
      "#{Dir.home}/Applications/Discord PTB.app",
      "#{Dir.home}/Applications/Discord Canary.app",
    ]
    unless editions.any? { |p| File.exist?(p) }
      raise "No Discord installation found (Stable/PTB/Canary). " \
            "Install one before running BetterDiscord Installer."
    end
  end

  uninstall quit: [
    "com.hnc.Discord",
    "com.hnc.DiscordCanary",
    "com.hnc.DiscordPTB",
  ]

  zap trash: [
    "~/Library/Application Support/BetterDiscord Installer",
    "~/Library/Application Support/BetterDiscord",
    "~/Library/Preferences/app.betterdiscord.installer.plist",
    "~/Library/Saved Application State/app.betterdiscord.installer.savedState",
  ]

  caveats do
    requires_rosetta
    <<~EOS
      Supports Discord Stable, PTB and Canary. Ensure at least one of these is installed; the installer will detect installed editions.
      This app may fail Gatekeeper checks (unsigned/not notarized).
      If macOS blocks it, use: Right-click → Open (once), or install with:
        HOMEBREW_CASK_OPTS="--no-quarantine" brew install --cask yaelmoshi/tap/betterdiscord-installer
    EOS
  end
end
