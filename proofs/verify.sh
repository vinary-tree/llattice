#!/usr/bin/env bash
# llattice formal-verification driver: builds the Rocq lattice-law proofs under
# a mandatory resource cap and runs the proof-escape and traceability gates.
# llattice has no ABI (its values never cross the vt resource boundary), so
# there are no TLC models -- only the algebra proofs.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
evidence="$root/target/verification"
temporary="$evidence/tmp"

mkdir -p "$temporary"

if [[ "${LLATTICE_FORMAL_SCOPED:-0}" != "1" ]]; then
  exec systemd-run --user --scope \
    -p MemoryMax=4G \
    -p MemorySwapMax=0 \
    -p CPUQuota=400% \
    -p TasksMax=64 \
    --setenv=LLATTICE_FORMAL_SCOPED=1 \
    --setenv=MAKEFLAGS=-j1 \
    --setenv=PYTHONDONTWRITEBYTECODE=1 \
    --setenv=TMPDIR="$temporary" \
    -- "$root/proofs/verify.sh"
fi

export MAKEFLAGS="${MAKEFLAGS:--j1}"
export PYTHONDONTWRITEBYTECODE=1
export TMPDIR="$temporary"

make -C "$root/proofs/coq" proof-check 2>&1 | tee "$evidence/proof-check.log"
make -C "$root/proofs/coq" clean 2>&1 | tee "$evidence/proof-clean.log"
make -C "$root/proofs/coq" -j1 2>&1 | tee "$evidence/rocq.log"

closed_count="$(rg -c '^Closed under the global context$' "$evidence/rocq.log")"
if [[ "$closed_count" != "7" ]]; then
  echo "expected 7 axiom-free Rocq assumption reports; found $closed_count" >&2
  exit 1
fi

# Lattice invariant registry: hook<->registry closure and spec/test resolution.
python3 "$root/scripts/check-lattice-invariants.py" 2>&1 \
  | tee "$evidence/lattice-invariants.log"
