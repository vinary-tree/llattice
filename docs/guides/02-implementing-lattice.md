# Implementing the layered traits

## 1. Start from the order

Before writing code, state what $`a \preceq b`$ means and which least upper
bound exists. If the domain has only monotone accumulation, implement only
`JoinSemilattice`.

```rust
use llattice::JoinSemilattice;

#[derive(Clone, Debug, PartialEq)]
struct Version(u64);

impl JoinSemilattice for Version {
    fn join_assign(&mut self, other: &Self) -> bool {
        if self.0 < other.0 {
            self.0 = other.0;
            true
        } else {
            false
        }
    }

    fn leq(&self, other: &Self) -> bool {
        self.0 <= other.0
    }
}

assert_eq!(Version(2).join(&Version(5)), Version(5));
```

The default `join` clones once and calls `join_assign`. Override `join` only
when an owned operation can choose a materially better strategy, such as
cloning the larger of two symmetric hash sets.

## 2. Make the change flag exact

The Boolean return is not “probably changed” and not “performed work.” It is:

```math
\mathrm{changed} \iff
(\mathrm{after} \neq \mathrm{before})
```

For an insert-only set, length change is exact. For a bitset, OR the words and
accumulate whether any word differs. For a scalar maximum, compare before
assigning. Never short-circuit a loop merely because one component changed;
the remaining components still need their joins.

## 3. Add meet and the marker separately

```rust
use llattice::{JoinSemilattice, Lattice, MeetSemilattice};

# #[derive(Clone, Debug, PartialEq)] struct Version(u64);
# impl JoinSemilattice for Version {
#   fn join_assign(&mut self, other: &Self) -> bool {
#     let changed = self.0 < other.0; self.0 = self.0.max(other.0); changed
#   }
# }
impl MeetSemilattice for Version {
    fn meet(&self, other: &Self) -> Self {
        Version(self.0.min(other.0))
    }
}

impl Lattice for Version {}
```

Write the marker only after establishing:

```math
a \vee (a \wedge b) = a
\qquad
a \wedge (a \vee b) = a
```

Having two semilattice implementations is insufficient evidence.

## 4. Add bottom only when construction is context-free

```rust
use llattice::{Bottom, JoinSemilattice};

# #[derive(Clone, Debug, PartialEq)] struct Version(u64);
# impl JoinSemilattice for Version {
#   fn join_assign(&mut self, other: &Self) -> bool {
#     let changed = self.0 < other.0; self.0 = self.0.max(other.0); changed
#   }
# }
impl Bottom for Version {
    fn bottom() -> Self {
        Version(0)
    }
}
```

If construction needs a universe, arena, comparator, or hash-builder instance,
do not implement context-free `Bottom`. Accept that context explicitly in the
owning application.

## 5. Reuse the law harness

```rust
use llattice::laws;

# use llattice::{Bottom, JoinSemilattice, Lattice, MeetSemilattice};
# #[derive(Clone, Debug, PartialEq)] struct Version(u64);
# impl JoinSemilattice for Version {
#   fn join_assign(&mut self, other: &Self) -> bool {
#     let changed = self.0 < other.0; self.0 = self.0.max(other.0); changed
#   }
# }
# impl MeetSemilattice for Version { fn meet(&self, other: &Self) -> Self { Version(self.0.min(other.0)) } }
# impl Lattice for Version {}
# impl Bottom for Version { fn bottom() -> Self { Version(0) } }
for a in 0..8 {
    for b in 0..8 {
        for c in 0..8 {
            laws::check_lattice(&Version(a), &Version(b), &Version(c)).unwrap();
        }
    }
    laws::check_bottom(&Version(a)).unwrap();
}
```

Use exhaustive tests for small finite carriers and property generators for
large carriers. The harness checks samples, so accompany critical generic
algebras with formal proofs or a mathematical derivation.

## 6. Preserve specialized performance

For hot domains:

1. keep scalar methods inline and allocation-free;
2. mutate owned buffers or tables in `join_assign`;
3. iterate the smaller side for symmetric intersection;
4. preserve custom allocators/hashers/representations;
5. avoid trait-object dispatch on monomorphized optimizer hot paths;
6. benchmark the same semantic operation before and after the change;
7. measure raw samples under fixed affinity, governor, and memory limits.

An array or bitset implementation may use explicit SIMD or rely on
auto-vectorization. It must produce the same structural value and exact change
flag as the scalar law model.

## 7. Keep input depth off the native stack

Flat product and collection joins should use loops. Recursive trees should use
an explicit heap-backed worklist. If the domain is a context-free tree language
or parser configuration, a specialized iterative pushdown automaton may be the
right machine; prove language equivalence and an explicit stack bound before
substituting it.

## 8. Add concurrency at the owner

```rust
use llattice::JoinSemilattice;

fn worker_domain<T: JoinSemilattice + Send + Sync>(value: T) {
    # let _ = value;
}

worker_domain(7_u32);
```

Do not add `Send + Sync` merely to satisfy the algebra. Add them where the value
crosses workers, and document the scheduler's determinism and merge order.
