# Lawfulness, refinement, and proof evidence

## 1. What a trait bound promises

A `JoinSemilattice` bound means join is idempotent, commutative, and
associative under the type's Rust `PartialEq`. It also means `join_assign`
refines `join` with an exact change flag, and `leq` is the join-derived partial
order. There are no hidden “except `NaN`” or “up to another equality” clauses.

`MeetSemilattice` promises the dual three laws. `Lattice` promises both and the
two absorption laws. `Bottom` promises a context-free join identity and least
element.

## 2. Lawfulness matrix

| Rust domain | Join laws | Meet laws | Absorption | Bottom | Public capability |
|---|---:|---:|---:|---:|---|
| integer primitives | yes | yes | yes | `MIN` | all four traits |
| `bool` | yes | yes | yes | `false` | all four traits |
| `Option<T>` | when `T` has join | when `T` has meet | when `T: Lattice` | `None` | capability-preserving lift |
| `HashSet<T, S>` | yes | yes | yes | when `S: Default` | join, meet, lattice; conditional bottom |
| raw `f32`/`f64` | no: `NaN` | no: `NaN` | not applicable | not exposed | no implementation |
| raw `Vec<T>` | no: order bias | no: order bias | not applicable | not exposed | no implementation |

![Lawful v2 capabilities and excluded raw candidates](figures/lawfulness-matrix.svg)

The generic rows are parametric. `Option<T>` cannot improve a broken inner
algebra. The Rust bounds ensure only the available capability is lifted.

## 3. The derived order proof

Define:

```math
a \preceq b \quad:\Longleftrightarrow\quad a \vee b = b
```

Idempotency proves reflexivity. Commutativity proves antisymmetry together with
the two order hypotheses. Associativity proves transitivity. Rocq theorem
`join_leq_is_partial_order` checks these derivations without axioms.

An optimized `leq` override must agree with this definition. The public law
harness checks the bridge before checking reflexivity, transitivity, and
antisymmetry over each supplied sample triple.

## 4. In-place refinement

Let $`u = a \vee b`$. The required result of `a.join_assign(b)` is:

```math
\text{stored value} = u
\qquad
\text{returned flag} = (a \neq u)
```

Rocq definitions `join_assign_model`, `join_assign_returns_join`, and
`join_assign_changed_iff` establish this abstract contract. The executable
harness clones the before-value, invokes `join_assign`, and independently
checks both the stored result and flag.

For `HashSet`, union never removes elements. Therefore the implementation may
compare cardinalities before and after extension: the cardinality changes if
and only if the set's structural value changes.

## 5. Absorption is independent evidence

Two lawful semilattice operations do not automatically form a lattice. Set
both candidate operations to Boolean OR. They are each idempotent, commutative,
and associative, but:

```math
\text{false} \mathbin{\mathrm{OR}}
(\text{false} \mathbin{\mathrm{OR}} \text{true})
= \text{true} \neq \text{false}
```

Rocq theorem `two_semilattices_need_not_form_lattice` and Rust test
`law_harness_rejects_nonabsorbing_operations` share this countermodel. This is
why `Lattice` is an explicit marker rather than a blanket implementation.

## 6. The `Option` lift

`None` is adjoined below every inner value. When both operands are `Some`, the
inner operation is used; otherwise join keeps the present value and meet
returns `None` unless both are present.

The Rocq file proves join and meet idempotency, commutativity, associativity,
both absorption laws, and `None` as join identity. Property tests apply the
public harness to generated `Option<i64>` triples. Thus the formal model,
generic Rust implementation, and executable samples describe the same lift.

![Option adjoins a fresh bottom](figures/option-lift.svg)

## 7. Why raw floats are excluded

For the candidate `join = f64::max`, `NaN` creates two failures:

1. `NaN != NaN`, so structural idempotency cannot be stated as equality.
2. `NaN.partial_cmp(x)` is `None`, so the carrier is not a poset under the
   intended order.

Rust `max` also drops a one-sided `NaN`. The Rocq model represents finite
values and a `NaN` token, models Rust's NaN-dropping maximum, and proves
`nan_breaks_idempotency` under IEEE equality.

A wrapper whose constructor rejects `NaN` changes the carrier to a lawful
subset and may implement the traits. That validation must be represented by
the type; a comment at a raw-float call site is insufficient.

## 8. Why raw sequences are excluded

An order-preserving union is left biased:

```math
[\text{false}] \vee [\text{true}]
= [\text{false},\text{true}]
\neq
[\text{true},\text{false}]
= [\text{true}] \vee [\text{false}]
```

Rocq theorem `raw_sequence_join_is_not_commutative` evaluates this witness.
Content equality could quotient away order, but Rust `Vec::eq` does not. A
canonical sorted/deduplicated newtype or a set representation makes the chosen
equality explicit and can implement the traits lawfully.

## 9. Stack-safety refinement

Collection operations refine an explicit state machine whose state is a pending
sequence plus accumulator. `explicit_worklist_progress` proves that every
successful step strictly decreases pending length and that the machine halts
exactly when pending is empty.

The theorem proves termination of the abstract iterative schedule. Source
structure and a 64 KiB-stack test provide the Rust refinement evidence: all
input-sized work is performed by loops over heap-backed hash tables, not by
native recursion. A PDA is unnecessary because union and intersection do not
have a nested-language stack discipline.

## 10. Traceability ladder

[`proofs/doc/lattice-invariants.tsv`](../../proofs/doc/lattice-invariants.tsv)
is the join key across evidence:

Each law identifier maps to exactly three evidence classes:

- its Rocq theorem;
- its Rust property, countermodel, or stack test;
- its verification command.

The formal driver rejects unchecked proof escapes, rebuilds every proof, checks
the exact number of closed `Print Assumptions` reports, and validates every
registry path, theorem, test, hook, and gate. The current registry contains 13
consistent obligations.

Executable tests establish implementation correspondence over exhaustive or
generated samples; Rocq establishes the abstract theorems for arbitrary values
under explicit hypotheses. Neither is silently substituted for the other.

## References

1. Birkhoff, G. *Lattice Theory*, 3rd ed. American Mathematical Society, 1967.
   [https://doi.org/10.1090/coll/025](https://doi.org/10.1090/coll/025)
2. Davey, B. A., and Priestley, H. A. *Introduction to Lattices and Order*, 2nd
   ed. Cambridge University Press, 2002.
   [https://doi.org/10.1017/CBO9780511809088](https://doi.org/10.1017/CBO9780511809088)
3. Claessen, K., and Hughes, J. “QuickCheck: A Lightweight Tool for Random
   Testing of Haskell Programs.” ICFP 2000.
   [https://doi.org/10.1145/351240.351266](https://doi.org/10.1145/351240.351266)
