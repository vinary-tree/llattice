# ADR-0002 — The semiring ↔ lattice bridge lives in `lling-llang`, not `llattice`

- **Status:** Accepted
- **Date:** 2026-06
- **Deciders:** `vinary-tree` maintainers
- **Related:** [theory/04 — semiring bridge](../../theory/04-semiring-bridge.md), [ADR-0001](0001-extract-llattice-leaf-crate.md)

---

## Context

Every **idempotent semiring** (dioid) `(S, ⊕, ⊗, 0̄, 1̄)` carries a join-semilattice for free: its addition `⊕`
is commutative, associative, and idempotent, so it *is* a `join`, with natural order `a ⊑ b ⟺ a ⊕ b = b` and
least element `0̄` (proved in [theory/04 §2](../../theory/04-semiring-bridge.md#2-every-idempotent-semiring-carries-a-join-semilattice--for-free)).
It is therefore tempting to provide, *in `llattice`*, a blanket `impl<S: IdempotentSemiring> Lattice for S`.

Two forces push against putting it here:

1. **The leaf invariant.** `llattice` must stay dependency-free and vocabulary-only ([ADR-0001](0001-extract-llattice-leaf-crate.md)).
   Hosting the bridge would require `llattice` to know about semiring types, bloating the leaf.
2. **The `⊗`/`⊓` category error.** A semiring's multiplication `⊗` is **path composition**, *not* lattice meet
   (`⊗` is generally non-idempotent and may be non-commutative). Code that defines the bridge must understand
   this so it never wires `⊗` to `meet`. That understanding belongs with the semiring types.

There is also a hard constraint: the **orphan rule**. The blanket impl `impl<S: IdempotentSemiring> Lattice for S`
is legal only in a crate that owns `IdempotentSemiring` (or `Lattice`). `IdempotentSemiring` is owned by
`lling-llang`.

## Decision

**The semiring↔lattice bridge lives in `lling-llang`.** `lling-llang` owns `trait IdempotentSemiring`, defines
the dioid instances (tropical, max-plus, Viterbi, Boolean), and provides
`impl<S: IdempotentSemiring> Lattice for S` that exposes `⊕` as `join`. `llattice` knows nothing about
semirings.

## Consequences

**Positive**

- **`llattice` stays a pure leaf** — zero dependencies, vocabulary only.
- **The category error is unrepresentable in `llattice`.** With no `⊗` in scope, no one can accidentally bind
  `⊗` to `meet` here; the dangerous identification can only be written where `⊗` lives, under code that knows
  it is path composition.
- **Orphan-rule-correct by construction.** `lling-llang` owns `IdempotentSemiring`, so the blanket impl is
  legal exactly there and nowhere else.
- **Separation of concerns.** Consumers who want lattices without semirings (CRDTs, dataflow) depend only on
  `llattice`; those who want weighted automata get the bridge from `lling-llang`.

**Negative / costs**

- **The bridge is "remote" from the trait it targets.** A reader must follow a link from `llattice` to
  `lling-llang` to see the semiring impl. Mitigated by [theory/04](../../theory/04-semiring-bridge.md) documenting
  the relationship explicitly.

## Alternatives considered

- **Blanket impl in `llattice`.** Rejected: violates the leaf invariant *and* is orphan-rule-illegal
  (`llattice` does not own `IdempotentSemiring`).
- **A third "bridge" crate depending on both.** Rejected as unnecessary indirection: `lling-llang` already owns
  the semiring side and may legally host the impl, so a separate crate adds a dependency and a publish target
  for no benefit.
- **Identify `⊗` with `meet`.** Rejected — a category error that would corrupt every shortest-path / weighted-
  automaton computation (see [theory/04 §3](../../theory/04-semiring-bridge.md#3-why-multiplication-is-not-meet)).
