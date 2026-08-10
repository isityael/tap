#!/usr/bin/env bash
# bottle-arm.sh — build an ARM64 bottle and return its generated files
# Called by Woodpecker CI via SSH on the Mac builder.
# Usage: bottle-arm.sh <repo-dir> <output-dir>
set -euo pipefail

REPO_DIR="${1:?Usage: bottle-arm.sh <repo-dir>}"
OUTPUT_DIR="${2:?Usage: bottle-arm.sh <repo-dir> <output-dir>}"
cd "${REPO_DIR}"
mkdir -p "${OUTPUT_DIR}"

# Extract version from formula
VERSION=$(ruby -e 'puts File.read("Formula/fast-cli.rb")[/fast-cli-([\d.]+)\.tgz/, 1]')
echo "==> Building bottle for fast-cli ${VERSION}"

# Point Homebrew tap at our checkout (backup existing)
TAP_DIR="$(brew --repository)/Library/Taps/isityael/homebrew-tap"
if [[ -e "${TAP_DIR}" ]] || [[ -L "${TAP_DIR}" ]]
then
  mv "${TAP_DIR}" "${TAP_DIR}.ci-backup"
fi
ln -sfn "${REPO_DIR}" "${TAP_DIR}"

cleanup() {
  echo "==> Cleaning up"
  brew uninstall fast-cli 2>/dev/null || true
  rm -f "${TAP_DIR}"
  if [[ -e "${TAP_DIR}.ci-backup" ]]
  then
    mv "${TAP_DIR}.ci-backup" "${TAP_DIR}"
  fi
}
trap cleanup EXIT

# Build bottle (ARM64 only)
cd "${OUTPUT_DIR}"
brew uninstall fast-cli 2>/dev/null || true
HOMEBREW_NO_AUTO_UPDATE=1 brew install --build-bottle isityael/tap/fast-cli
brew bottle --json \
  --root-url "https://github.com/isityael/tap/releases/download/fast-cli-${VERSION}" \
  isityael/tap/fast-cli

# Merge bottle block into formula
echo "==> Merging bottle block"
brew bottle --merge --write --no-commit "${OUTPUT_DIR}"/*.json
cp "${REPO_DIR}/Formula/fast-cli.rb" "${OUTPUT_DIR}/fast-cli.rb"

echo "==> Done — fast-cli ${VERSION} bottle artifacts are in ${OUTPUT_DIR}"
