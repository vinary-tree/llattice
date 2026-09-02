# `llattice` Documentation

The complete documentation for **`llattice`** — dependency-free layered
`JoinSemilattice`, `MeetSemilattice`, `Lattice`, and `Bottom` traits for Rust.
Start at the [crate README](../README.md) for the elevator pitch; this tree is the in-depth treatment.

Every document renders mathematics in GitHub-native MathJax (inline math spans and ` ```math ` blocks) while
keeping Rust identifiers in `code` spans, defines each symbol before use (collected in the
[**Glossary**](GLOSSARY.md)), cites primary sources with resolvable DOIs, and illustrates concepts with
fully-coloured diagrams authored from the pgmcp diagramming catalog (see [diagrams/](diagrams/README.md)).

---

## How to read this (by audience)

| You are… | Start here | Then |
|----------|-----------|------|
| **new to the crate** | [guides/01 — Quickstart](guides/01-quickstart.md) | [guides/02 — Implementing the traits](guides/02-implementing-lattice.md) |
| **building distributed state** | [guides/03 — CRDT cookbook](guides/03-crdt-cookbook.md) | [guides/04 — Fixpoints & analysis](guides/04-fixpoints-and-analysis.md) |
| **here for the maths** | [theory/01 — Order theory](theory/01-order-theory.md) | [theory/02](theory/02-semilattices-lattices.md) → [03](theory/03-lawfulness-and-proofs.md) → [04](theory/04-semiring-bridge.md) |
| **integrating / reviewing** | [design/01 — Architecture](design/01-architecture.md) | [design/03 — Semantics](design/03-semantics.md), [engineering/03 — Security](engineering/03-security.md) |
| **using Julia or Raku** | [bindings — Overview](bindings/README.md) | [Julia](bindings/julia.md) or [Raku](bindings/raku.md) |
| **unsure about a symbol** | [Glossary](GLOSSARY.md) | — |

---

## Theory

The mathematical foundations, building from order to lattices to the semiring bridge.

1. [**01 — Order theory**](theory/01-order-theory.md) — posets, Hasse diagrams, bounds, duality.
2. [**02 — Semilattices and lattices**](theory/02-semilattices-lattices.md) — the two operations, the four laws,
   the order↔operation theorem, and the bounded/complete/distributive/Boolean hierarchy.
3. [**03 — Lawfulness and proofs**](theory/03-lawfulness-and-proofs.md) — the lawfulness matrix, reusable harness,
   formal traceability, and the `f64`/`Vec` exclusion counterexamples.
4. [**04 — The semiring bridge**](theory/04-semiring-bridge.md) — idempotent semirings as join-semilattices, why
   $`\otimes`$ is not `meet`, and why the bridge lives in `lling-llang`.

## Design

Why the crate is shaped the way it is.

- [**01 — Architecture**](design/01-architecture.md) — the trait layers, bounds, optimized operations, and the
  leaf-crate position.
- [**02 — The orphan rule**](design/02-orphan-rule.md) — coherence, the diamond it avoids, the crate's reason to
  exist.
- [**03 — Semantics**](design/03-semantics.md) — the per-impl behavioural contract: order, bounds, edge cases.
- Architecture Decision Records: [ADR-0001 — extract a leaf crate](design/adr/0001-extract-llattice-leaf-crate.md),
  [ADR-0002 — bridge in `lling-llang`](design/adr/0002-semiring-bridge-lives-in-lling-llang.md),
  [ADR-0003 — layered lawful traits](design/adr/0003-layered-lawful-traits.md), and
  [ADR-0004 — dynamic host providers](design/adr/0004-host-lattice-provider.md).

## Language bindings

- [**Overview and architecture**](bindings/README.md) — provider capability,
  domain identity, ownership, batching, threading, and security.
- [**Julia**](bindings/julia.md) — multiple dispatch, custom values,
  `VinaryTreeInterop.LatticeValue`, type stability, and Documenter.
- [**Raku**](bindings/raku.md) — roles, collection idioms, custom NativeCall
  providers, zef build behavior, and deterministic disposal.
- [**Performance**](bindings/performance.md) — direct, pairwise ABI, and bounded
  batch cost model; repeated-sample methodology and diagnostic results.
- [**Capability matrix**](bindings/completeness-matrix.tsv) — implemented cells
  and their conformance, benchmark, and documentation evidence.

## Guides

Task-oriented, with compilable examples.

- [**01 — Quickstart**](guides/01-quickstart.md) — install, imports, `join_assign`, `leq`, `join`, and `meet`.
- [**02 — Implementing the traits**](guides/02-implementing-lattice.md) — your own type, the obligations checklist,
  composition.
- [**03 — CRDT cookbook**](guides/03-crdt-cookbook.md) — G-Set, G/PN-counter, LWW register, version vector,
  monotone clock.
- [**04 — Fixpoints and analysis**](guides/04-fixpoints-and-analysis.md) — monotone fixed points, dataflow,
  abstract interpretation, Datalog.

## Engineering

Operational concerns.

- [**01 — Testing**](engineering/01-testing.md) — the reusable law harness, property tests, formal refinement, and stack tests.
- [**02 — Performance**](engineering/02-performance.md) — complexity, allocation behavior, in-place joins, and the benchmark protocol.
- [**03 — Security**](engineering/03-security.md) — unlawful-domain exclusion, hashing threats, resource bounds, and the
  no-`unsafe`/no-panic guarantees.
- [**04 — Releasing**](engineering/04-releasing.md) — immutable tags, independent verification, protected
  environments, crates.io OIDC trusted publishing, and public-byte read-back.

## Reference

- [**Glossary**](GLOSSARY.md) — every symbol, acronym, and term.
- [**Diagrams**](diagrams/README.md) — the figure catalog, render pipeline, and colour palette.
- [**Changelog**](../CHANGELOG.md) — version history.

---

## Documentation map

- `README.md` is this documentation index, and `GLOSSARY.md` defines the shared
  vocabulary.
- `theory/` develops order theory, lattices, lawfulness, and the semiring
  bridge.
- `design/` records architecture, semantics, orphan-rule implications, and
  architectural decision records.
- `bindings/` specifies the shared application binary interface (ABI), Julia
  and Raku providers, and their capability matrix.
- `guides/` covers the quick start, custom implementations, conflict-free
  replicated data types (CRDTs), and fixpoint analyses.
- `engineering/` covers testing, performance, security, and release controls.
- `diagrams/` contains the shared figure catalog, palette, and deterministic
  render pipeline. Each subject directory keeps its own editable figure
  sources beside their rendered artifacts.

Every figure is rendered from a committed text source (`.dot`, `.d2`, `.puml`, `.tex`) via
`make -C docs/diagrams`; the [diagrams README](diagrams/README.md) documents which catalog tool renders each.
