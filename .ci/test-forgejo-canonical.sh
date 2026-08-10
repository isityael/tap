#!/bin/sh
# Contract tests for Forgejo-canonical repository ownership.

set -u

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

tests_passed=0
tests_failed=0

pass() {
  tests_passed=$((tests_passed + 1))
  printf 'PASS: %s\n' "$1"
}

fail() {
  tests_failed=$((tests_failed + 1))
  printf 'FAIL: %s\n' "$1" >&2
}

assert_contains() {
  file=$1
  text=$2
  message=$3

  if grep -Fq "$text" "$file"; then
    pass "$message"
  else
    fail "$message ($file lacks: $text)"
  fi
}

assert_not_contains() {
  file=$1
  text=$2
  message=$3

  if grep -Fq "$text" "$file"; then
    fail "$message ($file contains: $text)"
  else
    pass "$message"
  fi
}

assert_contains .woodpecker/lint.yaml \
  'sh .ci/test-woodpecker-lint.sh' \
  'Woodpecker executes its lint-scope contract'
assert_contains .woodpecker/lint.yaml \
  'sh .ci/test-forgejo-canonical.sh' \
  'Woodpecker executes the canonical ownership contract'
assert_contains .woodpecker/checksums.yaml \
  'https://git.m0sh1.cc/isityael/tap.git' \
  'Checksum updates push to Forgejo'
assert_contains .woodpecker/test.yaml \
  'https://git.m0sh1.cc/isityael/tap.git' \
  'macOS tests clone Forgejo'
assert_not_contains .woodpecker/checksums.yaml \
  'github.com/yaelmoshi/tap' \
  'Checksum updates avoid the legacy GitHub URL'
assert_not_contains .woodpecker/test.yaml \
  'github.com/yaelmoshi/tap' \
  'macOS tests avoid the legacy GitHub URL'
assert_not_contains .woodpecker/checksums.yaml \
  'FORGEJO_TOKEN@' \
  'Checksum pushes do not persist credentials in the remote URL'
assert_not_contains .woodpecker/test.yaml \
  'FORGEJO_TOKEN}@' \
  'macOS clones do not embed credentials in the clone URL'
assert_not_contains README.md \
  'github.com/yaelmoshi/tap' \
  'Documentation avoids the legacy GitHub URL'
assert_contains renovate.json \
  '"description": "Keep Headlamp updates enabled"' \
  'Headlamp Renovate policy description matches its behavior'
assert_contains renovate.json \
  '"enabled": true' \
  'Headlamp Renovate updates remain enabled'
assert_contains README.md \
  'brew tap isityael/tap https://github.com/isityael/tap.git' \
  'Documentation provides the explicit supported tap command'

printf '\nTests passed: %s\n' "$tests_passed"
printf 'Tests failed: %s\n' "$tests_failed"

if [ "$tests_failed" -eq 0 ]; then
  exit 0
fi

exit 1
