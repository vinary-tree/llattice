# Order Theory — the ground floor

> **Audience.** Anyone who wants to understand *why* `join`/`meet` behave the way they do. No prior
> order theory is assumed; every symbol is defined in the [glossary](../GLOSSARY.md) and on first use here.
>
> **Where this sits.** This document builds the partial-order scaffolding. [Document 02](02-semilattices-lattices.md)
> adds the two operations and the laws; [document 03](03-lawfulness-and-proofs.md) checks which laws each
> built-in impl actually satisfies; [document 04](04-semiring-bridge.md) connects lattices to semirings.

---

## 1. Relations and partial orders

A **binary relation** $`R`$ on a set $`S`$ is a subset of $`S \times S`$; we write $`a \mathbin{R} b`$ for $`(a, b) \in R`$.
A **partial order** is a relation $`\preceq`$ that is

- **reflexive** — $`a \preceq a`$ for every $`a`$;
- **antisymmetric** — $`a \preceq b`$ and $`b \preceq a`$ together force $`a = b`$;
- **transitive** — $`a \preceq b`$ and $`b \preceq c`$ together give $`a \preceq c`$.

A set equipped with such a relation is a **partially ordered set**, or **poset**, written $`(S, \preceq)`$.
The word *partial* is the crux: unlike the familiar $`\leq`$ on numbers, two elements may be **incomparable** —
neither $`a \preceq b`$ nor $`b \preceq a`$ holds. We write $`a \prec b`$ for the **strict** part: $`a \preceq b`$ and $`a \neq b`$.

> **Intuition.** Read $`a \preceq b`$ as "$`a`$ approximates $`b`$", or "$`a`$ carries no more information than $`b`$".
> For sets, $`\{1\} \preceq \{1,2\}`$ because $`\{1\}`$ says strictly less than $`\{1,2\}`$. For `Option`, $`\text{None} \preceq \text{Some}(x)`$
> because "no value yet" carries less than "the value $`x`$".

The three poset axioms are exactly the contract every `JoinSemilattice` impl's induced order obeys — and they are
what make $`\vee`$/$`\wedge`$ well-defined (see [document 02 §3](02-semilattices-lattices.md#3-the-orderoperation-bridge)).

### Worked instances (the built-in impls as posets)

| Poset | Carrier | $`a \preceq b`$ means | Comparable? |
|-------|---------|---------------|-------------|
| numbers | `u32`, `i64`, … | $`a \leq b`$ | always (a *chain*) |
| `bool` | $`\{\text{false}, \text{true}\}`$ | $`a`$ implies $`b`$ ($`\text{false} \leq \text{true}`$) | always |
| sets | `HashSet<T>` | $`a \subseteq b`$ | only when one contains the other |
| lifted | `Option<T>` | $`\text{None} \preceq \text{anything}`$; $`\text{Some}(a) \preceq \text{Some}(b) \iff a \preceq b`$ | depends on `T` |

`HashSet` is the first genuinely *partial* example: $`\{1\}`$ and $`\{2\}`$ are incomparable — neither is a subset
of the other. That incomparability is the whole reason lattices are interesting; on a chain, $`\vee`$ and $`\wedge`$
collapse to $`\max`$ and $`\min`$.

---

## 2. Hasse diagrams and the covering relation

To *draw* a finite poset we use a **Hasse diagram**. Element $`b`$ **covers** $`a`$, written $`a \prec b`$, when
$`a \prec b`$ and there is no $`c`$ strictly between ($`a \prec c \prec b`$ for no $`c`$). A Hasse diagram places each element
as a node and draws an edge **upward** from $`a`$ to $`b`$ exactly when $`a \prec b`$. Transitive and reflexive edges
are omitted — they are recoverable by reading paths upward.

The canonical example is the power set of $`\{1, 2, 3\}`$ ordered by $`\subseteq`$:

![Hasse diagram of the powerset lattice of {1,2,3}](../diagrams/powerset-hasse.svg)

Reading the picture:

- $`\{\}`$ at the bottom is below everything ($`\perp`$); $`\{1,2,3\}`$ at the top is above everything ($`\mathrm{top}`$).
- The **singletons** $`\{1\}, \{2\}, \{3\}`$ are the **atoms** — they cover $`\perp`$.
- The **pairs** $`\{1,2\}, \{1,3\}, \{2,3\}`$ are the **coatoms** — they are covered by $`\mathrm{top}`$.
- Moving **up** an edge adds an element ($`\subseteq`$ grows); moving **down** removes one.

This single diagram is also the geometry of `HashSet<i32>`: climbing toward $`\mathrm{top}`$ is `join` $`= \cup`$, descending
toward $`\perp`$ is `meet` $`= \cap`$. We return to it throughout the documentation.

---

## 3. Special elements: bounds, top, and bottom

Within a poset $`(S, \preceq)`$ and a subset $`X \subseteq S`$:

- $`u`$ is an **upper bound** of $`X`$ if $`x \preceq u`$ for every $`x \in X`$.
- $`\ell`$ is a **lower bound** of $`X`$ if $`\ell \preceq x`$ for every $`x \in X`$.
- The **least upper bound** (supremum, $`\vee X`$) is an upper bound below every other upper bound — *if it exists*.
- The **greatest lower bound** (infimum, $`\wedge X`$) is a lower bound above every other lower bound — *if it exists*.

When they exist for the whole carrier, the supremum of everything is the **top** $`\mathrm{top}`$ and the infimum of
everything is the **bottom** $`\perp`$:

```math
\perp \preceq x \preceq \mathrm{top} \qquad \text{for every element } x
```

> **Caution — existence is not guaranteed.** A bare poset need not have suprema. $`\{\, \{1\}, \{2\} \,\}`$ inside the
> *poset of all finite sets* has upper bound $`\{1,2\}`$, and it happens to be least — but in a poset that simply
> omitted $`\{1,2\}`$, the pair would have **no** least upper bound. A **lattice** is precisely a poset where the
> least upper bound and greatest lower bound of *every pair* are guaranteed to exist; that is the subject of
> [document 02](02-semilattices-lattices.md).

The built-in bounds:

| Type | $`\perp`$ | $`\mathrm{top}`$ |
|------|-----|-----|
| `u8 … u128`, `usize` | `MIN` (`0`) | `MAX` |
| `i8 … i128`, `isize` | `MIN` | `MAX` |
| `bool` | `false` | `true` |
| `HashSet<T>` | $`\{\}`$ | — (no greatest finite set; see [design/03](../design/03-semantics.md)) |
| `Option<T>` | `None` | $`\text{Some}(\mathrm{top}_T)`$ if `T` has a $`\mathrm{top}`$ |

Raw floats are absent: a validated no-`NaN` wrapper could model the extended-real
chain, but `f32`/`f64` themselves cannot satisfy the structural order. Note
`HashSet` has a $`\perp`$ but, at runtime over an unbounded element type, no $`\mathrm{top}`$ — a distinction that matters
for the structure classification in [document 03](03-lawfulness-and-proofs.md).

---

## 4. The duality principle

Every statement about posets has a **dual**, obtained by reversing $`\preceq`$ (swap $`\preceq`$ with $`\succeq`$, $`\vee`$ with $`\wedge`$,
$`\mathrm{top}`$ with $`\perp`$). If a statement holds in every poset, so does its dual — because reversing the order of a poset
yields another poset $`(S, \succeq)`$, called the **order dual** $`S^{\mathrm{op}}`$.

This is not a curiosity; it *halves the work*. Idempotency of $`\vee`$ and idempotency of $`\wedge`$ are duals, so one
proof yields both. The `join`/`meet` symmetry pervading `llattice` — and the `libdictenstein`/`duallity`
family name — is exactly this duality made into code: `meet` is `join` read upside-down.

```text
       statement                 dual statement
   a \preceq b  ⟺  a \vee b = b   ⟷   a \succeq b  ⟺  a \wedge b = b
        \perp is least        ⟷        \mathrm{top} is greatest
     atoms cover \perp        ⟷    coatoms covered by \mathrm{top}
```

---

## 5. Where to go next

You now have posets, Hasse diagrams, bounds, and duality. The next document promotes a poset to a **lattice**
by demanding that every pair has a $`\vee`$ and a $`\wedge`$, states the four laws those operations obey, and proves the
theorem that ties the order and the operations together.

→ **[02 — Semilattices and lattices](02-semilattices-lattices.md)**

---

## References

1. Davey, B. A., & Priestley, H. A. (2002). *Introduction to Lattices and Order* (2nd ed.). Cambridge
   University Press. <https://doi.org/10.1017/CBO9780511809088> — Chapters 1–2 (ordered sets, diagrams, duality).
2. Birkhoff, G. (1967). *Lattice Theory* (3rd ed.). American Mathematical Society Colloquium Publications,
   Vol. 25. [AMS Colloquium Publications 25](https://bookstore.ams.org/COLL/25), DOI: `10.1090/coll/025` —
   Chapter I (partly ordered sets).
