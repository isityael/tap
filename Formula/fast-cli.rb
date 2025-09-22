# typed: false
# frozen_string_literal: true

require "language/node"

class FastCli < Formula
  desc "Test your internet connection speed using Netflix's fast.com"
  homepage "https://github.com/sindresorhus/fast-cli"
  url "https://registry.npmjs.org/fast-cli/-/fast-cli-5.0.1.tgz"
  sha256 "154cecdfc2f0a0465d6a34dd2b231ada73a24166ef0d7458dd4fb54640f9ffa7"
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
