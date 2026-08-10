# isityael/tap

The canonical source, issues, pull requests, and releases are hosted on
[Forgejo](https://git.m0sh1.cc/isityael/tap). The
[GitHub repository](https://github.com/isityael/tap) is a public Git mirror and
Homebrew release-asset endpoint.

## How do I install these formulae?

Add the tap with its explicit GitHub mirror URL:

```sh
brew tap isityael/tap https://github.com/isityael/tap.git
```

Then install a formula:

```sh
brew install isityael/tap/<formula>
```

Existing `yaelmoshi/tap` installations remain supported and continue to update
from the same GitHub mirror.

In a `brew bundle` `Brewfile`:

```ruby
tap "isityael/tap", "https://github.com/isityael/tap.git"
brew "<formula>"
```

## Documentation

`brew help`, `man brew` or check [Homebrew's documentation](https://docs.brew.sh).
