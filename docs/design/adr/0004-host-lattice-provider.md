# ADR-0004 — Put dynamic lattice values in the shared resource ABI

- **Status:** Accepted
- **Date:** 2026-08-30
- **Deciders:** Vinary Tree maintainers
- **Related:** [architecture](../01-architecture.md),
  [binding architecture](../../bindings/README.md),
  [`vinary-tree-interop` ABI reference](https://github.com/vinary-tree/vinary-tree-interop/blob/master/docs/abi-reference.md)

## Context

Rust can monomorphize `Lattice` implementations, but a Julia or Raku customer
cannot implement a Rust trait directly. Passing a language object as a raw
pointer would also leave ownership, garbage-collector rooting, exceptions,
thread attachment, and ABI evolution undefined. Duplicating a C ABI in every
consumer would create incompatible capability identifiers and layout drift.

The family already has a versioned, queryable `VtResource` contract in
`vinary-tree-interop`. A lattice element is immutable and naturally maps to an
owned resource whose operations return new owned resources.

## Decision

Keep the Rust crate dependency-free and put the dynamic lattice-value contract
in `vinary-tree-interop` as capability `vt.lattice.val.1`. The capability has:

1. `join`, `meet`, and equality callbacks;
2. stable bytes that identify the value within a 16-byte domain;
3. bounded batch `join_many` and `meet_many` callbacks;
4. two-call diagnostics and byte-buffer operations;
5. explicit flags for thread confinement, parallel reentrancy, stable bytes,
   and native batching; and
6. ordinary `VtResource` retain/release ownership.

Language packages own runtime-specific rooting and exception containment.
Algorithms consume the capability through shared adapters rather than placing
foreign handles inside the native `Lattice` trait. A callback is never invoked
while an algorithm's internal lock is held.

## Consequences

### Positive

- Native Rust remains statically dispatched and allocation-free where the
  concrete lattice allows it.
- Foreign providers have one evolvable contract shared by all family projects.
- Batch callbacks amortize the foreign-function boundary for associative folds.
- Stable bytes allow cross-provider operations when a host supplies a decoder.
- Thread safety is declared and checked instead of inferred from a runtime.

### Costs

- Dynamic values pay resource allocation and indirect-call costs.
- Julia must root provider state in a registry; one short lock is needed when
  outputs are registered and when resource ownership changes.
- Rakudo NativeCall cannot store callback pointers directly in a `CStruct`, so
  the Raku package compiles a small C17 shim. Its reference count is atomic and
  callback execution itself does not take a native mutex.

These costs are isolated to the dynamic path. Callers should use bounded batch
folds for workloads large enough for boundary overhead to matter.

## Rejected alternatives

- **Add `vinary-tree-interop` as a Rust dependency.** Rejected because it would
  violate the leaf invariant and tax native users who do not use an FFI.
- **Store foreign handles in `Lattice`.** Rejected because garbage-collector
  rooting, resource ownership, callback containment, and runtime thread rules
  are not algebraic capabilities. The native trait remains `Clone +
  PartialEq`; consumers add `Send + Sync` only at a concrete parallel
  scheduling boundary.
- **One handwritten ABI per language.** Rejected because layouts, ownership,
  and capability identities would drift.
- **Process-global memoization.** Rejected because lattice results are
  derivable, domain-specific, and potentially unbounded; consumers can add a
  bounded policy where a workload demonstrates reuse.
