# typed: false
# frozen_string_literal: true

class AppleMailMcp < Formula
  desc "MCP server for Apple Mail — natural language email management"
  homepage "https://git.m0sh1.cc/isityael/apple-mail-mcp"
  url "https://git.m0sh1.cc/isityael/apple-mail-mcp/archive/v2.7.6.tar.gz"
  sha256 "f561b31018f00537d9b515ad2a04b347d817cf2a4f2c9c4da81cf722917273d7"
  license "Apache-2.0"

  depends_on :macos
  depends_on "uv"

  def install
    # Install all source files into libexec
    libexec.install Dir["*"]

    # Create wrapper script in bin
    (bin/"apple-mail-mcp").write <<~EOS
      #!/bin/bash
      set -e
      exec "#{libexec}/start_mcp.sh" "$@"
    EOS
    (bin/"apple-mail-mcp").chmod 0755
  end

  def caveats
    <<~EOS
      Apple Mail MCP requires macOS with Apple Mail configured.

      To use with Claude Desktop, add to your MCP config:
        {
          "apple-mail-mcp": {
            "command": "#{opt_bin}/apple-mail-mcp"
          }
        }

      To use with Claude Code:
        claude mcp add apple-mail-mcp #{opt_bin}/apple-mail-mcp

      On first run, macOS will prompt for Mail.app access permissions.
    EOS
  end

  test do
    # Verify the start script exists and is executable
    assert_predicate libexec/"start_mcp.sh", :executable?
    # Verify the Python entry point exists
    assert_path_exists libexec/"apple_mail_mcp.py"
  end
end
