# Glossary

Every symbol, acronym, and key term used across the `llattice` documentation, defined once here and
linked from the other documents. Mathematical symbols are written in Unicode and quoted in backticks.

> **Reading convention.** Where a Rust method and a mathematical operator coincide, both are given:
> e.g. `join` is the method, `⊔` is the operator it computes.

---

## Core symbols

| Symbol | Name | Meaning |
|--------|------|---------|
| `⊑` | **partial order** ("approximates", "is below or equal") | The reflexive, antisymmetric, transitive relation of a poset. For numbers it is `≤`; for `HashSet` it is `⊆`. |
| `⊏` | strict order | `a ⊏ b` ⟺ `a ⊑ b` and `a ≠ b`. |
| `⊔` | **join** / least upper bound / supremum | The smallest element that is `⊒` both operands. Computed by the `join` method. For numbers, `max`; for sets, `∪`. |
| `⊓` | **meet** / greatest lower bound / infimum | The largest element that is `⊑` both operands. Computed by the `meet` method. For numbers, `min`; for sets, `∩`. |
| `⊤` | **top** / greatest element | The element with `x ⊑ ⊤` for all `x` (if it exists). |
| `⊥` | **bottom** / least element | The element with `⊥ ⊑ x` for all `x` (if it exists). |
| `≤` | less-than-or-equal | The usual total order on numbers; the concrete `⊑` for the numeric impls. |
| `⊆` | subset-or-equal | Set inclusion; the concrete `⊑` for `HashSet`. |
| `∪` | union | Set union; the concrete `⊔` for `HashSet`. |
| `∩` | intersection | Set intersection; the concrete `⊓` for `HashSet`. |
| `∈` | membership | `x ∈ S` means `x` is an element of set `S`. |
| `𝒫(U)` | power set of `U` | The set of all subsets of a universe `U`, ordered by `⊆`. |
| `⊕` | semiring addition | The additive operation of a semiring; in an *idempotent* semiring it is a `⊔`. |
| `⊗` | semiring multiplication | The multiplicative operation of a semiring; generally **path composition**, *not* `⊓`. |
| `0̄` | semiring zero | Additive identity / multiplicative annihilator of a semiring. |
| `1̄` | semiring one | Multiplicative identity of a semiring. |
| `∞` | infinity | `±∞` are the bottom/top of the float lattice on the extended reals `[−∞, +∞]`. |
| `≅` | isomorphic | Two structures related by a bijection that preserves the operations (e.g. `𝒫(U) ≅ 2^U`). |
| `⟺` | if and only if | Logical biconditional. |
| `⟹` | implies | Logical implication. |
| `f ∘ g` | composition | `(f ∘ g)(x) = f(g(x))`. |
| `lfp f` | least fixed point | The `⊑`-least `x` with `f(x) = x`. |
| `2` | the two-element lattice | `({false, true}, ≤)`; the lattice `bool` realises. Also written `𝟚`. |
| `2^U` | functions `U → 2` | The `U`-indexed product of `2`; isomorphic to `𝒫(U)`. |

---

## Key terms

- **Poset (partially ordered set).** A set with a relation `⊑` that is reflexive (`a ⊑ a`), antisymmetric
  (`a ⊑ b` and `b ⊑ a` ⟹ `a = b`), and transitive (`a ⊑ b` and `b ⊑ c` ⟹ `a ⊑ c`). Not every pair need
  be comparable.

- **Chain.** A poset in which *every* pair is comparable (a total order). The numeric impls are chains.

- **Antichain.** A set of pairwise-incomparable elements.

- **Upper bound / lower bound.** `u` is an upper bound of `{a, b}` if `a ⊑ u` and `b ⊑ u`; dually for lower
  bound. The **least** upper bound is the `join`; the **greatest** lower bound is the `meet`.

- **Join-semilattice.** A poset in which every pair has a least upper bound (`⊔`).

- **Meet-semilattice.** A poset in which every pair has a greatest lower bound (`⊓`).

- **Lattice.** A poset that is both a join- and a meet-semilattice (every pair has both `⊔` and `⊓`).

- **Bounded lattice.** A lattice with a `⊥` and a `⊤`.

- **Complete lattice.** A lattice in which *every* subset (not just every pair) has a `⊔` and a `⊓`.

- **Distributive lattice.** A lattice where `⊓` distributes over `⊔` (equivalently `⊔` over `⊓`):
  `a ⊓ (b ⊔ c) = (a ⊓ b) ⊔ (a ⊓ c)`.

- **Boolean lattice (Boolean algebra).** A bounded distributive lattice in which every element `a` has a
  **complement** `¬a` with `a ⊔ ¬a = ⊤` and `a ⊓ ¬a = ⊥`. `bool` and `𝒫(U)` are Boolean lattices.

- **Atom / coatom.** An atom is an element covering `⊥` (nothing strictly between); a coatom is covered by
  `⊤`. In `𝒫({1,2,3})` the singletons are atoms and the pairs are coatoms.

- **Hasse diagram.** A drawing of a finite poset: nodes are elements, an edge goes upward from `a` to `b`
  when `b` *covers* `a` (`a ⊏ b` with nothing strictly between). See [the powerset example](diagrams/powerset-hasse.svg).

- **Covering relation.** `b` covers `a` when `a ⊏ b` and no `c` satisfies `a ⊏ c ⊏ b`. Hasse edges are exactly
  covers.

- **Idempotent / commutative / associative / absorption.** The four lattice laws — see
  [theory/02](theory/02-semilattices-lattices.md). Idempotent: `a ⊔ a = a`. Commutative: `a ⊔ b = b ⊔ a`.
  Associative: `(a ⊔ b) ⊔ c = a ⊔ (b ⊔ c)`. Absorption: `a ⊔ (a ⊓ b) = a`.

- **Lift (bottom adjunction), `(·)⊥`.** Adjoining a fresh `⊥` below a lattice. `Option<T>` is the lift of
  `T` with `None` as the new bottom. See [option-lift](theory/figures/option-lift.svg).

- **Observational vs. structural equality.** A law may hold under one notion of equality but not another.
  The `Vec` impl satisfies commutativity under *content-equality* (same elements) but not under structural
  `Vec::==` (same elements in the same order). The `f64` impl satisfies idempotency on values but not under
  `==` when `NaN` is involved (`NaN == NaN` is `false`).

- **CvRDT (Convergent Replicated Data Type).** A replicated data type whose state lives in a join-semilattice
  and whose merge is `⊔`; replicas converge without coordination. See [guides/03](guides/03-crdt-cookbook.md).
  Acronym expands to **C**onvergent **R**eplicated **D**ata **T**ype (the "v" marks the state-based / convergent
  variant, vs. the operation-based CmRDT).

- **G-Set / LWW / version vector.** Specific CRDT designs built from lattices — grow-only set, last-writer-wins
  register, and the version vector (element-wise `max`). Defined in [guides/03](guides/03-crdt-cookbook.md).

- **Monotone map.** `f` with `a ⊑ b ⟹ f(a) ⊑ f(b)`. Monotone maps on complete lattices have least fixed
  points (Tarski). See [guides/04](guides/04-fixpoints-and-analysis.md).

- **Idempotent semiring (dioid).** A semiring `(S, ⊕, ⊗, 0̄, 1̄)` whose addition is idempotent (`a ⊕ a = a`);
  its `⊕` is automatically a `⊔`. See [theory/04](theory/04-semiring-bridge.md).

- **Orphan rule (coherence).** Rust's rule that a trait impl must live in the crate defining the trait or the
  crate defining the type. The reason `Lattice` is a shared leaf crate. See [design/02](design/02-orphan-rule.md).

- **MSRV (Minimum Supported Rust Version).** The oldest Rust toolchain a crate compiles on. `llattice`'s MSRV
  is `1.70`.

- **NaN (Not a Number).** The IEEE-754 floating-point value that is unequal to everything including itself and
  is `≤`-incomparable; it breaks the float lattice laws. See [the NaN failure modes](engineering/figures/nan-poison.svg).
