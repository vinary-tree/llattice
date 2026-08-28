# CRDT cookbook

A state-based **Convergent Replicated Data Type** (CvRDT) merges replica states
with a join-semilattice. Idempotency tolerates replay, commutativity tolerates
arrival order, and associativity tolerates batching.

![Replicas converge under reordered joins](figures/crdt-convergence.svg)

## 1. Grow-only set

`HashSet` is the canonical grow-only set state:

```rust
use llattice::{Bottom, JoinSemilattice};
use std::collections::HashSet;

let mut replica: HashSet<&str> = Bottom::bottom();
assert!(replica.join_assign(&["alice"].into_iter().collect()));
assert!(replica.join_assign(&["bob", "carol"].into_iter().collect()));
assert!(!replica.join_assign(&["alice"].into_iter().collect()));
assert_eq!(replica, ["alice", "bob", "carol"].into_iter().collect());
```

The exact change flag is directly usable as “broadcast/enqueue dependents.”

## 2. Fixed-replica grow-only counter

Each replica owns one component. Merge takes componentwise maximum; the visible
count is the sum.

```rust
use llattice::{Bottom, JoinSemilattice};

#[derive(Clone, Debug, PartialEq)]
struct GCounter<const N: usize>([u64; N]);

impl<const N: usize> JoinSemilattice for GCounter<N> {
    fn join_assign(&mut self, other: &Self) -> bool {
        let mut changed = false;
        for (current, incoming) in self.0.iter_mut().zip(other.0) {
            if *current < incoming {
                *current = incoming;
                changed = true;
            }
        }
        changed
    }
}

impl<const N: usize> Bottom for GCounter<N> {
    fn bottom() -> Self {
        Self([0; N])
    }
}

impl<const N: usize> GCounter<N> {
    fn value(&self) -> u64 {
        self.0.iter().sum()
    }
}

let mut state = GCounter([2, 0, 0]);
assert!(state.join_assign(&GCounter([1, 3, 0])));
assert_eq!(state, GCounter([2, 3, 0]));
assert_eq!(state.value(), 5);
```

The loop is iterative. `changed` is assigned inside the loop rather than used
as a short-circuiting OR, because every component must still be merged.

## 3. Positive/negative counter

A PN-counter is the product of two grow-only counters. Its value is positive
minus negative counts.

```rust
use llattice::JoinSemilattice;

# #[derive(Clone, Debug, PartialEq)] struct GCounter<const N: usize>([u64; N]);
# impl<const N: usize> JoinSemilattice for GCounter<N> {
#   fn join_assign(&mut self, other: &Self) -> bool {
#     let mut changed=false; for (a,b) in self.0.iter_mut().zip(other.0) { if *a < b { *a=b; changed=true; } } changed
#   }
# }
#[derive(Clone, Debug, PartialEq)]
struct PNCounter<const N: usize> {
    positive: GCounter<N>,
    negative: GCounter<N>,
}

impl<const N: usize> JoinSemilattice for PNCounter<N> {
    fn join_assign(&mut self, other: &Self) -> bool {
        let positive_changed = self.positive.join_assign(&other.positive);
        let negative_changed = self.negative.join_assign(&other.negative);
        positive_changed | negative_changed
    }
}

let left = PNCounter { positive: GCounter([2, 0]), negative: GCounter([0, 1]) };
let right = PNCounter { positive: GCounter([1, 3]), negative: GCounter([0, 0]) };
assert_eq!(left.join(&right).positive, GCounter([2, 3]));
```

## 4. Last-writer-wins register

A total deterministic key is essential. Timestamp alone is insufficient when
two writers can tie. This example orders by timestamp, writer identifier, then
payload:

```rust
use llattice::JoinSemilattice;

#[derive(Clone, Debug, PartialEq, Eq, PartialOrd, Ord)]
struct Lww {
    timestamp: u64,
    writer: u64,
    value: String,
}

impl JoinSemilattice for Lww {
    fn join_assign(&mut self, other: &Self) -> bool {
        if *self < *other {
            *self = other.clone();
            true
        } else {
            false
        }
    }
}

let a = Lww { timestamp: 7, writer: 1, value: "alice".into() };
let b = Lww { timestamp: 7, writer: 2, value: "bob".into() };
assert_eq!(a.join(&b).value, "bob");
assert_eq!(b.join(&a).value, "bob");
```

## 5. Parallel replica processing

The algebra itself does not require thread safety. A parallel service adds it
at the transport or scheduler boundary:

```rust
use llattice::JoinSemilattice;

fn merge_worker_state<T>(mut local: T, remote: &T) -> T
where
    T: JoinSemilattice + Send + Sync,
{
    local.join_assign(remote);
    local
}

assert_eq!(merge_worker_state(3_u64, &9), 9);
```

Parallel reduction remains deterministic because the law makes result value
independent of grouping and ordering. Side effects surrounding the merge must
be scheduled separately from the pure algebra.

## 6. Validation checklist

- State updates move upward under `leq`.
- Merge is `join`, never an arbitrary conflict resolver.
- The representation has structural equality matching the mathematical value.
- `join_assign` merges every component and reports exact change.
- Replica identifiers and tie-breakers make ordering total where required.
- Input-sized traversals are iterative and heap-backed.
- Network and scheduler APIs add their own `Send + Sync` bounds.

The CvRDT convergence result is developed by Shapiro et al.,
[https://doi.org/10.1007/978-3-642-24550-3_29](https://doi.org/10.1007/978-3-642-24550-3_29).
