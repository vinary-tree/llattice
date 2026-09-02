#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
evidence="$root/target/verification"
temporary="$evidence/tmp"

mkdir -p "$temporary"

if [[ "${LLATTICE_DOCS_SCOPED:-0}" != "1" ]]; then
  exec systemd-run --user --scope \
    -p MemoryMax=4G \
    -p MemorySwapMax=0 \
    -p CPUQuota=100% \
    -p TasksMax=64 \
    --setenv=LLATTICE_DOCS_SCOPED=1 \
    --setenv=TMPDIR="$temporary" \
    --setenv=JAVA_TOOL_OPTIONS="-Xmx1024m -Djava.awt.headless=true -Djava.io.tmpdir=$temporary" \
    -- "$root/scripts/verify-docs.sh"
fi

export TMPDIR="$temporary"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Xmx1024m -Djava.awt.headless=true -Djava.io.tmpdir=$temporary}"

first_manifest="$evidence/diagrams-first.sha256"
second_manifest="$evidence/diagrams-second.sha256"

make -B -C "$root/docs/diagrams" -j1 2>&1 | tee "$evidence/diagrams-first.log"
find "$root/docs" -type f -name '*.svg' -not -path '*/archive/*' -print0 \
  | LC_ALL=C sort -z \
  | xargs -0 sha256sum >"$first_manifest"

make -B -C "$root/docs/diagrams" -j1 2>&1 | tee "$evidence/diagrams-second.log"
find "$root/docs" -type f -name '*.svg' -not -path '*/archive/*' -print0 \
  | LC_ALL=C sort -z \
  | xargs -0 sha256sum >"$second_manifest"
cmp "$first_manifest" "$second_manifest"

# vinary-doc-lint 0.1.1's Graphviz replay uses `dot -Tsvg`, then rejects the
# standard SVG 1.1 DOCTYPE emitted by that exact command. The contradiction is
# tracked as `vdl-graphviz-render-validator-contract-contradiction` in pgmcp.
# The two-pass byte comparison above independently proves deterministic native
# rendering; the linter remains authoritative for document structure and links.
vinary-doc-lint check "$root" --format json 2>&1 \
  | tee "$evidence/vinary-doc-lint.json"
jq -e '
  all(.files[];
    ((.diagnostics // []) | length) == 0 and
    ((.changes // []) | length) == 0
  )
' "$evidence/vinary-doc-lint.json" >/dev/null
