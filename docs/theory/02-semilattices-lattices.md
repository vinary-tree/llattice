# Semilattices and Lattices — the two operations and their laws

> **Prerequisite:** [01 — Order theory](01-order-theory.md). We freely use poset, $`\preceq`$, $`\prec`$, $`\perp`$, $`\mathrm{top}`$,
> and Hasse diagrams from there. All symbols are in the [glossary](../GLOSSARY.md).

This document promotes a poset to a **lattice** by demanding least upper bounds and greatest lower bounds,
states the four algebraic laws those operations obey, proves the theorem that the order and the operations are
two views of one structure, and then classifies the richer kinds of lattice (bounded, complete, distributive,
Boolean) that the built-in impls realise.

---

## 1. Semilattices and lattices

Let $`(S, \preceq)`$ be a poset.

- It is a **join-semilattice** if every pair $`\{a, b\}`$ has a least upper bound $`a \vee b`$ (the **join**).
- It is a **meet-semilattice** if every pair $`\{a, b\}`$ has a greatest lower bound $`a \wedge b`$ (the **meet**).
- It is a **lattice** if it is *both*: every pair has a $`\vee`$ *and* a $`\wedge`$.

The Rust API mirrors this hierarchy directly. `JoinSemilattice` and
`MeetSemilattice` are independent capabilities; the explicit `Lattice` marker
promises both plus absorption. Raw `Vec` and floating-point candidates are
excluded because their structural values cannot satisfy these laws
unconditionally; [document 03](03-lawfulness-and-proofs.md) proves the boundary.

The defining geometry is worth fixing in the mind's eye. For any two elements $`a`$ and $`b`$:

![lub/glb geometry: join sits above both operands, meet below both](figures/lub-glb-geometry.svg)

$`a \vee b`$ is the *lowest* element still above both $`a`$ and $`b`$; $`a \wedge b`$ is the *highest* element still below
both. The mnemonic — used in every diagram in this repository — is **green climbs up (join), amber descends
(meet)**.

The smallest non-trivial lattice is `bool`:

![the two-element lattice false \preceq true](figures/bool-lattice.svg)

Here $`\vee = \lor`$ (logical OR), $`\wedge = \land`$ (logical AND), $`\perp = \text{false}`$, $`\mathrm{top} = \text{true}`$.

---

## 2. The four laws

$`\vee`$ and $`\wedge`$ are not arbitrary binary operations: as least-upper- and greatest-lower-bound operators they
*necessarily* satisfy four laws. For all $`a, b, c`$:

| Law | Join form | Meet form |
|----------------|------------------------------|------------------------------|
| **Idempotency**   | $`a \vee a = a`$ | $`a \wedge a = a`$ |
| **Commutativity** | $`a \vee b = b \vee a`$ | $`a \wedge b = b \wedge a`$ |
| **Associativity** | $`(a \vee b) \vee c = a \vee (b \vee c)`$ | $`(a \wedge b) \wedge c = a \wedge (b \wedge c)`$ |
| **Absorption**    | $`a \vee (a \wedge b) = a`$ | $`a \wedge (a \vee b) = a`$ |

Each row is a dual pair ([01 §4](01-order-theory.md#4-the-duality-principle)), so proving the join form gives
the meet form for free.

> **Why these laws are the point, not decoration.** Idempotency, commutativity, and associativity are exactly
> the conditions under which *folding a multiset in any order, with any grouping, with repeats, yields one
> answer*. That is the convergence guarantee CRDTs rely on (see [guides/03](../guides/03-crdt-cookbook.md)):
>
> - **Idempotency** $`a \vee a = a \implies`$ delivering the same update twice is a no-op (at-least-once delivery is safe).
> - **Commutativity** $`a \vee b = b \vee a \implies`$ the arrival order of two updates does not matter.
> - **Associativity** $`(a \vee b) \vee c = a \vee (b \vee c) \implies`$ how a batch is parenthesised does not matter.
>
> A binary operation that is associative, commutative, and idempotent is *equivalent data* to a
> join-semilattice — this is the **fundamental theorem of semilattices**, proved next.

### Lemma (absorption forces compatible domains)

Absorption is what *links* $`\vee`$ and $`\wedge`$. Idempotency, commutativity, and associativity alone describe two
independent semilattices; absorption is the axiom that says they order the same set the same way (so that the
order read off $`\vee`$ agrees with the order read off $`\wedge`$). We use it in §3.

---

## 3. The order/operation bridge

The order $`\preceq`$ and the operations $`\vee`$, $`\wedge`$ are **two presentations of one structure**. This is the single most
important theorem in lattice theory and the reason `llattice` can offer *either* view.

### Theorem (connecting lemma)

Let $`(S, \preceq)`$ be a lattice with operations $`\vee`$, $`\wedge`$. Then for all $`a, b \in S`$:

```math
a \preceq b \iff a \vee b = b \iff a \wedge b = a
```

Conversely, given a set $`S`$ with operations $`\vee`$, $`\wedge`$ satisfying the four laws of §2, defining
$`a \preceq b :\iff a \vee b = b`$ yields a partial order whose least upper bound is $`\vee`$ and greatest lower bound is $`\wedge`$.
The two constructions are mutually inverse.

### Proof

**($`\Rightarrow`$, first equivalence.)** Suppose $`a \preceq b`$. Then $`b`$ is an upper bound of $`\{a, b\}`$ (since $`a \preceq b`$ and
$`b \preceq b`$). Any upper bound $`u`$ of $`\{a, b\}`$ satisfies $`b \preceq u`$, so $`b`$ is the *least* upper bound, i.e.
$`a \vee b = b`$.

**($`\Leftarrow`$, first equivalence.)** Suppose $`a \vee b = b`$. Since $`a \vee b`$ is an upper bound of $`a`$, we have
$`a \preceq a \vee b = b`$, hence $`a \preceq b`$.

**(second equivalence.)** Dually, $`a \preceq b \iff a \wedge b = a`$: if $`a \preceq b`$ then $`a`$ is a lower bound of $`\{a, b\}`$ and,
being $`\preceq`$ every lower bound's target, the *greatest* one, so $`a \wedge b = a`$; conversely $`a \wedge b = a`$ gives
$`a = a \wedge b \preceq b`$. ∎

**(converse — the laws rebuild the order.)** Define $`a \preceq b :\iff a \vee b = b`$.

- *Reflexive:* $`a \vee a = a`$ by idempotency, so $`a \preceq a`$.
- *Antisymmetric:* if $`a \vee b = b`$ and $`b \vee a = a`$, then by commutativity $`a = b \vee a = a \vee b = b`$.
- *Transitive:* if $`a \vee b = b`$ and $`b \vee c = c`$, then $`a \vee c = a \vee (b \vee c) = (a \vee b) \vee c = b \vee c = c`$
  (associativity, then the hypotheses), so $`a \preceq c`$.

That $`\vee`$ computes the least upper bound of $`\{a, b\}`$ under this $`\preceq`$, and $`\wedge`$ the greatest lower bound, follows
from absorption: $`a \preceq a \vee b`$ because $`a \vee (a \vee b) = (a \vee a) \vee b = a \vee b`$; minimality and the meet side are the
duals, using $`a \vee (a \wedge b) = a`$ to show $`a \wedge b \preceq a`$. ∎

> **Consequence for `llattice`.** This is why the docs sometimes speak of $`\preceq`$ and sometimes of $`\vee`$/$`\wedge`$: they
> are interchangeable. For `u32`, $`a \vee b = b`$ *is* $`\max(a,b) = b`$ *is* $`a \leq b`$. For `HashSet`, $`a \vee b = b`$ *is*
> $`a \cup b = b`$ *is* $`a \subseteq b`$.

---

## 4. The structure hierarchy

Demanding more of a lattice yields the specialised structures the built-in impls inhabit. Each is the previous
plus one axiom:

![Specialization hierarchy: poset → semilattice → lattice → bounded → complete / distributive → Boolean](figures/lattice-taxonomy.svg)

- **Bounded lattice** — has a $`\perp`$ and a $`\mathrm{top}`$. (Numeric types: `MIN`/`MAX`. `bool`: `false`/`true`.)
- **Complete lattice** — *every* subset, not just every pair, has a $`\vee`$ and $`\wedge`$. Finite lattices are
  automatically complete; $`\mathcal{P}(U)`$ is complete for any $`U`$. Completeness is what guarantees fixed points exist
  (Tarski; see [guides/04](../guides/04-fixpoints-and-analysis.md)).
- **Distributive lattice** — $`\wedge`$ distributes over $`\vee`$: $`a \wedge (b \vee c) = (a \wedge b) \vee (a \wedge c)`$. Chains and power
  sets are distributive.
- **Boolean lattice** — bounded, distributive, and **complemented**: every $`a`$ has $`\neg a`$ with $`a \vee \neg a = \mathrm{top}`$ and
  $`a \wedge \neg a = \perp`$. `bool` and $`\mathcal{P}(U)`$ are Boolean.

### Atoms, coatoms, and `2^U`

An **atom** covers $`\perp`$; a **coatom** is covered by $`\mathrm{top}`$. In $`\mathcal{P}(\{1,2,3\})`$ the singletons are the atoms. A finite
Boolean lattice is determined by its atoms: it is isomorphic to the power set of its atom set, equivalently to a
product of copies of $`\mathbf{2}`$:

```math
\mathcal{P}(U) \;\cong\; 2^U \;\cong\; (\text{a } U\text{-indexed tuple of bits})
```

This single isomorphism unifies three of the built-in impls — `bool` is the factor $`\mathbf{2}`$, a version vector is the
product $`2^U`$, and `HashSet` is the power set $`\mathcal{P}(U)`$:

![Isomorphism 𝒫(U) ≅ 2^U linking bool, version vectors, and HashSet](figures/powerset-iso.svg)

---

## 5. Distributivity and the two forbidden sublattices

Distributivity is *not* automatic — and there is a beautiful structural test for it. **Birkhoff's criterion**:
a lattice is distributive **if and only if** it contains neither the *diamond* $`M_3`$ nor the *pentagon* $`N_5`$ as a
sublattice.

![The forbidden sublattices M₃ (diamond) and N₅ (pentagon)](figures/m3-n5.svg)

- $`M_3`$ (the diamond) is **modular** but not distributive — it is the lattice of a 2-dimensional vector space's
  subspaces in miniature.
- $`N_5`$ (the pentagon) is not even modular.

Why this matters here: the integer, Boolean, and hash-set instances are
distributive, and we can now say *why* — numeric types are chains (a chain
contains neither $`M_3`$ nor $`N_5`$, since both require incomparable elements),
and $`\mathcal{P}(U)`$ is a power set (Boolean $`\implies`$ distributive). An
`Option<T>` lift inherits this property only when `T` has it. The `Lattice`
trait itself, however,
imposes **no** distributivity, so a *user* impl may be non-distributive; the documentation never assumes
distributivity of arbitrary `Lattice` types.

---

## 6. Where to go next

The laws and structures are in place. The next document connects each built-in
to executable and formal evidence, then uses raw float and sequence
counterexamples to explain why conditional instances are not exposed.

→ **[03 — Lawfulness and proofs](03-lawfulness-and-proofs.md)**

---

## References

1. Davey, B. A., & Priestley, H. A. (2002). *Introduction to Lattices and Order* (2nd ed.). Cambridge
   University Press. <https://doi.org/10.1017/CBO9780511809088> — §2.4–2.10 (lattices as algebras, the connecting
   lemma); §4.10 (the $`M_3`$–$`N_5`$ theorem).
2. Birkhoff, G. (1967). *Lattice Theory* (3rd ed.). AMS Colloquium Publications, Vol. 25.
   <https://doi.org/10.1090/coll/025> — Chapters I–II.
3. Tarski, A. (1955). A lattice-theoretical fixpoint theorem and its applications. *Pacific Journal of
   Mathematics*, 5(2), 285–309. <https://doi.org/10.2140/pjm.1955.5.285> — completeness $`\implies`$ fixed points.
