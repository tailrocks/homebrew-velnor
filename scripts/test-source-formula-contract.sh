#!/usr/bin/env bash
set -euo pipefail

root=$(cd -P -- "$(dirname -- "$0")/.." && pwd -P)
formula="$root/Formula/velnorctl.rb"
readme="$root/README.md"

die() {
  printf 'Homebrew product contract: %s\n' "$*" >&2
  exit 1
}

constant() {
  local name=$1
  ruby -e 'name = ARGV.fetch(0); source = STDIN.read; match = source.match(/^#{Regexp.escape(name)} = "([^"]+)"/); print(match ? match[1] : "")' "$name" < "$formula"
}

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" | awk '{print $1}'
  else
    shasum -a 256 -- "$1" | awk '{print $1}'
  fi
}

[[ -f "$formula" && ! -L "$formula" ]] || die "Formula/velnorctl.rb missing"
ruby -c "$formula" >/dev/null

source_commit=$(constant SOURCE_COMMIT)
source_sha=$(constant SOURCE_ARCHIVE_SHA256)
packaging_commit=$(constant PACKAGING_COMMIT)
launch_sha=$(constant LAUNCH_SHA256)
plist_sha=$(constant PLIST_SHA256)
version=$(ruby -e 'print STDIN.read[/^  version "([^"]+)"/, 1].to_s' < "$formula")

[[ "$source_commit" =~ ^[0-9a-f]{40}$ ]] || die "source commit is not a full lowercase Git identity"
[[ "$source_sha" =~ ^[0-9a-f]{64}$ ]] || die "source archive SHA-256 is not lowercase hex"
[[ "$packaging_commit" =~ ^[0-9a-f]{40}$ ]] || die "packaging commit is not a full lowercase Git identity"
[[ "$launch_sha" =~ ^[0-9a-f]{64}$ ]] || die "launcher SHA-256 is not lowercase hex"
[[ "$plist_sha" =~ ^[0-9a-f]{64}$ ]] || die "plist SHA-256 is not lowercase hex"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "formula version is not a release version: $version"

grep -Fq 'SOURCE_URL = "https://github.com/tailrocks/velnor/archive/#{SOURCE_COMMIT}.tar.gz"' "$formula" || die "source URL must be derived from SOURCE_COMMIT"
grep -Fq 'url SOURCE_URL' "$formula" || die "formula must use the pinned source URL"
grep -Fq 'sha256 SOURCE_ARCHIVE_SHA256' "$formula" || die "formula must use the pinned source digest"
grep -Fq 'url "https://raw.githubusercontent.com/tailrocks/velnor/#{PACKAGING_COMMIT}/packaging/macos/velnor-runner-launch"' "$formula" || die "launcher URL must be derived from PACKAGING_COMMIT"
grep -Fq 'url "https://raw.githubusercontent.com/tailrocks/velnor/#{PACKAGING_COMMIT}/packaging/macos/com.tailrocks.velnor.runner.plist"' "$formula" || die "plist URL must be derived from PACKAGING_COMMIT"

for dependency in rust docker gh git; do
  grep -Fq "depends_on \"$dependency\"" "$formula" || die "formula missing dependency: $dependency"
done
for binary in velnorctl velnor-runner velnor-workflow; do
  grep -E -q "\"$binary\"[[:space:]]+=>[[:space:]]+\"crates/$binary\"" "$formula" || die "formula does not install $binary"
done
grep -Fq 'std_cargo_args(path: path)' "$formula" || die "formula does not build the declared binaries from the pinned source"
grep -Fq 'resource "velnor-runner-launch"' "$formula" || die "formula missing pinned launcher resource"
grep -Fq 'resource "velnor-launchd-plist"' "$formula" || die "formula missing pinned launchd resource"
grep -Fq 'service do' "$formula" || die "formula missing Homebrew service"
grep -Fq 'name macos: "com.tailrocks.velnor.runner"' "$formula" || die "formula service label is not canonical"
grep -Fq 'run [opt_prefix / "libexec" / "velnor-runner-launch"]' "$formula" || die "service must use the verified launcher"
grep -Fq 'velnor.homebrew-install/v3' "$formula" || die "formula missing install manifest schema"
grep -Fq 'velnor.homebrew-install-identity/v2' "$formula" || die "formula missing install identity schema"
grep -Fq 'source_archive_sha256' "$formula" || die "manifest must bind the source archive digest"
grep -Fq 'packaging_commit' "$formula" || die "manifest must bind packaging identity"
grep -Fq 'binary_sha256' "$formula" || die "identity must bind installed binary digests"

if grep -E -n -- 'refs/heads|/releases/latest|disable!|bin\.install|velnorctl-preview|product-manifest|never builds from source' "$formula"; then
  die "formula contains a floating, disabled, or obsolete product contract"
fi

grep -Fq 'immutable Velnor source archive' "$readme" || die "README must describe the immutable source archive"
grep -Fq 'velnor-workflow' "$readme" || die "README must describe the complete toolset"
grep -Fq 'GitHub-only writer' "$readme" || die "README must describe feed mutation ownership"

tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
archive="$tmp/source.tar.gz"
curl -fsSL --retry 3 -o "$archive" -- "https://github.com/tailrocks/velnor/archive/$source_commit.tar.gz" || die "failed to download source archive"
actual_source_sha=$(sha256_file "$archive")
[[ "$actual_source_sha" == "$source_sha" ]] || die "source archive SHA-256 mismatch"

archive_root="velnor-$source_commit"
runner_version=$(tar -xOf "$archive" "$archive_root/crates/velnor-runner/Cargo.toml" | ruby -e 'print STDIN.read[/^version = "([^"]+)"/, 1].to_s')
[[ "$runner_version" == "$version" ]] || die "formula version $version disagrees with runner source version $runner_version"
for member in crates/velnorctl/Cargo.toml crates/velnor-runner/Cargo.toml crates/velnor-workflow/Cargo.toml; do
  tar -tzf "$archive" | grep -Fx "$archive_root/$member" >/dev/null || die "source archive missing $member"
done

launch_url="https://raw.githubusercontent.com/tailrocks/velnor/$packaging_commit/packaging/macos/velnor-runner-launch"
plist_url="https://raw.githubusercontent.com/tailrocks/velnor/$packaging_commit/packaging/macos/com.tailrocks.velnor.runner.plist"
curl -fsSL --retry 3 -o "$tmp/velnor-runner-launch" -- "$launch_url" || die "failed to download launcher resource"
curl -fsSL --retry 3 -o "$tmp/com.tailrocks.velnor.runner.plist" -- "$plist_url" || die "failed to download plist resource"
[[ "$(sha256_file "$tmp/velnor-runner-launch")" == "$launch_sha" ]] || die "launcher resource SHA-256 mismatch"
[[ "$(sha256_file "$tmp/com.tailrocks.velnor.runner.plist")" == "$plist_sha" ]] || die "plist resource SHA-256 mismatch"

printf 'Homebrew product contract passed: version=%s source=%s packaging=%s\n' "$version" "$source_commit" "$packaging_commit"
