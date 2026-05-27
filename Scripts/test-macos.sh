#!/usr/bin/env bash
# test-macos.sh — audit and test formulae on macOS
# Called by Woodpecker CI via SSH on the Mac builder.
# Usage: test-macos.sh <repo-dir>
set -euo pipefail

REPO_DIR="${1:?Usage: test-macos.sh <repo-dir>}"
cd "${REPO_DIR}"

# Point Homebrew tap at our checkout (backup existing)
TAP_DIR="$(brew --repository)/Library/Taps/yaelmoshi/homebrew-tap"
if [[ -e "${TAP_DIR}" ]] || [[ -L "${TAP_DIR}" ]]
then
  mv "${TAP_DIR}" "${TAP_DIR}.ci-backup"
fi
ln -sfn "${REPO_DIR}" "${TAP_DIR}"

cleanup() {
  rm -f "${TAP_DIR}"
  if [[ -e "${TAP_DIR}.ci-backup" ]]
  then
    mv "${TAP_DIR}.ci-backup" "${TAP_DIR}"
  fi
}
trap cleanup EXIT

export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ANALYTICS=1

echo "==> Auditing tap"
brew audit --tap yaelmoshi/tap || true

echo "==> Installing and testing formulae"
FAILED=0
for formula in Formula/*.rb
do
  [[ -f "${formula}" ]] || continue
  name=$(basename "${formula}" .rb)
  echo "--- ${name} ---"
  if ! brew install "yaelmoshi/tap/${name}"
  then
    echo "FAIL: install ${name}"
    FAILED=1
    continue
  fi
  if ! brew test "yaelmoshi/tap/${name}"
  then
    echo "FAIL: test ${name}"
    FAILED=1
  fi
  brew uninstall "${name}" 2>/dev/null || true
done

if [[ "${FAILED}" -ne 0 ]]
then
  echo "==> Some tests failed"
  exit 1
fi

echo "==> All tests passed"
