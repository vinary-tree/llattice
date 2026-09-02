# Changelog

All notable changes to `llattice` are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and releases follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## 0.2.0 — 2026-09-02

### Added

- Layered `JoinSemilattice`, `MeetSemilattice`, `Lattice`, and `Bottom` traits.
- `JoinSemilattice::join_assign`, an in-place join that reports structural
  change exactly, and `JoinSemilattice::leq`, the join-derived order.
- A public, dependency-free `laws` harness covering semilattice laws, the
  in-place refinement, partial-order coherence, absorption, and bottom.
- Context-free `Bottom` implementations for integers, `bool`, `Option<T>`, and
  `HashSet<T, S>` when its hasher has `Default`.
- Generic `HashSet<T, S>` support for every cloneable build hasher.
- A dependency-free `no_std` core when default features are disabled; the
  default `std` feature owns only the `HashSet` implementations.
- Lawful Julia and Raku packages, including host-defined lattice providers over
  the separately versioned `vinary-tree-interop` resource ABI.
- A pre-registered, reproducible hot-path benchmark with raw samples captured
  under repository-local `target/` and mandatory resource limits.
- Rocq proofs for the layered order, exact change flag, `Option` lift,
  non-absorption countermodel, unlawful sequence countermodel, and the strictly
  decreasing explicit-worklist machine used for stack-safety refinement.

### Changed

- `Lattice` is now an explicit absorption marker over the two semilattice
  traits. It is deliberately not blanket-implemented for every pair of
  semilattice operations.
- Algebraic traits require `Clone + PartialEq`, but no longer impose `Send` or
  `Sync`; concurrent consumers add those capabilities at their scheduling
  boundary.
- Integer and Boolean operations retain inline, constant-time specializations.
- `HashSet::join` clones the larger table and extends it with the smaller one;
  `meet` scans the smaller set; `join_assign` reuses accumulator storage. All
  collection algorithms are iterative and native-stack bounded.
- The crate version is `0.2.0` because imports and implementation obligations
  change: concrete method syntax needs `JoinSemilattice` and/or
  `MeetSemilattice` in scope, or `llattice::prelude::*`.
- The Rust algebra remains statically dispatched and independent of the dynamic
  provider ABI; foreign-language ownership and callback policies stay in their
  binding packages and `vinary-tree-interop`.

### Removed

- Raw `f32` and `f64` implementations. IEEE `NaN` breaks structural equality
  and the join-derived partial order; use a validated no-NaN newtype.
- Raw `Vec<T>` implementations. Left-biased sequence union is not commutative
  under structural equality and therefore is not a lawful semilattice value;
  use `HashSet`, a canonicalized set wrapper, or a domain-specific quotient.

## [0.1.0]

### Added

- The original monolithic `Lattice: Clone + Send + Sync` trait with `join` and
  `meet`.
- Built-ins for integers, raw floats, `bool`, `Option`, `HashSet`, and `Vec`.
- Dependency-free leaf-crate packaging, Rust 1.70 minimum, Apache-2.0 license,
  formal law proofs, and the first documentation suite.

[0.1.0]: https://github.com/vinary-tree/llattice/releases/tag/v0.1.0
