#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
evidence="$root/target/verification"
temporary="$evidence/tmp"
cargo_target="$root/target/cargo"
msrv_target="$root/target/cargo-msrv"

mkdir -p "$temporary" "$cargo_target" "$msrv_target"

if [[ "${LLATTICE_RELEASE_SCOPED:-0}" != "1" ]]; then
  exec systemd-run --user --scope \
    -p MemoryMax=4G \
    -p MemorySwapMax=0 \
    -p CPUQuota=100% \
    -p TasksMax=64 \
    --setenv=LLATTICE_RELEASE_SCOPED=1 \
    --setenv=LLATTICE_FORMAL_SCOPED=1 \
    --setenv=LLATTICE_DOCS_SCOPED=1 \
    --setenv=CARGO_BUILD_JOBS=1 \
    --setenv=CARGO_INCREMENTAL=0 \
    --setenv=CARGO_TARGET_DIR="$cargo_target" \
    --setenv=MAKEFLAGS=-j1 \
    --setenv=PYTHONDONTWRITEBYTECODE=1 \
    --setenv=RUFF_CACHE_DIR="$root/target/ruff-cache" \
    --setenv=TMPDIR="$temporary" \
    --setenv=JAVA_TOOL_OPTIONS="-Xmx1024m -Djava.awt.headless=true -Djava.io.tmpdir=$temporary" \
    -- "$root/scripts/verify-release.sh"
fi

export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
export CARGO_INCREMENTAL="${CARGO_INCREMENTAL:-0}"
export CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$cargo_target}"
export MAKEFLAGS="${MAKEFLAGS:--j1}"
export PYTHONDONTWRITEBYTECODE=1
export RUFF_CACHE_DIR="${RUFF_CACHE_DIR:-$root/target/ruff-cache}"
export TMPDIR="$temporary"

run_logged() {
  local name="$1"
  shift
  "$@" 2>&1 | tee "$evidence/$name.log"
}

cd "$root"
run_logged shell-syntax bash -n \
  proofs/verify.sh scripts/verify-docs.sh scripts/verify-release.sh
run_logged shellcheck shellcheck \
  proofs/verify.sh scripts/verify-docs.sh scripts/verify-release.sh
run_logged yamllint yamllint \
  .github/workflows/ci.yml .github/workflows/release.yml
run_logged ruff-check ruff check \
  scripts/check-lattice-invariants.py scripts/check-release-ref.py
run_logged ruff-format ruff format --check \
  scripts/check-lattice-invariants.py scripts/check-release-ref.py
run_logged cargo-fmt cargo fmt --all -- --check
run_logged cargo-check cargo check --locked --all-targets
run_logged cargo-check-no-std cargo check --locked --lib --no-default-features

msrv_cargo="$(rustup which --toolchain 1.70.0 cargo)"
msrv_command=("$msrv_cargo")
cargo_config="${CARGO_HOME:-$HOME/.cargo}/config.toml"
if [[ -f "$cargo_config" ]]; then
  command -v bwrap >/dev/null 2>&1 || {
    echo "bwrap is required to isolate the ambient Cargo config" >&2
    exit 1
  }
  empty_config="$evidence/empty-cargo-config"
  install -m 0444 /dev/null "$empty_config"
  msrv_command=(
    bwrap
    --bind / /
    --dev-bind /dev /dev
    --proc /proc
    --ro-bind "$empty_config" "$cargo_config"
    --chdir "$root"
    "$msrv_cargo"
  )
fi
run_logged cargo-msrv-no-std env CARGO_TARGET_DIR="$msrv_target" \
  "${msrv_command[@]}" check --locked --lib --no-default-features
run_logged cargo-msrv-std env CARGO_TARGET_DIR="$msrv_target" \
  "${msrv_command[@]}" check --locked --lib
run_logged cargo-clippy cargo clippy --locked --all-targets -- -D warnings
run_logged cargo-test cargo test --locked --all-targets
run_logged cargo-doctest cargo test --locked --doc
RUSTDOCFLAGS="-D warnings" run_logged cargo-doc cargo doc --locked --no-deps --all-features
run_logged lattice-invariants python3 scripts/check-lattice-invariants.py
run_logged release-ref python3 scripts/check-release-ref.py --self-test
run_logged binding-matrix raku scripts/check-bindings.raku
run_logged formal proofs/verify.sh
run_logged docs scripts/verify-docs.sh
run_logged package-list cargo package --locked --allow-dirty --list
run_logged package cargo package --locked --allow-dirty
