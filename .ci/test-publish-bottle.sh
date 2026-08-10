#!/usr/bin/env bash
# Contract and error-path tests for dual bottle publication.

set -u

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
publisher="$repo_root/Scripts/publish-bottle.sh"
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

assert_file_contains() {
  local text=$1
  local message=$2

  if [[ -f "$publisher" ]] && grep -Fq -- "$text" "$publisher"; then
    pass "$message"
  else
    fail "$message"
  fi
}

test_missing_environment_fails_closed() {
  # Arrange
  local output
  local status

  # Act
  output=$(env -i PATH="$PATH" bash "$publisher" 2>&1)
  status=$?

  # Assert
  if [[ $status -ne 0 && "$output" == *"required environment variable"* ]]; then
    pass "Missing publication environment fails closed"
  else
    fail "Missing publication environment should fail closed (status=$status output=$output)"
  fi
}

test_no_legacy_repository_url() {
  # Arrange / Act / Assert
  if grep -R -Fq 'github.com/yaelmoshi/tap' \
    "$repo_root/.woodpecker/bottle.yaml" \
    "$repo_root/Scripts/bottle-arm.sh" \
    "$publisher" 2>/dev/null; then
    fail "Bottle publication avoids the legacy GitHub repository URL"
  else
    pass "Bottle publication avoids the legacy GitHub repository URL"
  fi
}

test_publication_contract() {
  # Arrange / Act / Assert
  assert_file_contains 'fj release create' "Forgejo release is created with fj"
  assert_file_contains 'gh release create' "GitHub release is created with gh"
  assert_file_contains 'git ls-remote' "Publisher verifies mirrored tags"
  assert_file_contains 'mirror deadline exceeded' "Publisher has a bounded mirror wait"
  assert_file_contains 'verify_release_asset' "Publisher verifies release assets"

  if [[ -f "$publisher" ]] && grep -Fq -- '--clobber' "$publisher"; then
    fail "Publisher never overwrites an existing release asset"
  else
    pass "Publisher never overwrites an existing release asset"
  fi
}

started=$SECONDS
test_missing_environment_fails_closed
test_no_legacy_repository_url
test_publication_contract
duration=$((SECONDS - started))

if [[ $duration -lt 5 ]]; then
  pass "Publication contract tests finish within five seconds"
else
  fail "Publication contract tests exceeded five seconds (${duration}s)"
fi

printf '\nTests passed: %s\n' "$tests_passed"
printf 'Tests failed: %s\n' "$tests_failed"

if [[ $tests_failed -eq 0 ]]; then
  exit 0
fi

exit 1
