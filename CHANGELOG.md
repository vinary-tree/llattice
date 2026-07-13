# Changelog

All notable changes to **`llattice`** are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive `docs/` tree: theory (order theory, lattices, lawfulness proofs, the semiring bridge), design
  (architecture, the orphan rule, per-impl semantics, two ADRs), guides (quickstart, implementing `Lattice`, a
  CRDT cookbook, fixpoints & analysis), engineering (testing, performance, security), a glossary, and a diagram
  catalog.
- 19 fully-coloured, diagrams-as-code figures rendered from committed sources via `make -C docs/diagrams`
  (Graphviz, D2, PlantUML, TikZ), with a shared colour palette and a reproducible render pipeline.
- README examples and the documentation guides are now compiled and executed as doctests on `cargo test`.
- Two new figures: a **product-lattice** figure (`docs/guides/figures/product-lattice.puml`) showing
  componentwise `join`/`meet` on a struct, and a **law-audit** flowchart
  (`docs/engineering/figures/law-audit-flow.dot`) for the property-check pipeline.
- Additional DOI-linked citations: QuickCheck (testing), SipHash and the Crosby–Wallach algorithmic-complexity
  DoS attack (security), and Knaster/Kleene attributions (fixpoints).

### Changed
- **Aligned all documentation with the pgmcp documentation guidelines.** Mathematics is now written in
  GitHub-native MathJax — inline `` $`…`$ `` spans and ` ```math ` blocks — rather than Unicode literals inside
  inert `code` spans; Rust identifiers remain in `code` spans.
- **Migrated the class and CRDT-sequence figures from Mermaid to PlantUML** (byte-reproducible SVG with LaTeX
  labels typeset by JLaTeXMath). The retired Mermaid sources and `mermaid.json`, plus the redundant
  `powerset-hasse.puml`, are archived under `docs/archive/`.
- **Corrected the lawfulness claims** in `src/lib.rs` rustdoc and `README.md`. The previous blanket "satisfies
  the following properties" overstated the guarantees:
  - `f32`/`f64` form a lattice (a chain) only on the `NaN`-free extended reals $`[-\infty, +\infty]`$; with
    `NaN`, idempotency-under-`==` and the order break.
  - `Vec<T>` is a **join-semilattice on the content quotient** (commutativity/associativity hold only up to
    content-equality; absorption fails on raw `Vec` values), not a full lattice on `Vec` values.
  - `HashSet<T>` realises the bounded-below distributive-lattice fragment at runtime ($`\bot = \varnothing`$,
    no $`\top`$/complement); only the mathematical powerset $`\mathcal{P}(U)`$ is a complete atomic Boolean algebra.
- No behavioural or API changes — corrections are to documentation, comments, and figures only.

## [0.1.0]

### Added
- The `Lattice` trait — `join` (least upper bound, $`\sqcup`$) and `meet` (greatest lower bound, $`\sqcap`$) —
  with the supertrait bound `Clone + Send + Sync`.
- Built-in implementations for the integer types (`u8`…`u128`, `usize`, `i8`…`i128`, `isize`), `f32`/`f64`,
  `bool`, `Option<T>`, `HashSet<T>`, and `Vec<T>`.
- Unit tests pinning the documented semantics of every impl (numeric, boolean, option, set, vec ordering).
- Zero dependencies; MSRV Rust 1.70; Apache-2.0 licence. Extracted from `libdictenstein` to break a dependency
  cycle and serve as the shared lattice vocabulary for the `vinary-tree` family.

[Unreleased]: https://github.com/vinary-tree/llattice/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/vinary-tree/llattice/releases/tag/v0.1.0
