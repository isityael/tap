#!/bin/sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
pipeline="${repo_root}/.woodpecker/lint.yaml"

if grep -Fq 'brew style yaelmoshi/tap' "${pipeline}"; then
  echo "tap lint must not style the entire tap, which makes Homebrew install incompatible workflow tooling" >&2
  exit 1
fi

grep -Fq 'brew style "$TAP_PATH/Formula" "$TAP_PATH/Casks"' "${pipeline}" || {
  echo "tap lint must scope brew style to formula and cask files" >&2
  exit 1
}

echo "woodpecker lint contract passed"
