# Coherence and the orphan rule

## 1. The problem

Rust accepts a trait implementation only when the implementing crate owns the
trait or the type. This **orphan rule** gives the program one coherent answer to
each trait/type pair. Neither `libdictenstein` nor `lling-llang` owns
`std::collections::HashSet`, so neither can implement a trait owned only by the
other.

If every project declared a local join trait, their values would look alike but
remain type-system incompatible:

```rust,ignore
// crate A
trait Join { fn join(&self, other: &Self) -> Self; }

// crate B: a distinct trait with the same spelling
trait Join { fn join(&self, other: &Self) -> Self; }
```

A third crate importing both would need adapters for identical concepts, risk
diamond dependencies, and lose a single place to state the laws.

## 2. The shared-leaf solution

`llattice` owns the canonical traits, so it may provide the standard-library
implementations:

```rust
use std::collections::HashSet;
use std::hash::{BuildHasher, Hash};

# use llattice::JoinSemilattice;
fn accepts_any_hashset<T, S>(value: HashSet<T, S>)
where
    T: Clone + Eq + Hash,
    S: BuildHasher + Clone,
    HashSet<T, S>: JoinSemilattice,
{
    # let _ = value;
}
```

Family crates depend inward on the leaf and implement its traits for their own
local domain types. The dependency arrows stay acyclic:

![Shared leaf and avoided orphan diamond](figures/crate-family.svg)

## 3. Why the leaf owns laws, not policy

Coherence is valuable only when the shared trait means something precise.
`JoinSemilattice` therefore owns idempotency, commutativity, associativity, the
derived-order bridge, and the exact `join_assign` refinement. `Lattice` adds the
cross-operation absorption promise.

Scheduling, proof-certificate transport, equality saturation, and optimization
provenance are not required for coherence. They remain in the higher crates.
This keeps applications that need only a lawful join from pulling in the full
compiler stack.

## 4. Generic standard-library implementations

The `HashSet<T, S>` implementation is generic over `S: BuildHasher + Clone`.
This matters for deterministic analysis, denial-of-service-resistant services,
and specialized high-throughput hashers. `Bottom` additionally requires
`S: Default`; without a default hasher, constructing an empty set is not
context-free.

`Option<T>` is capability-preserving. It does not force `T` to be a full
lattice merely to lift its join. That avoids another form of accidental
coupling: demanding more algebra than a downstream type actually owns.

## 5. Downstream implementation rule

A family crate should:

1. implement only the smallest lawful trait set for its local type;
2. use the public law harness over exhaustive or generated samples;
3. add an explicit `Lattice` marker only after checking absorption;
4. put `Send + Sync` on the parallel API that moves the value;
5. never create another semantically duplicate lattice trait.

This yields one vocabulary, one law registry, and one optimization interface
without centralizing unrelated runtime policy.
