# Glossary

Every symbol, acronym, and key term used across the `llattice` documentation, defined once here and
linked from the other documents. Mathematical notation is written in GitHub-native MathJax (inline math
spans and ` ```math ` blocks); Rust identifiers — method and type names — stay in `code` spans.

> **Reading convention.** Where a Rust method and a mathematical operator coincide, both are given:
> e.g. `join` is the method, $`\sqcup`$ is the operator it computes.

---

## Core symbols

| Symbol | Name | Meaning |
|--------|------|---------|
| $`\sqsubseteq`$ | **partial order** ("approximates", "is below or equal") | The reflexive, antisymmetric, transitive relation of a poset. For numbers it is $`\leq`$; for `HashSet` it is $`\subseteq`$. |
| $`\sqsubset`$ | strict order | $`a \sqsubset b \iff (a \sqsubseteq b \;\land\; a \neq b)`$. |
| $`\sqcup`$ | **join** / least upper bound / supremum | The smallest element that is $`\sqsupseteq`$ both operands. Computed by the `join` method. For numbers, $`\max`$; for sets, $`\cup`$. |
| $`\sqcap`$ | **meet** / greatest lower bound / infimum | The largest element that is $`\sqsubseteq`$ both operands. Computed by the `meet` method. For numbers, $`\min`$; for sets, $`\cap`$. |
| $`\top`$ | **top** / greatest element | The element with $`x \sqsubseteq \top`$ for all $`x`$ (if it exists). |
| $`\bot`$ | **bottom** / least element | The element with $`\bot \sqsubseteq x`$ for all $`x`$ (if it exists). |
| $`\leq`$ | less-than-or-equal | The usual total order on numbers; the concrete $`\sqsubseteq`$ for the numeric impls. |
| $`\subseteq`$ | subset-or-equal | Set inclusion; the concrete $`\sqsubseteq`$ for `HashSet`. |
| $`\cup`$ | union | Set union; the concrete $`\sqcup`$ for `HashSet`. |
| $`\cap`$ | intersection | Set intersection; the concrete $`\sqcap`$ for `HashSet`. |
| $`\in`$ | membership | $`x \in S`$ means $`x`$ is an element of the set $`S`$. |
| $`\mathcal{P}(U)`$ | power set of $`U`$ | The set of all subsets of a universe $`U`$, ordered by $`\subseteq`$. |
| $`\oplus`$ | semiring addition | The additive operation of a semiring; in an *idempotent* semiring it is a $`\sqcup`$. |
| $`\otimes`$ | semiring multiplication | The multiplicative operation of a semiring; generally **path composition**, *not* $`\sqcap`$. |
| $`\bar{0}`$ | semiring zero | Additive identity / multiplicative annihilator of a semiring. |
| $`\bar{1}`$ | semiring one | Multiplicative identity of a semiring. |
| $`\infty`$ | infinity | $`\pm\infty`$ are the bottom/top of the float lattice on the extended reals $`[-\infty, +\infty]`$. |
| $`\cong`$ | isomorphic | Two structures related by a bijection that preserves the operations (e.g. $`\mathcal{P}(U) \cong 2^U`$). |
| $`\iff`$ | if and only if | Logical biconditional. |
| $`\implies`$ | implies | Logical implication. |
| $`f \circ g`$ | composition | $`(f \circ g)(x) = f(g(x))`$. |
| $`\operatorname{lfp} f`$ | least fixed point | The $`\sqsubseteq`$-least $`x`$ with $`f(x) = x`$. |
| $`\mathbf{2}`$ | the two-element lattice | $`(\{\text{false}, \text{true}\}, \leq)`$; the lattice `bool` realises. |
| $`2^U`$ | functions $`U \to \mathbf{2}`$ | The $`U`$-indexed product of $`\mathbf{2}`$; isomorphic to $`\mathcal{P}(U)`$. |

---

## Key terms

- **Poset (partially ordered set).** A set with a relation $`\sqsubseteq`$ that is reflexive ($`a \sqsubseteq a`$),
  antisymmetric ($`a \sqsubseteq b \;\land\; b \sqsubseteq a \implies a = b`$), and transitive
  ($`a \sqsubseteq b \;\land\; b \sqsubseteq c \implies a \sqsubseteq c`$). Not every pair need be comparable.

- **Chain.** A poset in which *every* pair is comparable (a total order). The numeric impls are chains.

- **Antichain.** A set of pairwise-incomparable elements.

- **Upper bound / lower bound.** $`u`$ is an upper bound of $`\{a, b\}`$ if $`a \sqsubseteq u`$ and
  $`b \sqsubseteq u`$; dually for a lower bound. The **least** upper bound is the `join`; the **greatest**
  lower bound is the `meet`.

- **Join-semilattice.** A poset in which every pair has a least upper bound ($`\sqcup`$).

- **Meet-semilattice.** A poset in which every pair has a greatest lower bound ($`\sqcap`$).

- **Lattice.** A poset that is both a join- and a meet-semilattice (every pair has both $`\sqcup`$ and $`\sqcap`$).

- **Bounded lattice.** A lattice with a $`\bot`$ and a $`\top`$.

- **Complete lattice.** A lattice in which *every* subset (not just every pair) has a $`\sqcup`$ and a $`\sqcap`$.

- **Distributive lattice.** A lattice where $`\sqcap`$ distributes over $`\sqcup`$ (equivalently $`\sqcup`$ over
  $`\sqcap`$): $`a \sqcap (b \sqcup c) = (a \sqcap b) \sqcup (a \sqcap c)`$.

- **Boolean lattice (Boolean algebra).** A bounded distributive lattice in which every element $`a`$ has a
  **complement** $`\lnot a`$ with $`a \sqcup \lnot a = \top`$ and $`a \sqcap \lnot a = \bot`$. `bool` and
  $`\mathcal{P}(U)`$ are Boolean lattices.

- **Atom / coatom.** An atom is an element covering $`\bot`$ (nothing strictly between); a coatom is covered by
  $`\top`$. In $`\mathcal{P}(\{1,2,3\})`$ the singletons are atoms and the pairs are coatoms.

- **Hasse diagram.** A drawing of a finite poset: nodes are elements, an edge goes upward from $`a`$ to $`b`$
  when $`b`$ *covers* $`a`$ ($`a \sqsubset b`$ with nothing strictly between). See [the powerset example](diagrams/powerset-hasse.svg).

- **Covering relation.** $`b`$ covers $`a`$ when $`a \sqsubset b`$ and no $`c`$ satisfies
  $`a \sqsubset c \sqsubset b`$. Hasse edges are exactly covers.

- **Idempotent / commutative / associative / absorption.** The four lattice laws — see
  [theory/02](theory/02-semilattices-lattices.md). Idempotent: $`a \sqcup a = a`$. Commutative:
  $`a \sqcup b = b \sqcup a`$. Associative: $`(a \sqcup b) \sqcup c = a \sqcup (b \sqcup c)`$. Absorption:
  $`a \sqcup (a \sqcap b) = a`$.

- **Lift (bottom adjunction), $`(\cdot)_\bot`$.** Adjoining a fresh $`\bot`$ below a lattice. `Option<T>` is the
  lift of `T` with `None` as the new bottom. See [option-lift](theory/figures/option-lift.svg).

- **Observational vs. structural equality.** A law may hold under one notion of equality but not another.
  The `Vec` impl satisfies commutativity under *content-equality* (same elements) but not under structural
  `Vec::==` (same elements in the same order). The `f64` impl satisfies idempotency on values but not under
  `==` when `NaN` is involved (`NaN == NaN` is `false`).

- **CvRDT (Convergent Replicated Data Type).** A replicated data type whose state lives in a join-semilattice
  and whose merge is $`\sqcup`$; replicas converge without coordination. See [guides/03](guides/03-crdt-cookbook.md).
  Acronym expands to **C**onvergent **R**eplicated **D**ata **T**ype (the "v" marks the state-based / convergent
  variant, vs. the operation-based CmRDT).

- **G-Set / LWW / version vector.** Specific CRDT designs built from lattices — grow-only set, last-writer-wins
  register, and the version vector (element-wise $`\max`$). Defined in [guides/03](guides/03-crdt-cookbook.md).

- **Monotone map.** $`f`$ with $`a \sqsubseteq b \implies f(a) \sqsubseteq f(b)`$. Monotone maps on complete
  lattices have least fixed points (Tarski). See [guides/04](guides/04-fixpoints-and-analysis.md).

- **Idempotent semiring (dioid).** A semiring $`(S, \oplus, \otimes, \bar{0}, \bar{1})`$ whose addition is
  idempotent ($`a \oplus a = a`$); its $`\oplus`$ is automatically a $`\sqcup`$. See [theory/04](theory/04-semiring-bridge.md).

- **Orphan rule (coherence).** Rust's rule that a trait impl must live in the crate defining the trait or the
  crate defining the type. The reason `Lattice` is a shared leaf crate. See [design/02](design/02-orphan-rule.md).

- **MSRV (Minimum Supported Rust Version).** The oldest Rust toolchain a crate compiles on. `llattice`'s MSRV
  is `1.70`.

- **NaN (Not a Number).** The IEEE-754 floating-point value that is unequal to everything including itself and
  is $`\leq`$-incomparable; it breaks the float lattice laws. See [the NaN failure modes](engineering/figures/nan-poison.svg).
