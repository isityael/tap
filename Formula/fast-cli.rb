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
    system "npm", "install", *std_npm_args
    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    output = shell_output("#{bin}/fast --help")
    assert_match "Usage", output
  end
end
