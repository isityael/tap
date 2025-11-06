# typed: false
# frozen_string_literal: true

require "language/node"

class FastCli < Formula
  desc "Test your internet connection speed using Netflix's fast.com"
  homepage "https://github.com/sindresorhus/fast-cli"
  url "https://registry.npmjs.org/fast-cli/-/fast-cli-5.0.2.tgz"
  sha256 "94ba89b2bb09edbc24dedddc4d3f0d179240ec7b3d212fcded5f8f73895886b3"
  license "MIT"

  depends_on "node"

  def install
    ENV["PUPPETEER_SKIP_DOWNLOAD"] = "true"
    system "npm", "install", *std_npm_args
    # Prune non-native prebuilt binaries to produce relocatable bottles
    prebuild_glob = "#{libexec}/lib/node_modules/**/prebuilds/*"
    if Hardware::CPU.arm?
      rm_r(Dir[File.join(prebuild_glob, "*-x64*")])
    elsif Hardware::CPU.intel?
      rm_r(Dir[File.join(prebuild_glob, "*-arm64*")])
    end
    # Never ship iOS simulator prebuilds
    rm_r(Dir[File.join(prebuild_glob, "ios-*")])
    # Symlink all npm binaries first
    bin.install_symlink Dir["#{libexec}/bin/*"]

    fast_bin = bin/"fast"
    fast_bin.unlink if fast_bin.exist?

    # Replace 'fast' with a wrapper that sets a Chrome executable if available
    fast_bin.write <<~EOS
      #!/bin/bash
      set -e
      if [ -z "$PUPPETEER_EXECUTABLE_PATH" ]; then
        candidates=(
          "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
          "/Applications/Google Chrome Beta.app/Contents/MacOS/Google Chrome Beta"
          "/Applications/Google Chrome Dev.app/Contents/MacOS/Google Chrome Dev"
          "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary"
        )
        for c in "${candidates[@]}"; do
          if [ -x "$c" ]; then
            export PUPPETEER_EXECUTABLE_PATH="$c"
            break
          fi
        done
      fi
      exec "#{libexec}/bin/fast" "$@"
    EOS
    fast_bin.chmod 0755
  end

  def caveats
    <<~EOS
      fast-cli uses Puppeteer to control Chrome.
      If you see "Could not find Chrome", either:
        1) Run once:  npx puppeteer browsers install chrome
        2) Or set:   export PUPPETEER_EXECUTABLE_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
      This formula also auto-detects Chrome Beta/Dev/Canary under /Applications when available.
    EOS
  end

  test do
    output = shell_output("#{bin}/fast --help")
    assert_match "Usage", output
  end
end
