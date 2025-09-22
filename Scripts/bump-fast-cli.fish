#!/usr/bin/env fish
set -e

set FORMULA Formula/fast-cli.rb
set VERSION (npm view fast-cli version)
set URL (npm view fast-cli dist.tarball)

set tmp (mktemp)
curl -L $URL -o $tmp
set SHA256 (shasum -a 256 $tmp | awk '{print $1}')
rm -f $tmp

# Update tarball URL (version number segment)
sd '/fast-cli-[0-9][^/]*\.tgz' "/fast-cli-$VERSION.tgz" $FORMULA

# Update sha256 line
sd '^\s*sha256 ".*"' "  sha256 \"$SHA256\"" $FORMULA

git add $FORMULA
git commit -m "fast-cli $VERSION"
git push

printf "Bumped fast-cli to %s with sha256 %s\n" $VERSION $SHA256
