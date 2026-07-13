# The Semiring ↔ Lattice Bridge — and why it lives elsewhere

> **Prerequisite:** [02 — Semilattices and lattices](02-semilattices-lattices.md). Symbols in the
> [glossary](../GLOSSARY.md). This document explains a relationship `llattice` deliberately does **not**
> implement, and *why* that boundary is drawn where it is.

There is a precise, well-known bridge between **lattices** and **idempotent semirings**. Understanding it
explains a design decision: the bridge code lives in the sibling crate [`lling-llang`](https://github.com/vinary-tree/lling-llang),
never in `llattice`. This document makes the mathematics explicit so the boundary reads as principled, not
arbitrary.

---

## 1. Semirings and dioids

A **semiring** $`(S, \oplus, \otimes, \bar{0}, \bar{1})`$ is a set with two associative operations:

- $`\oplus`$ (**addition**), commutative, with identity $`\bar{0}`$;
- $`\otimes`$ (**multiplication**), with identity $`\bar{1}`$, distributing over $`\oplus`$ on both sides;
- $`\bar{0}`$ annihilates $`\otimes`$: $`\bar{0} \otimes a = a \otimes \bar{0} = \bar{0}`$.

Unlike a ring, there are **no additive inverses** — you cannot subtract. A semiring whose addition is
**idempotent** ($`a \oplus a = a`$ for all $`a`$) is called an **idempotent semiring** or **dioid**.

The motivating examples are the *path algebras*:

| Dioid | $`\oplus`$ | $`\otimes`$ | $`\bar{0}`$ | $`\bar{1}`$ | Use |
|-------|-----|-----|-----|-----|-----|
| tropical (min-plus) | $`\min`$ | $`+`$ | $`+\infty`$ | $`0`$ | shortest paths |
| max-plus | $`\max`$ | $`+`$ | $`-\infty`$ | $`0`$ | scheduling, longest paths |
| Boolean | $`\lor`$ | $`\land`$ | $`\text{false}`$ | $`\text{true}`$ | reachability |
| Viterbi | $`\max`$ | $`\times`$ | $`0`$ | $`1`$ | most-likely path |

In each, $`\oplus`$ *selects among alternative paths* and $`\otimes`$ *composes along a path*.

---

## 2. Every idempotent semiring carries a join-semilattice — for free

This is the bridge, in one theorem.

### Theorem (natural order of a dioid)

Let $`(S, \oplus, \otimes, \bar{0}, \bar{1})`$ be an idempotent semiring. Define the **natural (canonical) order**

```math
a \sqsubseteq b \;:\iff\; a \oplus b = b.
```

Then $`(S, \sqsubseteq)`$ is a join-semilattice whose join is $`\oplus`$ and whose least element is $`\bar{0}`$.

### Proof

$`\oplus`$ is commutative, associative, and (by hypothesis) idempotent. By the converse direction of the connecting
theorem ([02 §3](02-semilattices-lattices.md#3-the-orderoperation-bridge)), any such operation defines a
partial order via $`a \sqsubseteq b :\iff a \oplus b = b`$, under which $`\oplus`$ is the least upper bound. The additive identity $`\bar{0}`$
satisfies $`\bar{0} \oplus a = a`$, i.e. $`\bar{0} \sqsubseteq a`$ for all $`a`$, so $`\bar{0} = \bot`$. ∎

> **So the bridge is real and one-directional-cheap:** *give me any idempotent semiring and I hand you a
> join-semilattice with `join` $`= \oplus`$.* This is exactly the `Lattice` impl that `lling-llang` provides for its
> semiring types.

![The bridge: ⊕ maps to join; ⊗ does NOT map to meet; the impl lives in lling-llang](figures/semiring-bridge.svg)

---

## 3. Why multiplication is not meet

Having identified $`\oplus`$ with $`\sqcup`$, the seductive next step is to identify $`\otimes`$ with $`\sqcap`$. **This is a category
error**, and avoiding it is the reason the bridge is quarantined.

In a dioid, $`\otimes`$ is **path composition**, not greatest-lower-bound:

- In min-plus, $`a \otimes b = a + b`$ (concatenate edge weights), whereas $`a \sqcap b`$ would be $`\max(a, b)`$ — different
  operations with different units and different algebra.
- $`\otimes`$ need not be idempotent ($`a \otimes a \neq a`$ in general: $`2 + 2 \neq 2`$), so it is not even a semilattice operation.
- $`\otimes`$ need not be commutative (matrix dioids, weighted automata), whereas $`\sqcap`$ always is.

The correct reading: a dioid is a **join-semilattice $`(S, \oplus)`$ enriched with a monoid $`(S, \otimes, \bar{1})`$ that
distributes over the join**. The $`\otimes`$ direction is orthogonal to the meet; conflating them silently corrupts
any shortest-path or weighted-automaton computation. (`liblevenshtein`'s automata and `lling-llang`'s WFSTs
depend on getting this exactly right.)

If a dioid *also* happens to be a lattice (has a genuine $`\sqcap`$), that meet is an additional structure, not $`\otimes`$.

---

## 4. Why the bridge lives in `lling-llang`, not here

`llattice` is a **leaf crate**: it owns the `Lattice` vocabulary and nothing else (see
[design/01](../design/01-architecture.md)). The semiring↔lattice bridge requires *semiring types* —
`IdempotentSemiring`, the tropical/Viterbi instances, the $`\otimes`$ monoid. Those live in `lling-llang`. Placing the
bridge there, rather than in `llattice`, has three concrete payoffs:

1. **`llattice` stays dependency-free.** A crate that needs only the lattice vocabulary (say, a CRDT in
   `libdictenstein`) never pulls in semiring machinery it will not use.
2. **The orphan rule is respected without contortion.** `lling-llang` defines `IdempotentSemiring`, so it is
   allowed to write `impl<S: IdempotentSemiring> Lattice for S` — exposing $`\oplus`$ as `join` — because it owns the
   semiring trait. (See [design/02 — the orphan rule](../design/02-orphan-rule.md).)
3. **The category error is structurally impossible to make here.** Because `llattice` has no $`\otimes`$, no one can
   accidentally wire $`\otimes`$ to `meet` in this crate. The dangerous identification can only be written where the
   semiring lives, under the eyes of code that understands path composition.

```text
   llattice  ──owns──▶  trait Lattice { join, meet }      (no ⊗ anywhere)
       ▲
       │ depends on
       │
   lling-llang  ──owns──▶  trait IdempotentSemiring { ⊕, ⊗, 0̄, 1̄ }
                ──provides──▶  impl Lattice for S  (join = ⊕;  meet is NOT ⊗)
```

---

## 5. Summary

- Every idempotent semiring has a **natural order** making $`\oplus`$ a `join` and $`\bar{0}`$ a $`\bot`$ (a join-semilattice, for
  free).
- Its $`\otimes`$ is **path composition**, categorically distinct from `meet`; identifying them is a bug.
- Therefore the bridge belongs in the crate that owns the semiring types — `lling-llang` — keeping `llattice` a
  pure, dependency-free leaf and making the $`\otimes`$/$`\sqcap`$ confusion unrepresentable here.

→ Back to **[the theory index](../README.md#theory)**, or on to **[design/01 — architecture](../design/01-architecture.md)**.

---

## References

1. Gondran, M., & Minoux, M. (2008). *Graphs, Dioids and Semirings: New Models and Algorithms*. Springer.
   <https://doi.org/10.1007/978-0-387-75450-5> — the authoritative reference on dioids and their natural order.
2. Davey, B. A., & Priestley, H. A. (2002). *Introduction to Lattices and Order* (2nd ed.). Cambridge
   University Press. <https://doi.org/10.1017/CBO9780511809088> — the connecting lemma reused in §2.
