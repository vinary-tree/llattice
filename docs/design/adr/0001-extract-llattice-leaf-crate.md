# ADR-0001 — Extract `Lattice` into a zero-dependency leaf crate

- **Status:** Accepted (realised by `llattice` 0.1.0)
- **Date:** 2026-06
- **Deciders:** `vinary-tree` maintainers
- **Related:** [design/01 — architecture](../01-architecture.md), [design/02 — orphan rule](../02-orphan-rule.md)

---

## Context

The `vinary-tree` family (`libdictenstein`, `liblevenshtein`, `lling-llang`, `duallity`, `libgrammstein`) all
manipulate values that merge commutatively and associatively — sets, counters, version data, automaton weights.
The lattice vocabulary `join`/`meet` first lived **inside `libdictenstein`**.

That placement caused a brewing problem. `lling-llang` also needed the lattice vocabulary, but a member crate
cannot depend "sideways" on `libdictenstein` just for a trait without risking a **dependency cycle**
(`libdictenstein` itself wants facilities that lean on the lattice vocabulary). The naive alternative — each
crate declaring its *own* `Lattice` — collides with Rust's **orphan rule**: each crate's
`impl Lattice for HashSet<T>` defines a *different, incompatible* trait, so a `HashSet` lattice cannot flow
between crates, and any crate depending on two members faces an unresolvable coherence **diamond** (analysed in
detail in [design/02](../02-orphan-rule.md)).

## Decision

**Extract the `Lattice` trait and all its `std`-type impls into a new, standalone crate `llattice` with
zero dependencies, and have every family member depend on it.**

Concretely:

1. `llattice` defines `trait Lattice: Clone + Send + Sync { join, meet }` and the impls for the numeric types,
   `f32`/`f64`, `bool`, `Option`, `HashSet`, `Vec`.
2. `llattice`'s `[dependencies]` is **empty**; it imports nothing beyond `std`. This "leaf" property is an
   invariant, not an accident.
3. Family crates `use llattice::Lattice;` and add `impl Lattice for TheirOwnType` locally (legal: they own the
   type).

## Consequences

**Positive**

- **One canonical trait.** A `HashSet<T>` (or any lattice value) produced in one crate is accepted by every
  other — no diamonds, no re-derivation, no orphan-rule contortions.
- **No dependency cycle.** The shared vocabulary sits *below* every member, so dependencies all point one way
  (down to the leaf).
- **Zero transitive cost.** Depending on `llattice` pulls in nothing else; crates needing only the vocabulary
  stay lean.
- **A natural home for each future impl.** The orphan rule now routes every impl to a unique legal location
  (the trait-owner for `std` types; the type-owner for local types).

**Negative / costs**

- **An extra crate to publish and version.** Mitigated by its tiny, stable surface (one trait).
- **The `Send + Sync` supertrait excludes non-thread-safe types** (e.g. `Rc`-based). Accepted: such types are
  not the merge-across-workers values the trait targets (see [design/01 §2](../01-architecture.md#2-why-the-supertrait-bound-is-clone--send--sync)).
- **Semiring machinery must stay out** to preserve the leaf property — which is why the semiring bridge lives in
  `lling-llang` ([ADR-0002](0002-semiring-bridge-lives-in-lling-llang.md)).

## Alternatives considered

- **Keep `Lattice` in `libdictenstein`.** Rejected: forces sideways dependencies and risks cycles.
- **Per-crate `Lattice` traits.** Rejected: orphan-rule diamond; incompatible `HashSet` lattices.
- **A `lattice`-feature behind a shared "core" mega-crate.** Rejected: heavier, drags in unrelated surface, and
  still risks cycles; a focused leaf is simpler and cheaper.
