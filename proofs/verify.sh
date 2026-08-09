#!/usr/bin/env bash
# llattice formal-verification driver: builds the Rocq lattice-law proofs under
# resource caps (when a user systemd scope is available) and runs the
# proof-escape gate. llattice has no ABI (its values never cross the vt resource
# boundary), so there are no TLC models -- only the algebra proofs.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

capped_make() {
  if command -v systemd-run >/dev/null 2>&1 \
     && systemd-run --user --scope -q true >/dev/null 2>&1; then
    systemd-run --user --scope -q \
      -p MemoryMax=8G -p CPUQuota=1800% -p TasksMax=200 \
      make "$@"
  else
    make "$@"
  fi
}

capped_make -C "$ROOT/proofs/coq" proof-check
capped_make -C "$ROOT/proofs/coq" -j1

# Lattice invariant registry: hook<->registry closure and spec/test resolution.
python3 "$ROOT/scripts/check-lattice-invariants.py"
