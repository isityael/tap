# typed: false
# frozen_string_literal: true

require "language/node"

class FastCli < Formula
  desc "Test your internet connection speed using Netflix's fast.com"
  homepage "https://github.com/sindresorhus/fast-cli"
  url "https://registry.npmjs.org/fast-cli/-/fast-cli-5.0.2.tgz"
  sha256 "aa7534a7bfbf74a7b3a5174cc1f7b32df36f0fd2af22e1daab7e85748c8d4c62"
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
