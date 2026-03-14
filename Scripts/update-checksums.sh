#!/usr/bin/env bash
# update-checksums.sh — recalculate sha256 for changed Homebrew cask/formula files
# Called by the renovate-checksums workflow after Renovate bumps a version.
set -euo pipefail

hash_file() {
  if command -v sha256sum &>/dev/null; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

for file in "$@"; do
  [[ -f "$file" ]] || continue
  name=$(basename "$file" .rb)

  case "$name" in
    betterdiscord)
      version=$(ruby -e "puts File.read('$file')[/version\s+\"([^\"]+)\"/, 1]")
      url="https://github.com/BetterDiscord/Installer/releases/download/v${version}/BetterDiscord-Mac.zip"
      ;;
    exifcleaner)
      version=$(ruby -e "puts File.read('$file')[/version\s+\"([^\"]+)\"/, 1]")
      url="https://github.com/szTheory/exifcleaner/releases/download/v${version}/ExifCleaner-${version}.dmg"
      ;;
    headlamp)
      echo "Skipping $name (multi-arch sha256, disabled in Renovate)" >&2
      continue
      ;;
    zenmap)
      version=$(ruby -e "puts File.read('$file')[/version\s+\"([^\"]+)\"/, 1]")
      url="https://nmap.org/dist/nmap-${version}.dmg"
      ;;
    fast-cli)
      version=$(ruby -e "puts File.read('$file')[/fast-cli-([\\d.]+)\\.tgz/, 1]")
      url="https://registry.npmjs.org/fast-cli/-/fast-cli-${version}.tgz"
      ;;
    *)
      echo "Skipping unknown package: $name" >&2
      continue
      ;;
  esac

  tmp=$(mktemp)

  echo "Fetching $name $version ..."
  if ! curl -fsSL -o "$tmp" "$url"; then
    echo "ERROR: download failed for $name ($url)" >&2
    rm -f "$tmp"
    continue
  fi

  sha=$(hash_file "$tmp")
  rm -f "$tmp"

  # Replace the first 64-char hex sha256 value in the file
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/sha256 \"[0-9a-f]\{64\}\"/sha256 \"${sha}\"/" "$file"
  else
    sed -i "s/sha256 \"[0-9a-f]\{64\}\"/sha256 \"${sha}\"/" "$file"
  fi

  echo "  Updated $name $version -> $sha"
done
