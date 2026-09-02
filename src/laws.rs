//! Reusable executable checks for the layered algebraic contracts.
//!
//! These functions check a supplied sample triple; they do not prove a type
//! lawful for every value. Exhaustive finite-domain tests, property-based
//! generators, or formal proofs should call them over an appropriate domain.

use crate::{Bottom, JoinSemilattice, Lattice, MeetSemilattice};
use core::fmt;

/// A single algebraic or refinement obligation.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum Law {
    /// `a.join(a) == a`.
    JoinIdempotency,
    /// `a.join(b) == b.join(a)`.
    JoinCommutativity,
    /// `(a.join(b)).join(c) == a.join(b.join(c))`.
    JoinAssociativity,
    /// `join_assign` stores the same value as `join`.
    JoinAssignValue,
    /// `join_assign` reports exactly whether the stored value changed.
    JoinAssignChangeFlag,
    /// `leq` agrees with `a.join(b) == b`.
    JoinOrderBridge,
    /// `a.leq(a)`.
    JoinOrderReflexivity,
    /// `a.leq(b) && b.leq(c)` implies `a.leq(c)`.
    JoinOrderTransitivity,
    /// `a.leq(b) && b.leq(a)` implies `a == b`.
    JoinOrderAntisymmetry,
    /// `a.meet(a) == a`.
    MeetIdempotency,
    /// `a.meet(b) == b.meet(a)`.
    MeetCommutativity,
    /// `(a.meet(b)).meet(c) == a.meet(b.meet(c))`.
    MeetAssociativity,
    /// `a.join(a.meet(b)) == a`.
    JoinAbsorbsMeet,
    /// `a.meet(a.join(b)) == a`.
    MeetAbsorbsJoin,
    /// `bottom.join(a) == a`.
    BottomIdentity,
    /// `bottom.leq(a)`.
    BottomLeast,
}

/// Identifies the first failed obligation in a deterministic check order.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct LawViolation {
    /// The failed law.
    pub law: Law,
}

impl fmt::Display for LawViolation {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "lattice law violated: {:?}", self.law)
    }
}

#[cfg(feature = "std")]
impl std::error::Error for LawViolation {}

#[inline]
fn violation(law: Law) -> Result<(), LawViolation> {
    Err(LawViolation { law })
}

/// Checks the join laws, the in-place refinement, and the derived partial
/// order over one sample triple.
pub fn check_join_semilattice<T>(a: &T, b: &T, c: &T) -> Result<(), LawViolation>
where
    T: JoinSemilattice,
{
    if a.join(a) != *a {
        return violation(Law::JoinIdempotency);
    }
    if a.join(b) != b.join(a) {
        return violation(Law::JoinCommutativity);
    }
    if a.join(b).join(c) != a.join(&b.join(c)) {
        return violation(Law::JoinAssociativity);
    }

    let expected = a.join(b);
    let mut assigned = a.clone();
    let changed = assigned.join_assign(b);
    if assigned != expected {
        return violation(Law::JoinAssignValue);
    }
    if changed != assigned.ne(a) {
        return violation(Law::JoinAssignChangeFlag);
    }

    if a.leq(b) != a.join(b).eq(b) {
        return violation(Law::JoinOrderBridge);
    }
    if !a.leq(a) {
        return violation(Law::JoinOrderReflexivity);
    }
    if a.leq(b) && b.leq(c) && !a.leq(c) {
        return violation(Law::JoinOrderTransitivity);
    }
    if a.leq(b) && b.leq(a) && a != b {
        return violation(Law::JoinOrderAntisymmetry);
    }

    Ok(())
}

/// Checks the meet-semilattice laws over one sample triple.
pub fn check_meet_semilattice<T>(a: &T, b: &T, c: &T) -> Result<(), LawViolation>
where
    T: MeetSemilattice,
{
    if a.meet(a) != *a {
        return violation(Law::MeetIdempotency);
    }
    if a.meet(b) != b.meet(a) {
        return violation(Law::MeetCommutativity);
    }
    if a.meet(b).meet(c) != a.meet(&b.meet(c)) {
        return violation(Law::MeetAssociativity);
    }
    Ok(())
}

/// Checks both semilattices and their absorption laws over one sample triple.
pub fn check_lattice<T>(a: &T, b: &T, c: &T) -> Result<(), LawViolation>
where
    T: Lattice,
{
    check_join_semilattice(a, b, c)?;
    check_meet_semilattice(a, b, c)?;
    if a.join(&a.meet(b)) != *a {
        return violation(Law::JoinAbsorbsMeet);
    }
    if a.meet(&a.join(b)) != *a {
        return violation(Law::MeetAbsorbsJoin);
    }
    Ok(())
}

/// Checks the context-free bottom laws against one sample value.
pub fn check_bottom<T>(value: &T) -> Result<(), LawViolation>
where
    T: Bottom,
{
    let bottom = T::bottom();
    if bottom.join(value) != *value {
        return violation(Law::BottomIdentity);
    }
    if !bottom.leq(value) {
        return violation(Law::BottomLeast);
    }
    Ok(())
}
