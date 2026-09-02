# ADR-0003 — Layer the algebra and expose only unconditional instances

- **Status:** Accepted
- **Date:** 2026-08-28
- **Deciders:** `vinary-tree` maintainers
- **Related:** [architecture](../01-architecture.md), [semantics](../03-semantics.md), [formal registry](../../../proofs/doc/lattice-invariants.tsv)

## Context

The 0.1 `Lattice` trait forced every domain to provide both operations and to be
`Send + Sync`. It also implemented raw floats and raw vectors while documenting
that their laws held only on a subset or quotient not represented by the type.
Those choices weakened the meaning of a trait bound and prevented join-only
semiring and CRDT domains from stating their real capability.

Fixed-point engines also paid for owned joins even when they already had a
mutable accumulator. They needed a reliable change flag to schedule dependent
work without a second whole-value comparison.

## Decision

1. Split the API into `JoinSemilattice`, `MeetSemilattice`, explicit
   `Lattice`, and context-free `Bottom`.
2. Make `join_assign` the required join primitive; its result is exact
   structural change. Provide owned `join` and join-derived `leq` defaults.
3. Require `Clone + PartialEq`, but move `Send + Sync` to parallel consumers.
4. Do not blanket-implement `Lattice` for all pairs of semilattice operations;
   absorption is an additional obligation.
5. Remove raw float and raw vector instances. Validated/canonicalized wrappers
   may implement the traits in the crate that owns the wrapper.
6. Generalize `HashSet` to cloneable build hashers and specialize its algorithms
   around larger-table cloning, smaller-side intersection, and accumulator
   reuse.
7. Require all input-sized work to be iterative and native-stack bounded.
8. Formalize the laws and transition model before Rust implementation, then
   validate the refinement with property, countermodel, stack, and performance
   tests.

## Consequences

Join-only domains are first-class, and the semiring bridge no longer invents a
meet. A trait bound now carries unconditional structural laws. Single-threaded
domains can participate; parallel APIs retain explicit safety. Fixed-point
engines can reuse allocation and schedule only on actual change.

The release is semver-major at the API level (`0.1` to `0.2`): imports move to
the operation traits, implementors split their methods, and raw float/vector
users must introduce domain wrappers. The stronger contract justifies the
migration cost.

## Alternatives rejected

- Keep one trait and add optional methods: this cannot express join-only generic
  bounds and leaves absorption ambiguous.
- Blanket `Lattice` over both semilattices: the formal OR/OR countermodel
  disproves the implication.
- Keep conditional instances with warnings: type checking still cannot enforce
  “no `NaN`” or content-quotient equality.
- Add a PDA to collection algebra: flat union/intersection is not
  pushdown-shaped; an iterative hash-table machine is smaller and faster.
