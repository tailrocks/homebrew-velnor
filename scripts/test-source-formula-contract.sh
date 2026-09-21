#!/usr/bin/env bash
set -euo pipefail

root=$(cd -P -- "$(dirname -- "$0")/.." && pwd -P)
formula="$root/Formula/velnorctl.rb"
readme="$root/README.md"

die() {
  printf 'source formula contract: %s\n' "$*" >&2
  exit 1
}

[[ -f "$formula" && ! -L "$formula" ]] || die "Formula/velnorctl.rb missing"
ruby -c "$formula" >/dev/null

url=$(ruby -e 'print STDIN.read[/\burl "([^"]+)"/, 1]' < "$formula") || true
sha=$(ruby -e 'print STDIN.read[/\bsha256 "([^"]+)"/, 1]' < "$formula") || true
[[ -n "$url" ]] || die "formula has no url"
[[ -n "$sha" ]] || die "formula has no sha256"
[[ "$url" == https://github.com/tailrocks/velnor/archive/refs/tags/v*.tar.gz ]] || die "formula url is not an immutable Velnor tag archive: $url"
[[ "$sha" =~ ^[0-9a-f]{64}$ ]] || die "formula sha256 is not 64 lowercase hex: $sha"

grep -Fq 'depends_on "rust" => :build' "$formula" || die "formula must build with rust"
grep -Fq 'std_cargo_args(path: "crates/velnorctl")' "$formula" || die "formula must cargo-install crates/velnorctl"
grep -Fq 'std_cargo_args(path: "crates/velnor-runner")' "$formula" || die "formula must cargo-install crates/velnor-runner"
grep -Fq 'system "cargo", "install"' "$formula" || die "formula must cargo install from source"
grep -Fq 'service do' "$formula" || die "formula must define a service block"
grep -Fq 'opt_bin/"velnor-runner"' "$formula" || die "service block must run velnor-runner"

if grep -E -n -- 'bin\.install|velnor-workflow|depends_on arch:' "$formula"; then
  die "formula must not install velnor-workflow or pin a bottle arch"
fi

if grep -E -n -- 'never builds from source|product-manifest|velnorctl-preview' "$formula"; then
  die "formula must not switch to the unpublished binary product-manifest contract"
fi

grep -Fq 'immutable Velnor release' "$readme" || die "README must describe the source-archive formula"
if grep -E -n -- 'never builds from source' "$readme"; then
  die "README must not claim the unpublished never-from-source product"
fi

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
archive="$tmp/source.tar.gz"
curl -fsSL --retry 3 -o "$archive" -- "$url" || die "failed to download formula url: $url"
if command -v sha256sum >/dev/null 2>&1; then
  actual=$(sha256sum -- "$archive" | awk '{print $1}')
else
  actual=$(shasum -a 256 -- "$archive" | awk '{print $1}')
fi
[[ "$actual" == "$sha" ]] || die "downloaded archive sha256 $actual != formula $sha"

printf 'source formula contract passed (%s sha256 match)\n' "$url"
