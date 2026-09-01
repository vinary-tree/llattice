# llattice

**A dependency-free `Lattice` trait for Rust** — `join` (least upper bound) and `meet` (greatest lower bound) — with built-in implementations for integers, floats, `bool`, `Option`, `HashSet`, and `Vec`. One shared lattice vocabulary for the whole family.

![License](https://img.shields.io/badge/license-Apache--2.0-blue)
[![crates.io](https://img.shields.io/crates/v/llattice.svg)](https://crates.io/crates/llattice)
[![docs.rs](https://img.shields.io/docsrs/llattice)](https://docs.rs/llattice)
![MSRV](https://img.shields.io/badge/rustc-1.70%2B-orange)
![deps](https://img.shields.io/badge/dependencies-0-success)

---

## What is llattice?

A **lattice** is a partially-ordered set in which *every pair* of elements has both a least upper bound and a greatest lower bound. llattice distills that idea to its smallest useful form: a single trait with two methods.

- **`join`** — the *least upper bound* (supremum, $`\sqcup`$): the smallest element that is $`\geq`$ both inputs. For numbers, $`\max`$; for sets, $`\cup`$ (union).
- **`meet`** — the *greatest lower bound* (infimum, $`\sqcap`$): the largest element that is $`\leq`$ both inputs. For numbers, $`\min`$; for sets, $`\cap`$ (intersection).

```rust
use llattice::Lattice;

assert_eq!(5u32.join(&3), 5); // least upper bound = max
assert_eq!(5u32.meet(&3), 3); // greatest lower bound = min
```

llattice is a **leaf crate**: it has **zero dependencies** and imports nothing beyond `std`. It was extracted from [`libdictenstein`](https://github.com/vinary-tree/libdictenstein) to break a dependency cycle, and now serves as the shared lattice vocabulary for the **libdictenstein / liblevenshtein / lling-llang / duallity / libgrammstein** family. Because the trait lives in one small crate everyone depends on, a `HashSet<T>` produced in one crate and merged in another agree on what `join` *means* — no orphan-rule gymnastics, no re-derivation, no diamond conflicts.

> **Terminology.** $`\sqsubseteq`$ is the **partial order** ("approximates" / "is below"). $`\sqcup`$ is **join**; $`\sqcap`$ is **meet**. A **join-semilattice** has only $`\sqcup`$ (every pair has a supremum); a **meet-semilattice** has only $`\sqcap`$; a **lattice** has both. The greatest element (if any) is $`\top`$ ("top"), the least is $`\bot`$ ("bottom").

---

## The lattice laws

`join` and `meet` are not arbitrary binary operations — they obey four laws that make them genuine lattice operations. The built-in impls satisfy all four, **with two documented exceptions**: `f32`/`f64` are lawful only on `NaN`-free values, and `Vec<T>` is a join-semilattice *up to content-equality* (its `join`/`meet` are left-biased in ordering). The precise, per-impl [**lawfulness matrix**](docs/theory/03-lawfulness-and-proofs.md) records exactly which law holds where.

| Law | Join form | Meet form |
|--------------------|-----------------------------------|-----------------------------------|
| **Idempotency**    | $`a \sqcup a = a`$                | $`a \sqcap a = a`$                |
| **Commutativity**  | $`a \sqcup b = b \sqcup a`$       | $`a \sqcap b = b \sqcap a`$       |
| **Associativity**  | $`(a \sqcup b) \sqcup c = a \sqcup (b \sqcup c)`$ | $`(a \sqcap b) \sqcap c = a \sqcap (b \sqcap c)`$ |
| **Absorption**     | $`a \sqcup (a \sqcap b) = a`$     | $`a \sqcap (a \sqcup b) = a`$     |

These laws are not decoration — they are exactly what makes lattice merge **safe under reordering and duplication**:

- **Idempotency** $`\implies`$ applying the same update twice is a no-op ($`a \sqcup a = a`$). At-least-once delivery is safe.
- **Commutativity** $`\implies`$ the order two updates arrive in does not matter ($`a \sqcup b = b \sqcup a`$).
- **Associativity** $`\implies`$ how you parenthesize a batch of merges does not matter.

Together these three give the property CRDTs rely on: *any* fold of *any* multiset of states, in *any* order, with *any* grouping, yields the same result.

The order and the operations are two views of one structure. Define the partial order **from** join:

```math
a \sqsubseteq b \quad\iff\quad a \sqcup b = b \quad\iff\quad a \sqcap b = a
```

The middle form says `b` is an upper bound of `a` (so `a` sits "below" `b`); the right form is the dual reading, via `meet`. So for `u32`, $`a \sqsubseteq b`$ is just $`a \leq b`$; for `HashSet`, $`a \sqsubseteq b`$ is $`a \subseteq b`$. `join` climbs the order toward $`\top`$; `meet` descends toward $`\bot`$.

---

## A worked example: the powerset lattice of {1, 2, 3}

The subsets of $`\{1, 2, 3\}`$, ordered by $`\subseteq`$, form a lattice where `join` is $`\cup`$ and `meet` is $`\cap`$. Its **Hasse diagram** (edges = "covered by", drawn upward) is the canonical picture of a lattice — and it is *exactly* what `HashSet<i32>` computes:

<img src="docs/diagrams/powerset-hasse.svg" alt="Hasse diagram of the powerset lattice of {1,2,3}" width="420"/>

```rust
use llattice::Lattice;
use std::collections::HashSet;

let s12: HashSet<i32> = [1, 2].into_iter().collect();
let s23: HashSet<i32> = [2, 3].into_iter().collect();

// Following the diagram upward to the least common ancestor:
assert_eq!(s12.join(&s23), [1, 2, 3].into_iter().collect()); // ⊔ = ∪ = {1,2,3}
// …and downward to the greatest common descendant:
assert_eq!(s12.meet(&s23), [2].into_iter().collect());       // ⊓ = ∩ = {2}
```

$`\bot`$ is $`\varnothing`$ (the empty set), $`\top`$ is $`\{1, 2, 3\}`$. Every pair has a unique supremum and infimum — the defining property of a lattice.

---

## Built-in implementations

Implementing `Lattice` requires `Clone + Send + Sync`. The crate ships these generic and concrete impls:

<img src="docs/design/figures/lattice-class.svg" alt="The Lattice trait and its built-in implementors; f64 and Vec carry lawfulness caveats" width="760"/>

| Type | `join` ($`\sqcup`$, supremum) | `meet` ($`\sqcap`$, infimum) | Order $`\sqsubseteq`$ | Bounds |
|------------------------------------------|----------------------------------|----------------------------------|------------|------------------|
| `u8 … u128`, `usize`, `i8 … i128`, `isize` | `max`                          | `min`                            | $`\leq`$   | `MIN` / `MAX`    |
| `f32`, `f64`                             | `f::max`                         | `f::min`                         | $`\leq`$   | $`\pm\infty`$    |
| `bool`                                   | $`\lor`$ (logical OR)            | $`\land`$ (logical AND)          | $`\text{false} \leq \text{true}`$ | `false` / `true` |
| `Option<T: Lattice>`                     | `Some` if **either** is `Some`   | `Some` only if **both** are `Some` | `None` $`\sqsubseteq`$ `Some(_)` | `None` = $`\bot`$ |
| `HashSet<T: Eq + Hash>`                  | $`\cup`$ (union)                 | $`\cap`$ (intersection)          | $`\subseteq`$ | `{}` = $`\bot`$  |
| `Vec<T: Eq>`                             | concat + dedup (order-preserving) | intersection (order-preserving)  | (see note) | `[]` = $`\bot`$  |

> **`f32`/`f64` caveat.** The float impls are a lattice (in fact a chain) only on the `NaN`-free extended reals $`[-\infty, +\infty]`$ ($`\bot = -\infty`$, $`\top = +\infty`$). `f64::max(NaN, x)` returns `x`, silently dropping a `NaN`, and `NaN != NaN` breaks idempotency under `==`. Validate away `NaN` before merging — see [theory/03 §6](docs/theory/03-lawfulness-and-proofs.md) and [the security threat model](docs/engineering/03-security.md).

Notes on the structural impls:

- **`Option<T>` is the "lifted" lattice.** `join` keeps a value if either side has one (`None` acts as bottom — $`\texttt{None} \sqcup x = x`$); `meet` requires *both* sides to be present ($`\texttt{None} \sqcap x = \texttt{None}`$). When both are `Some`, it recurses: $`\texttt{Some}(a) \sqcup \texttt{Some}(b) = \texttt{Some}(a \sqcup b)`$. This is the standard way to adjoin a fresh $`\bot`$ to any lattice `T`.
- **`Vec<T>` is the deduplicating, order-preserving view.** `join` appends elements of the right operand not already present ($`[3,1,2] \sqcup [4,2,1] = [3,1,2,4]`$); `meet` keeps the left operand's elements that also appear in the right, in the left's order ($`[3,1,2] \sqcap [4,2,1] = [1,2]`$). Treat it as a set-with-insertion-order, not a free monoid: idempotency and commutativity hold up to set-equality of contents, but the *ordering* of `join` is left-biased. Strictly, `Vec<T>` is a **join-semilattice on the content quotient**, *not* a full lattice on `Vec` values — $`[1,2] \sqcup [2,1] = [1,2]`$ while $`[2,1] \sqcup [1,2] = [2,1]`$, and absorption fails on raw `Vec`. Reach for `HashSet` when you need a symmetric set lattice; details in [theory/03 §7](docs/theory/03-lawfulness-and-proofs.md).

```rust
use llattice::Lattice;

// bool — the two-element lattice ⊥=false ⊑ ⊤=true
assert_eq!(true.join(&false), true);   // OR
assert_eq!(true.meet(&false), false);  // AND

// Option<T> — None is bottom; join fills in, meet requires both
assert_eq!(Some(5u32).join(&None), Some(5));
assert_eq!(Some(5u32).meet(&None), None);
assert_eq!(Some(5u32).join(&Some(3)), Some(5)); // recurses: max(5,3)
assert_eq!(Some(5u32).meet(&Some(3)), Some(3)); // recurses: min(5,3)
```

---

## Quick start

```toml
[dependencies]
llattice = "0.1"
```

The entire public surface is one trait and one import:

```rust
use llattice::Lattice;
use std::collections::HashSet;

// HashSet: join = union, meet = intersection
let a: HashSet<i32> = [1, 2].into_iter().collect();
let b: HashSet<i32> = [2, 3].into_iter().collect();
assert_eq!(a.join(&b), [1, 2, 3].into_iter().collect());
assert_eq!(a.meet(&b), [2].into_iter().collect());

// Numeric: join = max, meet = min
assert_eq!(5u32.join(&3), 5);
assert_eq!(5u32.meet(&3), 3);
```

Implement it for your own type by saying what "combine upward" and "combine downward" mean:

```rust
use llattice::Lattice;

/// A monotone version counter that only ever advances.
#[derive(Clone, PartialEq, Debug)]
struct Version(u64);

impl Lattice for Version {
    fn join(&self, other: &Self) -> Self { Version(self.0.max(other.0)) } // newer wins
    fn meet(&self, other: &Self) -> Self { Version(self.0.min(other.0)) } // common ancestor
}

assert_eq!(Version(7).join(&Version(4)), Version(7));
```

### Julia and Raku

The repository also contains natural Julia and Raku packages. They implement
the same lattice laws and can expose customer-defined values through the shared
Vinary Tree resource ABI without adding an FFI dependency to the Rust crate.

```julia
using LLattice
@assert join(MaxMin(3), MaxMin(8)) == MaxMin(8)
@assert validate_laws(MaxMin.([1, 2, 3]))
```

```raku
use LLattice;
my $left = FiniteSetLattice.new(value => set(<read write>));
my $right = FiniteSetLattice.new(value => set(<write admin>));
say $left.join($right).value;
```

See the [foreign-language architecture and usage guides](docs/bindings/README.md)
for installation, custom providers, stable encodings, ownership, threading,
security, and bounded batch operations.

---

## Use cases

### CRDT-style merges & state-based replication

A **join-semilattice** is the algebraic backbone of a **state-based CvRDT** (Convergent Replicated Data Type). In Shapiro et al.'s formulation, each replica holds a value drawn from a join-semilattice, and the merge of two replica states is their **join**. Because $`\sqcup`$ is idempotent, commutative, and associative, replicas that have seen the same set of updates — *regardless of order, duplication, or batching* — converge to the **identical** state. No coordination, no conflict resolution, no consensus round-trip:

<img src="docs/guides/figures/crdt-convergence.svg" alt="Three replicas merging a grow-only set in different orders converge to the same state" width="640"/>

```rust
use llattice::Lattice;
use std::collections::HashSet;

// Three replicas of a grow-only set (G-Set), each having seen different updates:
let r1: HashSet<&str> = ["alice"].into_iter().collect();
let r2: HashSet<&str> = ["bob", "carol"].into_iter().collect();
let r3: HashSet<&str> = ["alice", "bob"].into_iter().collect();

// Merge in ANY order — the result is always the full set (convergence):
let merged = r1.join(&r2).join(&r3);
assert_eq!(merged, ["alice", "bob", "carol"].into_iter().collect());
assert_eq!(merged, r3.join(&r1).join(&r2)); // order-independent
```

The same shape powers a **last-writer-wins register** (join over `(timestamp, value)` pairs), a **version vector** (join is element-wise $`\max`$, i.e. a `Vec`/map of counters), or a **monotone clock** (join is $`\max`$). Each is just a different `Lattice` instance over the same two-method contract.

### Monotone state & fixpoints

Lattices also model *monotone* computation: dataflow analyses, abstract interpretation, and Datalog-style fixpoint iteration all advance a value monotonically up a lattice ($`x \sqsubseteq f(x)`$) until it stops changing. llattice gives those engines a uniform `join` to accumulate facts and a uniform `meet` to intersect constraints.

---

## Relationship to semirings

There is a precise bridge between lattices and **idempotent semirings**. In a semiring $`(S, \oplus, \otimes, \bar{0}, \bar{1})`$ whose addition is idempotent ($`a \oplus a = a`$), the $`\oplus`$ operation is automatically a **join**: it is commutative, associative, idempotent, and induces the *natural order* $`a \sqsubseteq b \iff a \oplus b = b`$. So **every idempotent semiring carries a join-semilattice for free**.

The converse does *not* hold blindly: a semiring's $`\otimes`$ (multiplication) is generally **path composition**, not lattice meet — in a weighted-automaton (WFST) setting, $`\otimes`$ concatenates edge weights along a path while $`\oplus`$ selects the best among alternative paths. Conflating $`\otimes`$ with $`\sqcap`$ would be a category error.

For that reason the **semiring ↔ lattice bridge lives in [`lling-llang`](https://github.com/vinary-tree/lling-llang)**, not here. `lling-llang` owns the `IdempotentSemiring` types and provides the `Lattice` impl that exposes their $`\oplus`$ as `join`. llattice deliberately stays a pure, dependency-free leaf so that crates needing *only* the lattice vocabulary never pull in semiring machinery.

---

## Why a shared crate (not a local trait)?

Rust's orphan rule means a trait can only be implemented for a foreign type by the crate that *defines the trait* or the crate that *defines the type*. If each member of the family declared its own `Lattice`, then `libdictenstein`'s `HashSet` lattice and `lling-llang`'s `HashSet` lattice would be **different, incompatible traits** — a value could not flow between them, and any crate depending on both would face a diamond. Extracting `Lattice` into a single zero-dependency leaf crate gives the whole family one canonical trait, one set of built-in impls, and one source of truth for what `join`/`meet` mean.

---

## Documentation

In-depth documentation lives under [**`docs/`**](docs/README.md) — a guideline-driven suite with theory,
design, guides, language bindings, and engineering tracks, plus 20 fully-coloured diagrams rendered from committed sources.

- **Theory** — [order theory](docs/theory/01-order-theory.md) · [lattices & the four laws](docs/theory/02-semilattices-lattices.md) · [lawfulness matrix & proofs](docs/theory/03-lawfulness-and-proofs.md) · [the semiring bridge](docs/theory/04-semiring-bridge.md)
- **Design** — [architecture](docs/design/01-architecture.md) · [the orphan rule](docs/design/02-orphan-rule.md) · [per-impl semantics](docs/design/03-semantics.md) · [ADRs](docs/design/adr/)
- **Guides** — [quickstart](docs/guides/01-quickstart.md) · [implementing `Lattice`](docs/guides/02-implementing-lattice.md) · [CRDT cookbook](docs/guides/03-crdt-cookbook.md) · [fixpoints & analysis](docs/guides/04-fixpoints-and-analysis.md)
- **Language bindings** — [architecture](docs/bindings/README.md) · [Julia](docs/bindings/julia.md) · [Raku](docs/bindings/raku.md) · [performance](docs/bindings/performance.md) · [capability matrix](docs/bindings/completeness-matrix.tsv)
- **Engineering** — [testing](docs/engineering/01-testing.md) · [performance](docs/engineering/02-performance.md) · [security](docs/engineering/03-security.md)
- **Reference** — [glossary](docs/GLOSSARY.md) · [diagram catalog](docs/diagrams/README.md) · [changelog](CHANGELOG.md)

Diagrams are rebuilt from their text sources with `make -C docs/diagrams` (Graphviz · D2 · PlantUML · TikZ).

---

## References

1. Birkhoff, G. *Lattice Theory* (3rd ed., 1967). American Mathematical Society Colloquium Publications, Vol. 25. [10.1090/coll/025](https://doi.org/10.1090/coll/025)
2. Davey, B. A., & Priestley, H. A. (2002). *Introduction to Lattices and Order* (2nd ed.). Cambridge University Press. [10.1017/CBO9780511809088](https://doi.org/10.1017/CBO9780511809088)
3. Shapiro, M., Preguiça, N., Baquero, C., & Zawirski, M. (2011). *Conflict-Free Replicated Data Types.* In *Stabilization, Safety, and Security of Distributed Systems (SSS 2011)*, LNCS 6976, pp. 386–400. Springer. [10.1007/978-3-642-24550-3_29](https://doi.org/10.1007/978-3-642-24550-3_29)

---

## License

Licensed under **Apache-2.0**. Minimum supported Rust version: **1.70**.

Part of the [vinary-tree](https://github.com/vinary-tree) family:
[`libdictenstein`](https://github.com/vinary-tree/libdictenstein) ·
[`liblevenshtein`](https://github.com/vinary-tree/liblevenshtein-rust) ·
[`lling-llang`](https://github.com/vinary-tree/lling-llang) ·
[`duallity`](https://github.com/vinary-tree/duallity)
