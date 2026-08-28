# Quickstart

## 1. Add the leaf dependency

```toml
[dependencies]
llattice = "0.2"
```

`llattice` has no runtime dependencies. Import the operations an algorithm
uses, or use the prelude.

```rust
use llattice::{Bottom, JoinSemilattice, MeetSemilattice};

assert_eq!(3_u32.join(&7), 7);
assert_eq!(3_u32.meet(&7), 3);
assert_eq!(u32::bottom(), 0);
assert!(3_u32.leq(&7));
```

## 2. Prefer in-place join in a worklist

`join_assign` both updates the accumulator and reports whether new information
arrived:

```rust
use llattice::JoinSemilattice;
use std::collections::HashSet;

let mut reached: HashSet<&str> = ["entry"].into_iter().collect();
assert!(reached.join_assign(&["left", "right"].into_iter().collect()));
assert!(!reached.join_assign(&["left"].into_iter().collect()));
```

Use the returned flag to enqueue downstream work. Do not clone and compare the
entire value again.

## 3. Use only the capability the domain owns

```rust
use llattice::JoinSemilattice;

fn merge_all<T>(mut accumulator: T, incoming: impl IntoIterator<Item = T>) -> T
where
    T: JoinSemilattice,
{
    for value in incoming {
        accumulator.join_assign(&value);
    }
    accumulator
}

assert_eq!(merge_all(0_u32, [4, 2, 9]), 9);
```

The bound does not demand meet, bottom, or thread safety. A parallel variant
adds `Send + Sync` at its scheduler boundary.

## 4. Lift optional information

```rust
use llattice::{Bottom, JoinSemilattice, MeetSemilattice};

let absent: Option<u32> = Bottom::bottom();
assert_eq!(absent.join(&Some(5)), Some(5));
assert_eq!(Some(5).join(&Some(3)), Some(5));
assert_eq!(Some(5).meet(&None), None);
```

`Option<T>` exposes only the capabilities that `T` exposes, while `None` is a
fresh bottom for every join-semilattice `T`.

## 5. Avoid the excluded raw domains

Raw floats and raw vectors intentionally have no implementation. Validate
floats into a no-`NaN` newtype. Represent mathematical sets with `HashSet`, or
create a canonical sequence wrapper whose equality agrees with its join.

Continue with [implementing the traits](02-implementing-lattice.md).
