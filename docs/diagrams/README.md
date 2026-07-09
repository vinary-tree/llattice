# Diagrams — catalog, render pipeline, and palette

Every figure in this documentation is **diagrams-as-code**: a committed text source rendered to a committed
image. This page is the catalog (which tool draws what and why), the reproducible render pipeline, and the
shared colour palette that gives the figures cross-document visual continuity.

All tools are drawn from the **pgmcp `diagramming` toolbox catalog** — the principle is *best tool per
illustration*, not one tool for everything.

---

## 1. Tool → engine map

| Source | Catalog tool (domain) | Renders to | Why this tool |
|--------|-----------------------|-----------|---------------|
| `*.dot` | **Graphviz** `dot` (`graph_layout`) | `.svg` | Ranked layouts are purpose-built for Hasse/order diagrams and reliable branching flowcharts; native-text SVG renders everywhere. |
| `*.d2` | **D2** (`uml_architecture`, `elk` layout) | `.svg` | Containers + labelled edges + styling for taxonomy, dependency, and concept-mapping diagrams. |
| `*.mmd` | **Mermaid** `mmdc` (`uml_architecture`) | `.png` | Idiomatic class-realization and sequence diagrams. Rendered to PNG via headless Chromium for full HTML-label fidelity (see §4). |
| `*.tex` | **TikZ/PGF** (`diagram_language`) → `dvisvgm` | `.svg` | Publication-grade mathematical typography for the `M₃`/`N₅` figures. |
| `*.puml` | **PlantUML** (`uml_architecture`) | `.svg` | Legacy/alternative source for the powerset Hasse (the canonical source is now `powerset-hasse.dot`). |

Rasterisation / conversion when needed uses **rsvg-convert** (librsvg) or **ImageMagick** (`magick`), both in
the catalog's `diagram_conversion` family.

---

## 2. The figure catalog

Each illustration, its source, its tool, and its diagram type. (`†` = rendered to PNG; all others to SVG.)

| # | Figure | Source | Tool | Type |
|---|--------|--------|------|------|
| 1 | Powerset Hasse of `{1,2,3}` | `powerset-hasse.dot` | Graphviz | ranked Hasse |
| 2 | `bool` two-element lattice | `../theory/figures/bool-lattice.dot` | Graphviz | Hasse |
| 3 | `Option<T>` lift | `../theory/figures/option-lift.dot` | Graphviz | Hasse + cluster |
| 4 | lub/glb geometry | `../theory/figures/lub-glb-geometry.dot` | Graphviz | Hasse (highlighted) |
| 5 | Lattice taxonomy | `../theory/figures/lattice-taxonomy.d2` | D2 | spec hierarchy |
| 6 | `𝒫(U) ≅ 2^U` isomorphism | `../theory/figures/powerset-iso.d2` | D2 | mapping |
| 7 | Semiring↔lattice bridge | `../theory/figures/semiring-bridge.d2` | D2 | concept map |
| 8 | Lawfulness matrix | `../theory/figures/lawfulness-matrix.dot` | Graphviz | coloured table |
| 9 | `M₃` & `N₅` forbidden sublattices | `../theory/figures/m3-n5.tex` | TikZ | publication Hasse |
| 10 | `Lattice` trait + implementors `†` | `../design/figures/lattice-class.mmd` | Mermaid | class diagram |
| 11 | Crate family / orphan diamond | `../design/figures/crate-family.d2` | D2 | dependency DAG |
| 12 | `Option::join` flow | `../design/figures/option-join-flow.dot` | Graphviz | flowchart |
| 13 | `Vec::join` flow | `../design/figures/vec-join-flow.dot` | Graphviz | flowchart |
| 14 | `Vec::meet` flow | `../design/figures/vec-meet-flow.dot` | Graphviz | flowchart |
| 15 | CRDT convergence `†` | `../guides/figures/crdt-convergence.mmd` | Mermaid | sequence |
| 16 | Monotone fixpoint ascent | `../guides/figures/fixpoint-ascent.dot` | Graphviz | ascending chain |
| 17 | `NaN` poisoning | `../engineering/figures/nan-poison.dot` | Graphviz | data-flow |

---

## 3. Shared colour palette

Defined once, reused everywhere, so a colour means the same concept across all 17 figures.

| Swatch | Hex | Concept |
|--------|-----|---------|
| slate | `#E5E7EB` | `⊥` / bottom / neutral |
| light blue | `#DBEAFE` | atoms / first rank |
| mid blue | `#BFDBFE` | mid rank / coatoms |
| strong blue | `#93C5FD` | `⊤` / top / most-specific |
| green | `#86EFAC` | **join** result / "holds" / the shared leaf |
| amber | `#FCD34D` | **meet** result / "holds up to ≅" |
| violet | `#C4B5FD` | operands / the trait / bridge |
| red | `#FCA5A5` | danger (`NaN`, DoS) / "fails" |
| grey | `#6B7280` | covering edges |

Mnemonic: **green climbs up (join), amber descends (meet)**.

---

## 4. Render pipeline (reproducible)

A single `Makefile` discovers every source in the `docs/` tree and renders it to a sibling image:

```sh
make -C docs/diagrams          # render everything out of date
make -C docs/diagrams clean    # remove generated images
make -C docs/diagrams list     # list discovered sources
```

Per-engine invocation (what the Makefile runs):

```sh
dot -Tsvg figure.dot -o figure.svg                    # Graphviz
d2 --layout elk figure.d2 figure.svg                  # D2
mmdc -c mermaid.json -i figure.mmd -o figure.png -s 2 # Mermaid → PNG (Chromium)
latex figure.tex && dvisvgm figure.dvi -o figure.svg  # TikZ via the DVI route
```

**Two deliberate engineering choices**, recorded so future maintainers do not "fix" them:

- **Mermaid renders to PNG, not SVG.** Mermaid's SVG uses `<foreignObject>` HTML labels that GitHub and
  librsvg cannot rasterise (they appear blank); its native-text SVG mode collapses inter-word spaces. Rendering
  to PNG via headless Chromium (`mmdc -s 2`) sidesteps both, giving portable, space-correct, fully-coloured
  output. Graphviz/D2/TikZ have no such issue and stay scalable SVG.
- **TikZ uses the DVI route** (`latex` → `dvisvgm`), not `pdflatex` → `dvisvgm --pdf`: the latter requires
  Ghostscript `< 10.01`, which is older than what is installed. The DVI route needs no Ghostscript.

**Kroki fallback.** A self-hosted [Kroki](https://kroki.io) gateway (catalog tool, `uml_architecture`) can render
all of these engines over HTTP at `http://localhost:8000/<type>/svg` when the native CLIs are unavailable —
useful in constrained CI. It is optional; the native pipeline above is the default.

---

## 5. Conventions for contributors

- **Author in a catalog language; commit both source and rendered image.** Never hand-edit a generated `.svg`/`.png`.
- **Reuse the palette** in §3 so colours stay meaningful across figures.
- **Keep flowcharts in Graphviz** (reliable, scalable, space-preserving); reserve Mermaid for class and sequence
  diagrams.
- **Verify DOIs via the Crossref API**, not the `doi.org` HTML endpoint (which 403s automated requests):
  `curl -s -o /dev/null -w '%{http_code}' https://api.crossref.org/works/<DOI>` should return `200`. Every DOI
  cited in the documentation has been checked this way.
