# Testing the Laws

> **Goal.** Turn the four lattice laws from prose into *executable checks*, so a custom `Lattice` impl is
> verified, not merely asserted. We give a dependency-free exhaustive checker (runnable today) and a
> `proptest`-based harness (the recommended approach for non-trivial domains), with the **lawful-subset
> generators** that keep `f64` and `Vec` honest.

---

## 1. The properties, as code

The laws of [theory/02 §2](../theory/02-semilattices-lattices.md) become four predicates over a triple
`(a, b, c)`. Stated once, reused for every impl:

```text
idempotent(a)        ≡  a.join(a) == a      ∧  a.meet(a) == a
commutative(a,b)     ≡  a.join(b) == b.join(a)  ∧  a.meet(b) == b.meet(a)
associative(a,b,c)   ≡  (a.join(b)).join(c) == a.join(b.join(c))   ∧  (dual for meet)
absorptive(a,b)      ≡  a.join(a.meet(b)) == a  ∧  a.meet(a.join(b)) == a
```

---

## 2. A dependency-free exhaustive checker

For a small finite type you can check *every* triple — a complete proof by exhaustion, with no test
dependencies. Here for `bool` (all `2³ = 8` triples):

```rust
use llattice::Lattice;

fn laws_hold<L: Lattice + PartialEq + Clone>(a: &L, b: &L, c: &L) -> bool {
    // idempotency
    a.join(a) == *a && a.meet(a) == *a &&
    // commutativity
    a.join(b) == b.join(a) && a.meet(b) == b.meet(a) &&
    // associativity
    a.join(b).join(c) == a.join(&b.join(c)) &&
    a.meet(b).meet(c) == a.meet(&b.meet(c)) &&
    // absorption
    a.join(&a.meet(b)) == *a && a.meet(&a.join(b)) == *a
}

// Exhaustive over bool: every triple satisfies every law.
for &a in &[false, true] {
    for &b in &[false, true] {
        for &c in &[false, true] {
            assert!(laws_hold(&a, &b, &c), "law violated at {a},{b},{c}");
        }
    }
}
```

The same `laws_hold` works for any `Lattice + PartialEq`; sweep a small integer range, or a fixed pool of
`HashSet`s, the same way.

---

## 3. Property-based testing with `proptest`

For large or infinite domains, sample instead of enumerate. Add the dev-dependency and assert the laws on random
triples. (Shown as a recommended pattern; it requires `proptest` in `[dev-dependencies]`, so it is not part of
the crate's own doctest run.)

```rust,ignore
use llattice::Lattice;
use proptest::prelude::*;

proptest! {
    #[test]
    fn u32_laws(a: u32, b: u32, c: u32) {
        prop_assert_eq!(a.join(&a), a);                       // idempotent
        prop_assert_eq!(a.join(&b), b.join(&a));              // commutative
        prop_assert_eq!(a.join(&b).join(&c), a.join(&b.join(&c))); // associative
        prop_assert_eq!(a.join(&a.meet(&b)), a);              // absorptive
    }
}
```

---

## 4. Lawful-subset generators (keeping `f64` and `Vec` honest)

The two impls with scoped lawfulness ([theory/03](../theory/03-lawfulness-and-proofs.md)) must be tested on the
domain / under the equality where their laws actually hold — otherwise the tests *correctly* fail, which is
noise, not signal.

### `f64` — exclude `NaN`

`f64` is lawful only on the `NaN`-free extended reals. Generate from that subset:

```rust,ignore
use proptest::prelude::*;
// any f64 that is not NaN (±∞ are fine — they are ⊥/⊤):
fn nan_free() -> impl Strategy<Value = f64> {
    any::<f64>().prop_filter("exclude NaN", |x| !x.is_nan())
}
proptest! {
    #[test]
    fn f64_idempotent(a in nan_free()) {
        prop_assert_eq!(a.join(&a), a); // holds on the NaN-free subset
    }
}
```

### `Vec` — compare up to content-equality

`Vec` is commutative/associative only *up to content-equality* ([theory/03 §7](../theory/03-lawfulness-and-proofs.md)).
Normalise (sort + dedup) before comparing, which compares *contents* rather than structural `Vec` order:

```rust,ignore
use llattice::Lattice;
use proptest::prelude::*;

fn content_eq(x: &[i32], y: &[i32]) -> bool {
    let (mut x, mut y) = (x.to_vec(), y.to_vec());
    x.sort_unstable(); x.dedup();
    y.sort_unstable(); y.dedup();
    x == y
}
proptest! {
    #[test]
    fn vec_commutative_up_to_content(a: Vec<i32>, b: Vec<i32>) {
        prop_assert!(content_eq(&a.join(&b), &b.join(&a))); // ✓ under content-equality
        // NOTE: a.join(&b) == b.join(&a) under structural Vec::== would FAIL — by design (left-biased).
    }
}
```

This is the executable form of the documentation's central correction: test `Vec` under `≈`, not `==`.

---

## 5. Literate sketch of a generic law-audit

For a reusable harness, structure the audit as: *for each impl, draw a representative sample, run every law,
report the first violating witness*. In literate form:

```text
audit(impl, sample):
    « draw a finite SAMPLE of representative values for `impl` »      ── small domain → exhaustive
                                                                       ── large domain → random (proptest)
    « pick the equality ≈ under which `impl` claims its laws »        ── == for numbers/bool/HashSet/Option
                                                                       ── content-equality for Vec
                                                                       ── NaN-free == for f64
    for each (a, b, c) in SAMPLE³:
        « evaluate idempotent, commutative, associative, absorptive under ≈ »
        if any fails:
            report (law, a, b, c)  and stop                           ── a counterexample witness
    report "all laws hold on SAMPLE under ≈"
```

The crate's own test module (`src/lib.rs`, `#[cfg(test)] mod tests`) is the seed of this: it pins the documented
behaviour of every impl with concrete `assert_eq!`s, including the idempotency and disjointness edge cases.

---

## 6. What the crate ships

`cargo test` runs:

- the unit tests in `src/lib.rs` (`numeric_u32`, `option`, `hashset`, `vec_preserves_order`, …), which lock in
  the per-impl semantics of [design/03](../design/03-semantics.md); and
- the **doctests** — every ` ```rust ` block in the README and in these guides is compiled and executed (wired
  via `#[doc = include_str!(...)]` in `src/lib.rs`), so every runnable example in this documentation is verified
  on each test run.

→ Continue to **[02 — Performance](02-performance.md)** for the complexity of each operation, or
**[03 — Security](03-security.md)** for the threat model.
