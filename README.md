# homebrew-velnor

Homebrew tap for the native Velnor control-plane toolset.

Install the CLI on macOS with:

```sh
brew tap tailrocks/velnor
brew install velnorctl
```

The `velnorctl` formula builds `velnorctl`, `velnor-runner`, and
`velnor-workflow` from one immutable Velnor source archive. It also installs
the pinned launchd launcher and service plist, package-owned configuration,
state, work, and log paths, plus a manifest and identity record containing the
source, package, service, and installed-binary SHA-256 identities.

Start the installed service only after configuring the required host mode and
credentials in the package-owned environment file:

```sh
brew services start velnorctl
```

The generated Homebrew feed contract verifies the formula on GitHub-hosted
CI. Feed mutation is an explicit GitHub-only writer; local Velnor execution
cannot publish the tap.

The formula version follows the Velnor runner product version. `velnorctl` and
`velnor-workflow` retain their independently reported crate versions in the
installed identity until the upstream release contract unifies component
versions.
