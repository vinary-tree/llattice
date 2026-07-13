# Per-Implementation Semantics

> **Audience.** Anyone calling `join`/`meet` who needs the exact behavioural contract of each built-in impl —
> the order it induces, its bounds, its edge cases, and the precise lawfulness scope. This is the API-level
> companion to the proofs in [theory/03](../theory/03-lawfulness-and-proofs.md).

---

## 1. The contract of the trait itself

```rust
pub trait Lattice: Clone + Send + Sync {
    fn join(&self, other: &Self) -> Self;   // ⊔  least upper bound
    fn meet(&self, other: &Self) -> Self;   // ⊓  greatest lower bound
}
```

- **Totality.** Both methods are total — they return a `Self` for every pair of inputs. None of the built-in
  impls panic, loop forever, or allocate unboundedly beyond the size of their inputs. (See the no-panic
  guarantee in [engineering/03](../engineering/03-security.md).)
- **`# Panics`: none.** No built-in impl contains `panic!`, `unwrap`, `expect`, indexing, or arithmetic that
  can overflow — `max`/`min`/set-ops/`clone` are panic-free.
- **No `bottom()` / `top()` in the trait.** The trait intentionally exposes *only* the two binary operations.
  $`\bot`$ and $`\top`$ exist *per impl* (see the table below) but are **not** part of the contract. Consequences:
  - You cannot write a fully generic `fold` from an empty seed over arbitrary `L: Lattice` — there is no generic
    identity. Seed folds with a concrete bottom you supply (e.g. `HashSet::new()`); see
    [guides/03](../guides/03-crdt-cookbook.md).
  - This keeps the trait minimal and implementable by *unbounded* lattices (like `HashSet`, which has no runtime
    $`\top`$). A bounded-lattice extension could add `fn bottom() -> Self` later without breaking this one.

---

## 2. The semantics table

For each impl: the carrier set, the induced order $`\sqsubseteq`$, what `join`/`meet` compute, the bounds, and a pointer to
the lawfulness scope.

| Impl | $`\sqsubseteq`$ (induced order) | `join` ($`\sqcup`$) | `meet` ($`\sqcap`$) | $`\bot`$ | $`\top`$ | Lawfulness |
|------|---------------------|-----------|-----------|-----|-----|------------|
| `u8 … u128`, `usize` | $`\leq`$ | `max` | `min` | `0` | `MAX` | full ([03 §2](../theory/03-lawfulness-and-proofs.md#2-numeric-types--join--max-meet--min)) |
| `i8 … i128`, `isize` | $`\leq`$ | `max` | `min` | `MIN` | `MAX` | full |
| `f32`, `f64` | $`\leq`$ (partial; `NaN` incomparable) | `max` | `min` | $`-\infty`$ | $`+\infty`$ | **NaN-free only** ([03 §6](../theory/03-lawfulness-and-proofs.md#6-f32--f64--lawful-only-on-the-nan-free-extended-reals)) |
| `bool` | `false` $`\leq`$ `true` | $`\lor`$ (OR) | $`\land`$ (AND) | `false` | `true` | full (Boolean) |
| `Option<T: Lattice>` | $`\mathrm{None} \sqsubseteq \mathrm{Some}(\_)`$; $`\mathrm{Some}(a) \sqsubseteq \mathrm{Some}(b) \iff a \sqsubseteq b`$ | see below | see below | `None` | $`\mathrm{Some}(\top_T)`$ if `T` has $`\top`$ | **inherits `T`** ([03 §5](../theory/03-lawfulness-and-proofs.md#5-optiont--the-lift-bottom-adjunction)) |
| `HashSet<T: Clone + Eq + Hash + Send + Sync>` | $`\subseteq`$ | $`\cup`$ (union) | $`\cap`$ (intersection) | `{}` | *(none at runtime)* | full; no $`\top`$/$`\lnot`$ ([03 §4](../theory/03-lawfulness-and-proofs.md#4-hashsett--union-and-intersection)) |
| `Vec<T: Clone + Eq + Send + Sync>` | $`\subseteq`$ on contents (left-biased order) | concat + dedup | left-biased $`\cap`$ | `[]` | *(none)* | **join-semilattice up to content-eq** ([03 §7](../theory/03-lawfulness-and-proofs.md#7-vect--a-join-semilattice-on-the-content-quotient)) |

---

## 3. Edge cases, spelled out

These are the inputs that surprise people. Each is a guarantee you can rely on.

### `Option<T>`

```rust
use llattice::Lattice;
assert_eq!(Some(5u32).join(&None),     Some(5)); // None is identity for ⊔
assert_eq!(None.join(&Some(3u32)),     Some(3));
assert_eq!(None::<u32>.join(&None),    None);    // ⊥ ⊔ ⊥ = ⊥
assert_eq!(Some(5u32).meet(&None),     None);    // None annihilates ⊓
assert_eq!(Some(5u32).join(&Some(3)),  Some(5)); // recurses: max(5,3)
assert_eq!(Some(5u32).meet(&Some(3)),  Some(3)); // recurses: min(5,3)
```

`join` fills in a value if *either* side has one; `meet` requires *both*. This is the lift $`T_\bot`$.

### `HashSet<T>`

```rust
use llattice::Lattice;
use std::collections::HashSet;
let a: HashSet<i32> = [1, 2].into_iter().collect();
let b: HashSet<i32> = [3, 4].into_iter().collect();
assert_eq!(a.join(&b), [1, 2, 3, 4].into_iter().collect()); // disjoint: union grows
assert!(a.meet(&b).is_empty());                              // disjoint: meet = {} = ⊥
let empty: HashSet<i32> = HashSet::new();
assert_eq!(a.join(&empty), a.clone());                       // {} is the identity for ∪
assert!(a.meet(&empty).is_empty());                          // {} annihilates ∩
```

### `Vec<T>` — order is left-biased (the load-bearing caveat)

```rust
use llattice::Lattice;
// join keeps the LEFT operand's order, then appends genuinely-new elements:
assert_eq!(vec![3, 1, 2].join(&vec![4, 2, 1]), vec![3, 1, 2, 4]);
// meet keeps the LEFT operand's elements that also appear on the right, in the LEFT's order:
assert_eq!(vec![3, 1, 2].meet(&vec![4, 2, 1]), vec![1, 2]);
// hence join is NOT symmetric as a Vec value (only up to content-equality):
assert_eq!(vec![1, 2].join(&vec![2, 1]), vec![1, 2]);
assert_eq!(vec![2, 1].join(&vec![1, 2]), vec![2, 1]); // ≠ the line above as Vec values
```

If you need a *symmetric* set meet/join on values, use `HashSet` instead — see
[theory/03 §7](../theory/03-lawfulness-and-proofs.md#7-vect--a-join-semilattice-on-the-content-quotient).

### `f32` / `f64` — `NaN`

```rust
use llattice::Lattice;
assert_eq!(5.0_f64.join(&3.0), 5.0);
assert_eq!(5.0_f64.meet(&3.0), 3.0);
// NaN is silently dropped by max/min, and NaN.join(&NaN) != NaN under ==:
assert_eq!(3.0_f64.join(&f64::NAN), 3.0);     // the NaN vanishes
assert!((f64::NAN.join(&f64::NAN)).is_nan()); // both-NaN yields NaN…
assert!(f64::NAN != f64::NAN);                // …but NaN != NaN, so idempotency-under-== fails
```

Validate away `NaN` at your boundary before using the float impl in any order-dependent computation.

---

## 4. Syntactic coverage (rustdoc)

The crate's public surface is exactly: the `Lattice` trait, its two methods, and the impls listed above. Every
public item carries a doc-comment with at least one `# Examples` block; the trait and methods additionally state
their $`\sqcup`$/$`\sqcap`$ meaning and the laws (with the scoped lawfulness pointer added by this documentation pass). Because
the surface is so small, **100 % rustdoc coverage** is both achievable and maintained — verify with
`cargo doc --no-deps` (no missing-docs warnings) and the doctest run described in
[engineering/01](../engineering/01-testing.md).

---

## 5. Where to go next

- The proofs behind every "Lawfulness" cell: **[theory/03](../theory/03-lawfulness-and-proofs.md)**.
- Putting these semantics to work: **[guides/02 — implementing Lattice](../guides/02-implementing-lattice.md)**
  and **[guides/03 — CRDT cookbook](../guides/03-crdt-cookbook.md)**.
- Performance and security characteristics: **[engineering/02](../engineering/02-performance.md)**,
  **[engineering/03](../engineering/03-security.md)**.
