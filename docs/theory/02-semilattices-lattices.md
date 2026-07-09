# Semilattices and Lattices — the two operations and their laws

> **Prerequisite:** [01 — Order theory](01-order-theory.md). We freely use poset, `⊑`, `⋖`, `⊥`, `⊤`,
> and Hasse diagrams from there. All symbols are in the [glossary](../GLOSSARY.md).

This document promotes a poset to a **lattice** by demanding least upper bounds and greatest lower bounds,
states the four algebraic laws those operations obey, proves the theorem that the order and the operations are
two views of one structure, and then classifies the richer kinds of lattice (bounded, complete, distributive,
Boolean) that the built-in impls realise.

---

## 1. Semilattices and lattices

Let `(S, ⊑)` be a poset.

- It is a **join-semilattice** if every pair `{a, b}` has a least upper bound `a ⊔ b` (the **join**).
- It is a **meet-semilattice** if every pair `{a, b}` has a greatest lower bound `a ⊓ b` (the **meet**).
- It is a **lattice** if it is *both*: every pair has a `⊔` *and* a `⊓`.

The `Lattice` trait asks for both methods, so it targets full lattices — but two of its impls (`Vec`, and any
non-NaN-free `f64` usage) only honour the join half cleanly; that nuance is the subject of
[document 03](03-lawfulness-and-proofs.md).

The defining geometry is worth fixing in the mind's eye. For any two elements `a` and `b`:

![lub/glb geometry: join sits above both operands, meet below both](figures/lub-glb-geometry.svg)

`a ⊔ b` is the *lowest* element still above both `a` and `b`; `a ⊓ b` is the *highest* element still below
both. The mnemonic — used in every diagram in this repository — is **green climbs up (join), amber descends
(meet)**.

The smallest non-trivial lattice is `bool`:

![the two-element lattice false ⊑ true](figures/bool-lattice.svg)

Here `⊔ = ∨` (logical OR), `⊓ = ∧` (logical AND), `⊥ = false`, `⊤ = true`.

---

## 2. The four laws

`⊔` and `⊓` are not arbitrary binary operations: as least-upper- and greatest-lower-bound operators they
*necessarily* satisfy four laws. For all `a, b, c`:

| Law | Join form | Meet form |
|----------------|------------------------------|------------------------------|
| **Idempotency**   | `a ⊔ a = a`                   | `a ⊓ a = a`                   |
| **Commutativity** | `a ⊔ b = b ⊔ a`               | `a ⊓ b = b ⊓ a`               |
| **Associativity** | `(a ⊔ b) ⊔ c = a ⊔ (b ⊔ c)`   | `(a ⊓ b) ⊓ c = a ⊓ (b ⊓ c)`   |
| **Absorption**    | `a ⊔ (a ⊓ b) = a`             | `a ⊓ (a ⊔ b) = a`             |

Each row is a dual pair ([01 §4](01-order-theory.md#4-the-duality-principle)), so proving the join form gives
the meet form for free.

> **Why these laws are the point, not decoration.** Idempotency, commutativity, and associativity are exactly
> the conditions under which *folding a multiset in any order, with any grouping, with repeats, yields one
> answer*. That is the convergence guarantee CRDTs rely on (see [guides/03](../guides/03-crdt-cookbook.md)):
>
> - **Idempotency** `a ⊔ a = a` ⟹ delivering the same update twice is a no-op (at-least-once delivery is safe).
> - **Commutativity** `a ⊔ b = b ⊔ a` ⟹ the arrival order of two updates does not matter.
> - **Associativity** `(a ⊔ b) ⊔ c = a ⊔ (b ⊔ c)` ⟹ how a batch is parenthesised does not matter.
>
> A binary operation that is associative, commutative, and idempotent is *equivalent data* to a
> join-semilattice — this is the **fundamental theorem of semilattices**, proved next.

### Lemma (absorption forces compatible domains)

Absorption is what *links* `⊔` and `⊓`. Idempotency, commutativity, and associativity alone describe two
independent semilattices; absorption is the axiom that says they order the same set the same way (so that the
order read off `⊔` agrees with the order read off `⊓`). We use it in §3.

---

## 3. The order/operation bridge

The order `⊑` and the operations `⊔`, `⊓` are **two presentations of one structure**. This is the single most
important theorem in lattice theory and the reason `llattice` can offer *either* view.

### Theorem (connecting lemma)

Let `(S, ⊑)` be a lattice with operations `⊔`, `⊓`. Then for all `a, b ∈ S`:

```text
a ⊑ b   ⟺   a ⊔ b = b   ⟺   a ⊓ b = a
```

Conversely, given a set `S` with operations `⊔`, `⊓` satisfying the four laws of §2, defining
`a ⊑ b :⟺ a ⊔ b = b` yields a partial order whose least upper bound is `⊔` and greatest lower bound is `⊓`.
The two constructions are mutually inverse.

### Proof

**(⇒, first equivalence.)** Suppose `a ⊑ b`. Then `b` is an upper bound of `{a, b}` (since `a ⊑ b` and
`b ⊑ b`). Any upper bound `u` of `{a, b}` satisfies `b ⊑ u`, so `b` is the *least* upper bound, i.e.
`a ⊔ b = b`.

**(⇐, first equivalence.)** Suppose `a ⊔ b = b`. Since `a ⊔ b` is an upper bound of `a`, we have
`a ⊑ a ⊔ b = b`, hence `a ⊑ b`.

**(second equivalence.)** Dually, `a ⊑ b ⟺ a ⊓ b = a`: if `a ⊑ b` then `a` is a lower bound of `{a, b}` and,
being `⊑` every lower bound's target, the *greatest* one, so `a ⊓ b = a`; conversely `a ⊓ b = a` gives
`a = a ⊓ b ⊑ b`. ∎

**(converse — the laws rebuild the order.)** Define `a ⊑ b :⟺ a ⊔ b = b`.

- *Reflexive:* `a ⊔ a = a` by idempotency, so `a ⊑ a`.
- *Antisymmetric:* if `a ⊔ b = b` and `b ⊔ a = a`, then by commutativity `a = b ⊔ a = a ⊔ b = b`.
- *Transitive:* if `a ⊔ b = b` and `b ⊔ c = c`, then `a ⊔ c = a ⊔ (b ⊔ c) = (a ⊔ b) ⊔ c = b ⊔ c = c`
  (associativity, then the hypotheses), so `a ⊑ c`.

That `⊔` computes the least upper bound of `{a, b}` under this `⊑`, and `⊓` the greatest lower bound, follows
from absorption: `a ⊑ a ⊔ b` because `a ⊔ (a ⊔ b) = (a ⊔ a) ⊔ b = a ⊔ b`; minimality and the meet side are the
duals, using `a ⊔ (a ⊓ b) = a` to show `a ⊓ b ⊑ a`. ∎

> **Consequence for `llattice`.** This is why the docs sometimes speak of `⊑` and sometimes of `⊔`/`⊓`: they
> are interchangeable. For `u32`, `a ⊔ b = b` *is* `max(a,b) = b` *is* `a ≤ b`. For `HashSet`, `a ⊔ b = b` *is*
> `a ∪ b = b` *is* `a ⊆ b`.

---

## 4. The structure hierarchy

Demanding more of a lattice yields the specialised structures the built-in impls inhabit. Each is the previous
plus one axiom:

![Specialization hierarchy: poset → semilattice → lattice → bounded → complete / distributive → Boolean](figures/lattice-taxonomy.svg)

- **Bounded lattice** — has a `⊥` and a `⊤`. (Numeric types: `MIN`/`MAX`. `bool`: `false`/`true`.)
- **Complete lattice** — *every* subset, not just every pair, has a `⊔` and `⊓`. Finite lattices are
  automatically complete; `𝒫(U)` is complete for any `U`. Completeness is what guarantees fixed points exist
  (Tarski; see [guides/04](../guides/04-fixpoints-and-analysis.md)).
- **Distributive lattice** — `⊓` distributes over `⊔`: `a ⊓ (b ⊔ c) = (a ⊓ b) ⊔ (a ⊓ c)`. Chains and power
  sets are distributive.
- **Boolean lattice** — bounded, distributive, and **complemented**: every `a` has `¬a` with `a ⊔ ¬a = ⊤` and
  `a ⊓ ¬a = ⊥`. `bool` and `𝒫(U)` are Boolean.

### Atoms, coatoms, and `2^U`

An **atom** covers `⊥`; a **coatom** is covered by `⊤`. In `𝒫({1,2,3})` the singletons are the atoms. A finite
Boolean lattice is determined by its atoms: it is isomorphic to the power set of its atom set, equivalently to a
product of copies of `2`:

```text
𝒫(U)  ≅  2^U  ≅  (a U-indexed tuple of bits)
```

This single isomorphism unifies three of the built-in impls — `bool` is the factor `2`, a version vector is the
product `2^U`, and `HashSet` is the power set `𝒫(U)`:

![Isomorphism 𝒫(U) ≅ 2^U linking bool, version vectors, and HashSet](figures/powerset-iso.svg)

---

## 5. Distributivity and the two forbidden sublattices

Distributivity is *not* automatic — and there is a beautiful structural test for it. **Birkhoff's criterion**:
a lattice is distributive **if and only if** it contains neither the *diamond* `M₃` nor the *pentagon* `N₅` as a
sublattice.

![The forbidden sublattices M₃ (diamond) and N₅ (pentagon)](figures/m3-n5.svg)

- `M₃` (the diamond) is **modular** but not distributive — it is the lattice of a 2-dimensional vector space's
  subspaces in miniature.
- `N₅` (the pentagon) is not even modular.

Why this matters here: the built-in impls are *all* distributive, and we can now say *why* — the numeric types
are chains (a chain contains neither `M₃` nor `N₅`, since both require incomparable elements), and `𝒫(U)` is a
power set (Boolean ⟹ distributive). No built-in impl embeds `M₃` or `N₅`. The `Lattice` trait itself, however,
imposes **no** distributivity, so a *user* impl may be non-distributive; the documentation never assumes
distributivity of arbitrary `Lattice` types.

---

## 6. Where to go next

The laws and structures are in place. The next document confronts the impls with these laws and asks, bluntly,
*which laws does each built-in impl actually satisfy, and under which notion of equality?* — exposing the two
places (`f64` with `NaN`, and `Vec`) where the textbook story needs care.

→ **[03 — Lawfulness and proofs](03-lawfulness-and-proofs.md)**

---

## References

1. Davey, B. A., & Priestley, H. A. (2002). *Introduction to Lattices and Order* (2nd ed.). Cambridge
   University Press. <https://doi.org/10.1017/CBO9780511809088> — §2.4–2.10 (lattices as algebras, the connecting
   lemma); §4.10 (the `M₃`–`N₅` theorem).
2. Birkhoff, G. (1967). *Lattice Theory* (3rd ed.). AMS Colloquium Publications, Vol. 25.
   <https://doi.org/10.1090/coll/025> — Chapters I–II.
3. Tarski, A. (1955). A lattice-theoretical fixpoint theorem and its applications. *Pacific Journal of
   Mathematics*, 5(2), 285–309. <https://doi.org/10.2140/pjm.1955.5.285> — completeness ⟹ fixed points.
