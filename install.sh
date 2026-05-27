#!/usr/bin/env bash
# install.sh — drop bin/promodoro into PROMODORO_PREFIX/bin.
# Use this on systems without Nix; on NixOS, install the flake's package instead.

set -euo pipefail

prefix="${PROMODORO_PREFIX:-$HOME/.local}"
src_dir="$(cd "$(dirname "$0")" && pwd)"

install -d "$prefix/bin"
install -m755 "$src_dir/bin/promodoro" "$prefix/bin/promodoro"

echo "installed: $prefix/bin/promodoro"
case ":$PATH:" in
  *":$prefix/bin:"*) ;;
  *) echo "warning: $prefix/bin is not on PATH" >&2 ;;
esac
