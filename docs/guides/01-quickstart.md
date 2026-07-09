# Quickstart

> **Goal.** Be productive with `llattice` in five minutes. The whole public surface is one trait and one
> import; this guide gets you from `cargo add` to your first `join`/`meet`.

---

## 1. Install

```toml
# Cargo.toml
[dependencies]
llattice = "0.1"
```

`llattice` has **zero dependencies** and an MSRV of **Rust 1.70**, so adding it costs nothing transitively.

---

## 2. The one import

```rust
use llattice::Lattice;
```

That brings the two methods into scope on every type that implements the trait:

```rust
use llattice::Lattice;

// Numbers: join = max, meet = min
assert_eq!(5u32.join(&3), 5);
assert_eq!(5u32.meet(&3), 3);
```

`join` (⊔) climbs *up* the order (for numbers, `max`); `meet` (⊓) descends (for numbers, `min`). The full
mental model is in [theory/01](../theory/01-order-theory.md); you do not need it to start.

---

## 3. Sets: union and intersection

```rust
use llattice::Lattice;
use std::collections::HashSet;

let a: HashSet<i32> = [1, 2].into_iter().collect();
let b: HashSet<i32> = [2, 3].into_iter().collect();

assert_eq!(a.join(&b), [1, 2, 3].into_iter().collect()); // ⊔ = ∪ (union)
assert_eq!(a.meet(&b), [2].into_iter().collect());       // ⊓ = ∩ (intersection)
```

This is the powerset lattice in action — the canonical picture of what `llattice` computes:

![Powerset lattice Hasse diagram](../diagrams/powerset-hasse.svg)

---

## 4. The full menu of built-in types

Every common shape already implements `Lattice`:

```rust
use llattice::Lattice;

// bool — the two-element lattice ⊥=false ⊑ ⊤=true
assert_eq!(true.join(&false), true);   // OR
assert_eq!(true.meet(&false), false);  // AND

// Option<T> — None is bottom; join fills in, meet requires both
assert_eq!(Some(5u32).join(&None), Some(5));
assert_eq!(Some(5u32).meet(&None), None);

// Vec<T> — set-with-insertion-order (join dedups, meet intersects; left-biased)
assert_eq!(vec![1, 2, 3].join(&vec![2, 3, 4]), vec![1, 2, 3, 4]);
assert_eq!(vec![1, 2, 3].meet(&vec![2, 3, 4]), vec![2, 3]);
```

For the exact behaviour, bounds, and caveats of each type, see
[design/03 — semantics](../design/03-semantics.md). Two impls have caveats worth knowing early:

- **`f32`/`f64`** are a clean lattice *only on `NaN`-free values* — validate away `NaN` first
  ([theory/03 §6](../theory/03-lawfulness-and-proofs.md)).
- **`Vec`** is *left-biased* and lawful only up to content-equality — use `HashSet` if you want a symmetric set
  lattice ([theory/03 §7](../theory/03-lawfulness-and-proofs.md)).

---

## 5. Next steps

- **Implement `Lattice` for your own type** → [02 — Implementing Lattice](02-implementing-lattice.md).
- **Build CRDTs** (grow-only sets, counters, LWW registers, version vectors) → [03 — CRDT cookbook](03-crdt-cookbook.md).
- **Run fixpoint / dataflow analyses** → [04 — Fixpoints and analysis](04-fixpoints-and-analysis.md).
- **Understand the theory** → start at [theory/01](../theory/01-order-theory.md).
