# Archived documentation assets

This directory holds documentation sources that have been **retired** and are intentionally excluded from
the live docs and the render pipeline (`docs/diagrams/Makefile` prunes `*/archive/*`). Nothing here is
referenced by the current documentation. Files are kept — not deleted — so the history and rationale remain
recoverable.

## Why these were retired (2026-07-12)

The pgmcp documentation guideline **`diagrams-prefer-plantuml`** — *"Prefer PlantUML over Mermaid for any
diagram type both support; reach for Mermaid only where PlantUML has no equivalent. PlantUML output is
byte-reproducible and renders LaTeX; Mermaid's is neither."* — supersedes the two Mermaid figures this crate
shipped. PlantUML covers both diagram types in question (class and sequence), emits portable native-vector
SVG (no `<foreignObject>` rasterisation problem, so no PNG workaround is needed), and typesets `<latex>`
labels through bundled JLaTeXMath. The figures were therefore re-authored in PlantUML and re-rendered to SVG.

## Contents and replacements

| Archived file | What it was | Replaced by |
|---------------|-------------|-------------|
| `design/figures/lattice-class.mmd` | Mermaid class diagram of the `Lattice` trait + implementors | `docs/design/figures/lattice-class.puml` → `lattice-class.svg` |
| `design/figures/lattice-class.png` | PNG rendered from the Mermaid source | `docs/design/figures/lattice-class.svg` (PlantUML) |
| `guides/figures/crdt-convergence.mmd` | Mermaid sequence diagram of G-Set convergence | `docs/guides/figures/crdt-convergence.puml` → `crdt-convergence.svg` |
| `guides/figures/crdt-convergence.png` | PNG rendered from the Mermaid source | `docs/guides/figures/crdt-convergence.svg` (PlantUML) |
| `diagrams/mermaid.json` | Mermaid-CLI theme/config passed to `mmdc -c` | *(none — Mermaid is no longer invoked)* |
| `diagrams/powerset-hasse.puml` | A second, redundant PlantUML source for the powerset Hasse | `docs/diagrams/powerset-hasse.dot` (Graphviz remains canonical for ranked Hasse layouts) |

## Historical note — why Mermaid used PNG

For the record (this rationale previously lived in `docs/diagrams/Makefile`): Mermaid was rendered to PNG via
headless Chromium (`mmdc -s 2`) rather than SVG because Mermaid's SVG output uses `<foreignObject>` HTML
labels that GitHub and librsvg cannot rasterise (they appear blank), and its native-text SVG mode collapses
inter-word spaces. PlantUML has neither defect, so its figures are committed as scalable SVG like the
Graphviz, D2, and TikZ figures.

`docs/diagrams/powerset-hasse.dot` (Graphviz) was and remains the canonical source for the powerset Hasse:
Graphviz's ranked layout is purpose-built for order/Hasse diagrams. The `diagrams-prefer-plantuml` guideline
governs PlantUML **vs. Mermaid**, not PlantUML vs. Graphviz, so the best-tool-per-illustration choice stands.
