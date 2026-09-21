# homebrew-velnor

Homebrew tap for the native `velnorctl` operator CLI.

Install the CLI on macOS with:

```sh
brew tap tailrocks/velnor
brew install velnorctl
```

This formula builds `velnorctl` and `velnor-runner` from the matching
immutable Velnor release source archive, and provides a Homebrew service
for launchd supervision of the runner daemon.

The formula version follows the Velnor release tag. The current source still
reports the independently versioned control-plane package version (`0.1.0`)
from `velnorctl version`; keep that distinction visible until the upstream
release contract unifies component versions.
