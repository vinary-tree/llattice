# Public semantics

## 1. Equality and change

The traits use Rust `PartialEq` as their observable equality. If
`before.join_assign(incoming)` returns `changed`, then:

```math
\text{after} = \text{before} \vee \text{incoming}
```

and `changed` is equivalent to `after != before`. Implementors may specialize
storage, hashing, vector instructions, or representation, but may not weaken
this result.

## 2. Trait-level behavior

| Trait | Required operation | Laws | Derived/default behavior |
|---|---|---|---|
| `JoinSemilattice` | `join_assign` | idempotent, commutative, associative join | `join`, `leq` |
| `MeetSemilattice` | `meet` | idempotent, commutative, associative meet | none |
| `Lattice` | explicit marker | both semilattices plus absorption | none |
| `Bottom` | `bottom` | join identity and leastness | none |

`leq` means the join-derived order, not an arbitrary comparison:
$`a.\mathrm{leq}(b) \iff a.\mathrm{join}(b) = b`$.

## 3. Built-in domains

| Domain | Order | Join | Meet | Bottom |
|---|---|---|---|---|
| unsigned integers | numeric $`\leq`$ | `max` | `min` | `0` |
| signed integers | numeric $`\leq`$ | `max` | `min` | type `MIN` |
| `bool` | `false` below `true` | OR | AND | `false` |
| `Option<T>` | `None` below every `Some`; inner order within `Some` | lifted join | lifted meet | `None` |
| `HashSet<T, S>` | subset | union | intersection | empty when `S: Default` |

The `Option` lift is exact:

```text
JOIN_OPTION(left, right):
    if both are Some: return Some(join(inner_left, inner_right))
    if exactly one is Some: return that value
    otherwise: return None

MEET_OPTION(left, right):
    if both are Some: return Some(meet(inner_left, inner_right))
    otherwise: return None
```

The implementation delegates `Some/Some` join to `T::join`, preserving any
specialized inner allocation strategy.

## 4. Hash-set algorithms

Let $`n`$ and $`m`$ be operand sizes. Hash operations are expected constant time
under a suitable build hasher.

Owned join chooses the larger table as the clone source:

```text
JOIN_SET(left, right):
    larger, smaller ← operands ordered by length
    result ← clone(larger)
    for each value in smaller:
        insert clone(value) into result
    return result
```

This is expected $`\Theta(n+m)`$ and avoids rebuilding the larger hash table
element by element. In-place join extends the existing accumulator and detects
change by its cardinality increase. Since union only adds elements, cardinality
change is equivalent to structural change.

Meet iterates the smaller input and clones only retained values:

```text
MEET_SET(left, right):
    smaller, larger ← operands ordered by length
    result ← empty set using clone(smaller.hasher)
    for each value in smaller:
        if larger contains value:
            insert clone(value) into result
    return result
```

The expected time is $`\Theta(\min(n,m))`$ lookups plus output construction.
The algorithms preserve the chosen build-hasher type and require no recursion.

## 5. Excluded raw domains

`f32` and `f64` do not implement the traits. `NaN != NaN`, and `NaN` is
incomparable under `partial_cmp`; therefore structural idempotency and the
partial-order bridge cannot hold for every value. A validated wrapper whose
constructor rejects `NaN` may lawfully implement the traits.

`Vec<T>` does not implement the traits. For left-biased order-preserving union:

```text
[false] join [true] = [false, true]
[true]  join [false] = [true, false]
```

The results have the same contents but are unequal `Vec` values. A canonical
sorted/deduplicated newtype can establish structural equality; raw `Vec` cannot.

## 6. Failure and resource behavior

Built-ins contain no `unsafe`, explicit recursion, indexing, integer arithmetic
that can overflow, or `unwrap`. Allocation failure and a user-provided hasher's
own behavior remain environmental. Adversarial hashing can degrade expected
complexity; callers choose `S` according to their trust boundary.

`Bottom::bottom` is offered only when construction is context-free. For a
custom hash builder without `Default`, the empty mathematical set still exists,
but the Rust value needs a supplied hasher and therefore has no `Bottom` impl.

## 7. Concurrency behavior

The algebra makes no thread-safety claim. `HashSet<T, S>` becomes `Send` and/or
`Sync` according to its element and hasher, as ordinary Rust auto-traits
determine. Parallel consumers state those bounds explicitly. This separates
semantic lawfulness from runtime placement without changing either.
