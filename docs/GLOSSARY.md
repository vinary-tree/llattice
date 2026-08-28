# Glossary

Every symbol, acronym, and key term used across the `llattice` documentation, defined once here and
linked from the other documents. Mathematical notation is written in GitHub-native MathJax (inline math
spans and ` ```math ` blocks); Rust identifiers — method and type names — stay in `code` spans.

> **Reading convention.** Where a Rust method and a mathematical operator coincide, both are given:
> e.g. `join` is the method, $`\vee`$ is the operator it computes.

---

## Core symbols

| Symbol | Name | Meaning |
|--------|------|---------|
| $`\preceq`$ | **partial order** ("approximates", "is below or equal") | The reflexive, antisymmetric, transitive relation of a poset. For numbers it is $`\leq`$; for `HashSet` it is $`\subseteq`$. |
| $`\prec`$ | strict order | $`a \prec b \iff (a \preceq b \;\land\; a \neq b)`$. |
| $`\vee`$ | **join** / least upper bound / supremum | The smallest element that is $`\succeq`$ both operands. Computed by the `join` method. For numbers, $`\max`$; for sets, $`\cup`$. |
| $`\wedge`$ | **meet** / greatest lower bound / infimum | The largest element that is $`\preceq`$ both operands. Computed by the `meet` method. For numbers, $`\min`$; for sets, $`\cap`$. |
| $`\mathrm{top}`$ | **top** / greatest element | The element with $`x \preceq \mathrm{top}`$ for all $`x`$ (if it exists). |
| $`\perp`$ | **bottom** / least element | The element with $`\perp \preceq x`$ for all $`x`$ (if it exists). |
| $`\leq`$ | less-than-or-equal | The usual total order on numbers; the concrete $`\preceq`$ for the numeric impls. |
| $`\subseteq`$ | subset-or-equal | Set inclusion; the concrete $`\preceq`$ for `HashSet`. |
| $`\cup`$ | union | Set union; the concrete $`\vee`$ for `HashSet`. |
| $`\cap`$ | intersection | Set intersection; the concrete $`\wedge`$ for `HashSet`. |
| $`\in`$ | membership | $`x \in S`$ means $`x`$ is an element of the set $`S`$. |
| $`\mathcal{P}(U)`$ | power set of $`U`$ | The set of all subsets of a universe $`U`$, ordered by $`\subseteq`$. |
| $`\oplus`$ | semiring addition | The additive operation of a semiring; in an *idempotent* semiring it is a $`\vee`$. |
| $`\otimes`$ | semiring multiplication | The multiplicative operation of a semiring; generally **path composition**, *not* $`\wedge`$. |
| $`\bar{0}`$ | semiring zero | Additive identity / multiplicative annihilator of a semiring. |
| $`\bar{1}`$ | semiring one | Multiplicative identity of a semiring. |
| $`\infty`$ | infinity | An unbounded mathematical value. Raw Rust floats do not implement the traits because `NaN` prevents a lawful structural order. |
| $`\cong`$ | isomorphic | Two structures related by a bijection that preserves the operations (e.g. $`\mathcal{P}(U) \cong 2^U`$). |
| $`\iff`$ | if and only if | Logical biconditional. |
| $`\implies`$ | implies | Logical implication. |
| $`f \circ g`$ | composition | $`(f \circ g)(x) = f(g(x))`$. |
| $`\mathrm{lfp} f`$ | least fixed point | The $`\preceq`$-least $`x`$ with $`f(x) = x`$. |
| $`\mathbf{2}`$ | the two-element lattice | $`(\{\text{false}, \text{true}\}, \leq)`$; the lattice `bool` realises. |
| $`2^U`$ | functions $`U \to \mathbf{2}`$ | The $`U`$-indexed product of $`\mathbf{2}`$; isomorphic to $`\mathcal{P}(U)`$. |

---

## Key terms

- **Poset (partially ordered set).** A set with a relation $`\preceq`$ that is reflexive ($`a \preceq a`$),
  antisymmetric ($`a \preceq b \;\land\; b \preceq a \implies a = b`$), and transitive
  ($`a \preceq b \;\land\; b \preceq c \implies a \preceq c`$). Not every pair need be comparable.

- **Chain.** A poset in which *every* pair is comparable (a total order). The numeric impls are chains.

- **Antichain.** A set of pairwise-incomparable elements.

- **Upper bound / lower bound.** $`u`$ is an upper bound of $`\{a, b\}`$ if $`a \preceq u`$ and
  $`b \preceq u`$; dually for a lower bound. The **least** upper bound is the `join`; the **greatest**
  lower bound is the `meet`.

- **Join-semilattice.** A poset in which every pair has a least upper bound ($`\vee`$).

- **In-place join.** `join_assign` updates an accumulator to its join and returns
  `true` exactly when its structural value changes. It refines `join`; it is not
  a different algebraic operation.

- **Meet-semilattice.** A poset in which every pair has a greatest lower bound ($`\wedge`$).

- **Lattice.** A poset that is both a join- and a meet-semilattice (every pair has both $`\vee`$ and $`\wedge`$).

- **Bounded lattice.** A lattice with a $`\perp`$ and a $`\mathrm{top}`$.

- **Complete lattice.** A lattice in which *every* subset (not just every pair) has a $`\vee`$ and a $`\wedge`$.

- **Distributive lattice.** A lattice where $`\wedge`$ distributes over $`\vee`$ (equivalently $`\vee`$ over
  $`\wedge`$): $`a \wedge (b \vee c) = (a \wedge b) \vee (a \wedge c)`$.

- **Boolean lattice (Boolean algebra).** A bounded distributive lattice in which every element $`a`$ has a
  **complement** $`\neg a`$ with $`a \vee \neg a = \mathrm{top}`$ and $`a \wedge \neg a = \perp`$. `bool` and
  $`\mathcal{P}(U)`$ are Boolean lattices.

- **Atom / coatom.** An atom is an element covering $`\perp`$ (nothing strictly between); a coatom is covered by
  $`\mathrm{top}`$. In $`\mathcal{P}(\{1,2,3\})`$ the singletons are atoms and the pairs are coatoms.

- **Hasse diagram.** A drawing of a finite poset: nodes are elements, an edge goes upward from $`a`$ to $`b`$
  when $`b`$ *covers* $`a`$ ($`a \prec b`$ with nothing strictly between). See [the powerset example](diagrams/powerset-hasse.svg).

- **Covering relation.** $`b`$ covers $`a`$ when $`a \prec b`$ and no $`c`$ satisfies
  $`a \prec c \prec b`$. Hasse edges are exactly covers.

- **Idempotent / commutative / associative / absorption.** The four lattice laws — see
  [theory/02](theory/02-semilattices-lattices.md). Idempotent: $`a \vee a = a`$. Commutative:
  $`a \vee b = b \vee a`$. Associative: $`(a \vee b) \vee c = a \vee (b \vee c)`$. Absorption:
  $`a \vee (a \wedge b) = a`$.

- **Lift (bottom adjunction), $`(\cdot)_\perp`$.** Adjoining a fresh $`\perp`$ below a lattice. `Option<T>` is the
  lift of `T` with `None` as the new bottom. See [option-lift](theory/figures/option-lift.svg).

- **Observational vs. structural equality.** A law may hold under one notion of
  equality but not another. The public traits use Rust `PartialEq` as their
  structural equality. Raw `Vec` and floating-point candidates therefore stay
  outside the built-in implementation set; a wrapper must make its intended
  quotient or validated subset part of the type.

- **CvRDT (Convergent Replicated Data Type).** A replicated data type whose state lives in a join-semilattice
  and whose merge is $`\vee`$; replicas converge without coordination. See [guides/03](guides/03-crdt-cookbook.md).
  Acronym expands to **C**onvergent **R**eplicated **D**ata **T**ype (the "v" marks the state-based / convergent
  variant, vs. the operation-based CmRDT).

- **G-Set / LWW / version vector.** Specific CRDT designs built from lattices — grow-only set, last-writer-wins
  register, and the version vector (element-wise $`\max`$). Defined in [guides/03](guides/03-crdt-cookbook.md).

- **Monotone map.** $`f`$ with $`a \preceq b \implies f(a) \preceq f(b)`$. Monotone maps on complete
  lattices have least fixed points (Tarski). See [guides/04](guides/04-fixpoints-and-analysis.md).

- **Idempotent semiring (dioid).** A semiring $`(S, \oplus, \otimes, \bar{0}, \bar{1})`$ whose addition is
  idempotent ($`a \oplus a = a`$); its $`\oplus`$ is automatically a $`\vee`$. See [theory/04](theory/04-semiring-bridge.md).

- **Orphan rule (coherence).** Rust's rule that a trait impl must live in the crate defining the trait or the
  crate defining the type. The reason the layered lattice traits live in a shared leaf crate. See [design/02](design/02-orphan-rule.md).

- **Native-stack safety.** Runtime input depth does not cause proportional
  native call-stack growth. `llattice` collection work is iterative and keeps
  input-sized state in heap-backed collections.

- **Pushdown automaton (PDA).** A finite controller with an explicit stack,
  suited to nested or context-free structure. A specialized iterative PDA is
  useful for parser and tree-language layers, but flat set union/intersection
  needs only an iterative collection machine.

- **MSRV (Minimum Supported Rust Version).** The oldest Rust toolchain a crate compiles on. `llattice`'s MSRV
  is `1.70`.

- **NaN (Not a Number).** The IEEE-754 floating-point value that is unequal to everything including itself and
  is $`\leq`$-incomparable; it breaks the float lattice laws. See [the NaN failure modes](engineering/figures/nan-poison.svg).
