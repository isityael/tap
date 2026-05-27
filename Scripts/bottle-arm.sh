#!/usr/bin/env bash
# bottle-arm.sh — build ARM64 bottle, create GitHub Release, merge bottle block
# Called by Woodpecker CI via SSH on the Mac builder.
# Usage: bottle-arm.sh <repo-dir>
set -euo pipefail

REPO_DIR="${1:?Usage: bottle-arm.sh <repo-dir>}"
cd "${REPO_DIR}"

# Extract version from formula
VERSION=$(ruby -e 'puts File.read("Formula/fast-cli.rb")[/fast-cli-([\d.]+)\.tgz/, 1]')
echo "==> Building bottle for fast-cli ${VERSION}"

# Point Homebrew tap at our checkout (backup existing)
TAP_DIR="$(brew --repository)/Library/Taps/yaelmoshi/homebrew-tap"
if [[ -e "${TAP_DIR}" ]] || [[ -L "${TAP_DIR}" ]]
then
  mv "${TAP_DIR}" "${TAP_DIR}.ci-backup"
fi
ln -sfn "${REPO_DIR}" "${TAP_DIR}"

BOTTLE_DIR=$(mktemp -d)

cleanup() {
  echo "==> Cleaning up"
  brew uninstall fast-cli 2>/dev/null || true
  rm -f "${TAP_DIR}"
  if [[ -e "${TAP_DIR}.ci-backup" ]]
  then
    mv "${TAP_DIR}.ci-backup" "${TAP_DIR}"
  fi
  rm -rf "${BOTTLE_DIR}"
}
trap cleanup EXIT

# Build bottle (ARM64 only)
cd "${BOTTLE_DIR}"
brew uninstall fast-cli 2>/dev/null || true
HOMEBREW_NO_AUTO_UPDATE=1 brew install --build-bottle yaelmoshi/tap/fast-cli
brew bottle --json \
  --root-url "https://github.com/yaelmoshi/tap/releases/download/fast-cli-${VERSION}" \
  yaelmoshi/tap/fast-cli

# Create or update GitHub Release
echo "==> Uploading to GitHub Release fast-cli-${VERSION}"
if ! gh release view "fast-cli-${VERSION}" --repo yaelmoshi/tap &>/dev/null
then
  gh release create "fast-cli-${VERSION}" \
    --repo yaelmoshi/tap \
    --title "fast-cli ${VERSION}" \
    --notes "ARM64 macOS bottle for fast-cli ${VERSION}" \
    "${BOTTLE_DIR}"/*.bottle.tar.gz
else
  gh release upload "fast-cli-${VERSION}" \
    --repo yaelmoshi/tap \
    "${BOTTLE_DIR}"/*.bottle.tar.gz --clobber
fi

# Merge bottle block into formula
echo "==> Merging bottle block"
brew bottle --merge --write --no-commit "${BOTTLE_DIR}"/*.json

# Commit and push
cd "${REPO_DIR}"
git config user.name "Woodpecker CI"
git config user.email "ci@m0sh1.cc"
git add Formula/fast-cli.rb
if git diff --cached --quiet
then
  echo "No bottle changes to commit"
  exit 0
fi
git commit -m "fast-cli: add bottle block for ${VERSION} [CI SKIP]"
git push origin main

echo "==> Done — fast-cli ${VERSION} bottled and released"
