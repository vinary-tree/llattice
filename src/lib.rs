//! Lawful, layered lattice traits for monotone computation.
//!
//! The API separates the algebraic structures that programs actually need:
//! [`JoinSemilattice`] for monotone accumulation, [`MeetSemilattice`] for
//! greatest-lower-bound queries, [`Lattice`] when both operations additionally
//! satisfy absorption, and [`Bottom`] when a context-free least value exists.
//!
//! The hot path is [`JoinSemilattice::join_assign`]. It updates an accumulator
//! in place and reports exactly whether its value changed, avoiding the
//! allocate-compare-replace cycle common in fixed-point engines.
//!
//! ```rust
//! use llattice::{Bottom, JoinSemilattice, MeetSemilattice};
//! use std::collections::HashSet;
//!
//! let mut facts: HashSet<u32> = Bottom::bottom();
//! assert!(facts.join_assign(&[1, 2].into_iter().collect()));
//! assert!(!facts.join_assign(&[1].into_iter().collect()));
//! assert!(facts.leq(&[1, 2, 3].into_iter().collect()));
//! assert_eq!(facts.meet(&[2, 3].into_iter().collect()), [2].into_iter().collect());
//! ```
//!
//! Algebraic traits deliberately do not require `Send` or `Sync`. Parallel
//! engines add those bounds at their own scheduling boundary instead of
//! excluding valid single-threaded domains from the shared vocabulary.
//!
//! The core traits, scalar implementations, `Option` lift, and law harness are
//! available without the default `std` feature. The `HashSet`
//! implementations require `std`.

#![forbid(unsafe_code)]
#![cfg_attr(not(feature = "std"), no_std)]

mod impls;
pub mod laws;

/// An idempotent, commutative, associative join operation.
///
/// The derived order is `a.leq(b)` exactly when `a.join(b) == b`. Implementors
/// must keep [`join`](Self::join), [`join_assign`](Self::join_assign), and
/// [`leq`](Self::leq) observationally equivalent. The reusable [`laws`] module
/// checks these obligations.
///
/// `Clone + PartialEq` are the only base capabilities required. `Clone` enables
/// the allocation-neutral default `join` implementation, while `PartialEq`
/// makes the change flag and derived order exact. Concurrency bounds belong on
/// consumers, not on this algebra.
pub trait JoinSemilattice: Clone + PartialEq {
    /// Updates `self` to its join with `other`.
    ///
    /// Returns `true` exactly when the resulting value differs from the value
    /// of `self` before the call. Implementations should mutate existing
    /// storage directly when that is more efficient than allocating a result.
    fn join_assign(&mut self, other: &Self) -> bool;

    /// Returns the least upper bound of `self` and `other`.
    #[inline]
    #[must_use]
    fn join(&self, other: &Self) -> Self {
        let mut result = self.clone();
        let _changed = result.join_assign(other);
        result
    }

    /// Returns whether `self` is below or equal to `other` in the join-derived
    /// partial order.
    #[inline]
    #[must_use]
    fn leq(&self, other: &Self) -> bool {
        self.join(other).eq(other)
    }
}

/// An idempotent, commutative, associative meet operation.
pub trait MeetSemilattice: Clone + PartialEq {
    /// Returns the greatest lower bound of `self` and `other`.
    #[must_use]
    fn meet(&self, other: &Self) -> Self;
}

/// A lawful lattice: join and meet semilattices that also satisfy absorption.
///
/// This is an explicit marker rather than a blanket implementation. Two lawful
/// semilattice operations do not necessarily absorb each other, so implementors
/// must opt in only after checking both absorption laws with
/// [`laws::check_lattice`].
pub trait Lattice: JoinSemilattice + MeetSemilattice {}

/// A join-semilattice with a context-free least element.
///
/// A lawful implementation satisfies `Self::bottom().join(x) == x` for every
/// `x`. Context-free means construction needs no universe, comparator, arena,
/// or runtime configuration.
pub trait Bottom: JoinSemilattice {
    /// Returns the least value.
    #[must_use]
    fn bottom() -> Self;
}

/// Convenient imports for algorithms that use the full layered API.
pub mod prelude {
    pub use crate::{Bottom, JoinSemilattice, Lattice, MeetSemilattice};
}

// Compile and run every Rust block in the documentation suite as doctests.
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
