//! `llattice` — a minimal lattice abstraction (`join` / `meet`).
//!
//! A **lattice** is a partially-ordered set with two operations:
//! - **join** — least upper bound / supremum (for sets: union; for numbers: max)
//! - **meet** — greatest lower bound / infimum (for sets: intersection; for numbers: min)
//!
//! This crate provides the [`Lattice`] trait plus built-in implementations for
//! the common cases (integers, floats, `bool`, `Option`, `HashSet`, `Vec`) so
//! that downstream crates can share one lattice vocabulary without re-deriving
//! it. It has no dependencies.
//!
//! # Examples
//!
//! ```rust
//! use llattice::Lattice;
//! use std::collections::HashSet;
//!
//! // HashSet: join = union, meet = intersection
//! let a: HashSet<i32> = [1, 2].into_iter().collect();
//! let b: HashSet<i32> = [2, 3].into_iter().collect();
//! assert_eq!(a.join(&b), [1, 2, 3].into_iter().collect());
//! assert_eq!(a.meet(&b), [2].into_iter().collect());
//!
//! // Numeric: join = max, meet = min
//! assert_eq!(5u32.join(&3), 5);
//! assert_eq!(5u32.meet(&3), 3);
//! ```

use std::collections::HashSet;
use std::hash::Hash;

/// A lattice provides join (least upper bound) and meet (greatest lower bound) operations.
///
/// A *lawful* lattice satisfies four laws — for all `a`, `b`, `c`:
/// - **Idempotency**: `a.join(a) == a` and `a.meet(a) == a`
/// - **Commutativity**: `a.join(b) == b.join(a)` and `a.meet(b) == b.meet(a)`
/// - **Associativity**: `(a.join(b)).join(c) == a.join(&b.join(c))` (same for meet)
/// - **Absorption**: `a.join(&a.meet(b)) == a` and `a.meet(&a.join(b)) == a`
///
/// The built-in impls satisfy all four **with two documented exceptions**:
/// - `f32`/`f64` are lawful only on the `NaN`-free values: a `NaN` breaks idempotency under `==`
///   (`NaN.join(&NaN)` is `NaN`, yet `NaN != NaN`) and the order (`NaN` is incomparable).
/// - `Vec<T>` is a *join-semilattice up to content-equality* — `join`/`meet` are left-biased in
///   ordering, so commutativity/associativity hold for the *set of elements*, not the `Vec` value:
///   `[1, 2].join(&[2, 1])` is `[1, 2]`, while `[2, 1].join(&[1, 2])` is `[2, 1]`.
///
/// See the lawfulness matrix and proofs in `docs/theory/03-lawfulness-and-proofs.md`.
///
/// # Panics
///
/// None of the built-in implementations panic: `join`/`meet` are total on every input (including
/// `NaN`, empty collections, and disjoint sets), contain no `unsafe`, and never `unwrap`/index/overflow.
///
/// # Use Cases
///
/// - **CRDT-style merges**: combine values from multiple sources commutatively and
///   associatively (e.g., merging sets, taking max/min).
/// - **Conflict-free replication**: lattice operations are the algebraic basis of CvRDTs.
///
/// # Relationship to Semirings
///
/// For idempotent semirings (where `a ⊕ a = a`), the `plus` operation forms a join
/// semilattice; `times` is generally path composition, not lattice meet. The bridge
/// from `IdempotentSemiring` to `Lattice` lives in the `lling-llang` crate, which owns
/// the semiring types.
///
/// # Examples
///
/// ```rust
/// use llattice::Lattice;
/// use std::collections::HashSet;
///
/// // HashSet: join = union, meet = intersection
/// let a: HashSet<i32> = [1, 2].into_iter().collect();
/// let b: HashSet<i32> = [2, 3].into_iter().collect();
///
/// let joined = a.join(&b);  // {1, 2, 3}
/// let met = a.meet(&b);     // {2}
///
/// assert_eq!(joined, [1, 2, 3].into_iter().collect());
/// assert_eq!(met, [2].into_iter().collect());
///
/// // Numeric: join = max, meet = min
/// assert_eq!(5u32.join(&3), 5);
/// assert_eq!(5u32.meet(&3), 3);
/// ```
pub trait Lattice: Clone + Send + Sync {
    /// Join operation (least upper bound / union / supremum).
    ///
    /// For sets, this is union. For numbers, this is max.
    fn join(&self, other: &Self) -> Self;

    /// Meet operation (greatest lower bound / intersection / infimum).
    ///
    /// For sets, this is intersection. For numbers, this is min.
    fn meet(&self, other: &Self) -> Self;
}

// =============================================================================
// Built-in Lattice Implementations
// =============================================================================

// Numeric types: join = max, meet = min
macro_rules! impl_lattice_for_numeric {
    ($($t:ty),+) => {
        $(
            impl Lattice for $t {
                #[inline]
                fn join(&self, other: &Self) -> Self {
                    (*self).max(*other)
                }

                #[inline]
                fn meet(&self, other: &Self) -> Self {
                    (*self).min(*other)
                }
            }
        )+
    };
}

impl_lattice_for_numeric!(u8, u16, u32, u64, u128, usize, i8, i16, i32, i64, i128, isize);

// f32: join = max, meet = min. Lawful only on NaN-free values: `f32::max(NaN, x) == x` silently
// drops NaN, and `NaN != NaN` breaks idempotency under `==`. See docs/theory/03 §6.
impl Lattice for f32 {
    #[inline]
    fn join(&self, other: &Self) -> Self {
        self.max(*other)
    }

    #[inline]
    fn meet(&self, other: &Self) -> Self {
        self.min(*other)
    }
}

// f64: join = max, meet = min. Lawful only on NaN-free values (see the f32 note above and docs/theory/03 §6).
impl Lattice for f64 {
    #[inline]
    fn join(&self, other: &Self) -> Self {
        self.max(*other)
    }

    #[inline]
    fn meet(&self, other: &Self) -> Self {
        self.min(*other)
    }
}

// bool: join = OR, meet = AND
impl Lattice for bool {
    #[inline]
    fn join(&self, other: &Self) -> Self {
        *self || *other
    }

    #[inline]
    fn meet(&self, other: &Self) -> Self {
        *self && *other
    }
}

// Option<T>: join = Some if either Some, meet = Some only if both Some
impl<T: Lattice> Lattice for Option<T> {
    #[inline]
    fn join(&self, other: &Self) -> Self {
        match (self, other) {
            (Some(a), Some(b)) => Some(a.join(b)),
            (Some(a), None) => Some(a.clone()),
            (None, Some(b)) => Some(b.clone()),
            (None, None) => None,
        }
    }

    #[inline]
    fn meet(&self, other: &Self) -> Self {
        match (self, other) {
            (Some(a), Some(b)) => Some(a.meet(b)),
            _ => None,
        }
    }
}

// HashSet<T>: join = union (∪), meet = intersection (∩); ⊥ = {}. A distributive lattice with bottom.
// (The mathematical powerset 𝒫(U) is a complete atomic Boolean algebra; this runtime type has no ⊤
// or complement over an unbounded element type.) See docs/theory/03 §4.
impl<T: Clone + Eq + Hash + Send + Sync> Lattice for HashSet<T> {
    fn join(&self, other: &Self) -> Self {
        self.union(other).cloned().collect()
    }

    fn meet(&self, other: &Self) -> Self {
        self.intersection(other).cloned().collect()
    }
}

// Vec<T>: a join-semilattice *up to content-equality*, NOT a full lattice on Vec values.
// join = concat + dedup (order-preserving, left-biased); meet = intersection in self's order.
// Left bias: [1,2].join(&[2,1]) == [1,2] != [2,1] == [2,1].join(&[1,2]). See docs/theory/03 §7.
impl<T: Clone + Eq + Send + Sync> Lattice for Vec<T> {
    fn join(&self, other: &Self) -> Self {
        let mut result = self.clone();
        for item in other {
            if !result.contains(item) {
                result.push(item.clone());
            }
        }
        result
    }

    fn meet(&self, other: &Self) -> Self {
        self.iter()
            .filter(|item| other.contains(item))
            .cloned()
            .collect()
    }
}

// =============================================================================
// Documentation doctests
// =============================================================================
//
// Compile and run every ```rust block in the README and the guides as part of `cargo test`, so
// every runnable example in this crate's documentation is verified on each test run. Gated on
// `cfg(doctest)` so these helper items never appear in `cargo doc` output.

#[cfg(doctest)]
#[doc = include_str!("../README.md")]
struct ReadmeDoctests;

#[cfg(doctest)]
#[doc = include_str!("../docs/guides/01-quickstart.md")]
struct QuickstartDoctests;

#[cfg(doctest)]
#[doc = include_str!("../docs/guides/02-implementing-lattice.md")]
struct ImplementingLatticeDoctests;

#[cfg(doctest)]
#[doc = include_str!("../docs/guides/03-crdt-cookbook.md")]
struct CrdtCookbookDoctests;

#[cfg(doctest)]
#[doc = include_str!("../docs/guides/04-fixpoints-and-analysis.md")]
struct FixpointsDoctests;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn numeric_u32() {
        // join = max, meet = min
        assert_eq!(5u32.join(&3), 5);
        assert_eq!(3u32.join(&5), 5);
        assert_eq!(5u32.meet(&3), 3);
        assert_eq!(3u32.meet(&5), 3);

        // Idempotency
        assert_eq!(5u32.join(&5), 5);
        assert_eq!(5u32.meet(&5), 5);
    }

    #[test]
    fn numeric_i32() {
        assert_eq!((-5i32).join(&3), 3);
        assert_eq!((-5i32).meet(&3), -5);
    }

    #[test]
    fn numeric_f64() {
        assert_eq!(5.0f64.join(&3.0), 5.0);
        assert_eq!(5.0f64.meet(&3.0), 3.0);
    }

    #[test]
    fn boolean() {
        // join = OR
        assert!(true.join(&false));
        assert!(!false.join(&false));
        // meet = AND
        assert!(true.meet(&true));
        assert!(!true.meet(&false));
    }

    #[test]
    fn option() {
        let some_5 = Some(5u32);
        let some_3 = Some(3u32);
        let none: Option<u32> = None;

        // join: Some if either Some
        assert_eq!(some_5.join(&some_3), Some(5)); // max
        assert_eq!(some_5.join(&none), Some(5));
        assert_eq!(none.join(&some_3), Some(3));
        assert_eq!(none.join(&none), None);

        // meet: Some only if both Some
        assert_eq!(some_5.meet(&some_3), Some(3)); // min
        assert_eq!(some_5.meet(&none), None);
        assert_eq!(none.meet(&none), None);
    }

    #[test]
    fn hashset() {
        let set1: HashSet<i32> = [1, 2, 3].into_iter().collect();
        let set2: HashSet<i32> = [2, 3, 4].into_iter().collect();

        // join = union
        assert_eq!(set1.join(&set2), [1, 2, 3, 4].into_iter().collect());
        // meet = intersection
        assert_eq!(set1.meet(&set2), [2, 3].into_iter().collect());
    }

    #[test]
    fn hashset_disjoint() {
        let set1: HashSet<i32> = [1, 2].into_iter().collect();
        let set2: HashSet<i32> = [3, 4].into_iter().collect();

        assert_eq!(set1.join(&set2), [1, 2, 3, 4].into_iter().collect());
        assert!(set1.meet(&set2).is_empty());
    }

    #[test]
    fn vec() {
        let vec1 = vec![1, 2, 3];
        let vec2 = vec![2, 3, 4];

        // join = concat + dedup
        assert_eq!(vec1.join(&vec2), vec![1, 2, 3, 4]);
        // meet = intersection preserving order
        assert_eq!(vec1.meet(&vec2), vec![2, 3]);
    }

    #[test]
    fn vec_preserves_order() {
        let vec1 = vec![3, 1, 2];
        let vec2 = vec![4, 2, 1];

        // join preserves order of first, then appends new elements
        assert_eq!(vec1.join(&vec2), vec![3, 1, 2, 4]);
        // meet preserves order of first
        assert_eq!(vec1.meet(&vec2), vec![1, 2]);
    }
}
