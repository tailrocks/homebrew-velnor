#!/usr/bin/env bash
set -euo pipefail

root=$(cd -P -- "$(dirname -- "$0")/.." && pwd -P)
formula="$root/Formula/velnorctl.rb"

die() {
  printf 'homebrew audit: %s\n' "$*" >&2
  exit 1
}

command -v brew >/dev/null 2>&1 || die "brew is required"
[[ -f "$formula" && ! -L "$formula" ]] || die "stable formula must be a regular non-symlink file: $formula"
ruby -c "$formula" >/dev/null

brew_repository=$(brew --repository) || die "brew --repository failed"
[[ -n "$brew_repository" && -d "$brew_repository/Library/Taps" ]] || die "Homebrew taps directory missing"
tap_user=velnor-ci
tap_parent="$brew_repository/Library/Taps/$tap_user"
mkdir -p "$tap_parent"
[[ -d "$tap_parent" && ! -L "$tap_parent" ]] || die "tap parent is not a regular directory: $tap_parent"
tap_path=$(mktemp -d "$tap_parent/homebrew-velnor-checked-out.XXXXXX") || die "cannot create unique disposable tap"
[[ -d "$tap_path" && ! -L "$tap_path" ]] || die "disposable tap is not a regular directory"
tap_name=$(basename "$tap_path")
formula_ref="$tap_user/${tap_name#homebrew-}/velnorctl"

cleanup() {
  local status=$?
  if [[ -n "${tap_path:-}" && "$tap_path" == "$tap_parent"/homebrew-velnor-checked-out.* && -d "$tap_path" && ! -L "$tap_path" ]]; then
    rm -rf -- "$tap_path"
  fi
  rmdir "$tap_parent" 2>/dev/null || true
  exit "$status"
}
trap cleanup EXIT

mkdir -p "$tap_path/Formula"
cp -- "$formula" "$tap_path/Formula/velnorctl.rb"

printf 'homebrew audit: auditing checked-out %s via %s\n' "$formula" "$formula_ref"
HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_ENV_HINTS=1 \
  brew audit --formula --strict --online --display-filename "$formula_ref"
printf 'homebrew audit: audited checked-out %s\n' "$formula"
