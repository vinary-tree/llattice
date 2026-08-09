//! Executable lattice-law harness.
//!
//! docs/engineering/01-testing.md specifies a `laws_hold` harness that turns the
//! four lattice laws (idempotency, commutativity, associativity, absorption)
//! from prose into executable checks, but no such harness existed in the crate.
//! This file implements it exactly as documented and exercises it against the
//! built-in impls: exhaustively over `bool`, by `proptest` over integers,
//! `Option`, and `HashSet`, and over the NaN-free `f64` subset (the impl is
//! documented lawful only there). `Vec` is intentionally only a join-semilattice
//! *up to content-equality* (its `join` is left-biased, so commutativity fails
//! on `Vec` values) -- it is checked up to set-equality, matching its documented
//! contract.
//!
//! Correspondence: the four laws mechanized in proofs/coq/LatticeLaws.v
//! (LATT-LAW-1..5) and the NaN caveat in proofs/coq/FloatCaveat.v
//! (LATT-FLOAT-1) are the formal home; this harness is their executable mirror.

use llattice::Lattice;
use proptest::prelude::*;

/// The four lattice laws over a triple, exactly as documented in
/// docs/engineering/01-testing.md.
fn laws_hold<L: Lattice + PartialEq + Clone>(a: &L, b: &L, c: &L) -> bool {
    // idempotency
    a.join(a) == *a && a.meet(a) == *a &&
    // commutativity
    a.join(b) == b.join(a) && a.meet(b) == b.meet(a) &&
    // associativity
    a.join(b).join(c) == a.join(&b.join(c)) &&
    a.meet(b).meet(c) == a.meet(&b.meet(c)) &&
    // absorption
    a.join(&a.meet(b)) == *a && a.meet(&a.join(b)) == *a
}

#[test]
fn laws_hold_exhaustively_over_bool() {
    for &a in &[false, true] {
        for &b in &[false, true] {
            for &c in &[false, true] {
                assert!(laws_hold(&a, &b, &c), "bool law violated at {a},{b},{c}");
            }
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(512))]

    // INVARIANT-HOOK: LATT-LAW-1..4 — idempotency, commutativity, associativity,
    // and absorption of join/meet (proofs/coq/LatticeLaws.v).
    #[test]
    fn laws_hold_over_i64(a: i64, b: i64, c: i64) {
        prop_assert!(laws_hold(&a, &b, &c));
    }

    #[test]
    fn laws_hold_over_u32(a: u32, b: u32, c: u32) {
        prop_assert!(laws_hold(&a, &b, &c));
    }

    #[test]
    fn laws_hold_over_option_i64(a: Option<i64>, b: Option<i64>, c: Option<i64>) {
        prop_assert!(laws_hold(&a, &b, &c));
    }

    #[test]
    fn laws_hold_over_hashset_i8(
        a in proptest::collection::hash_set(any::<i8>(), 0..8),
        b in proptest::collection::hash_set(any::<i8>(), 0..8),
        c in proptest::collection::hash_set(any::<i8>(), 0..8),
    ) {
        prop_assert!(laws_hold(&a, &b, &c));
    }

    /// The f64 impl is lawful only on NaN-free values; sweep finite f64 (the
    /// generator excludes NaN and infinities) and confirm the laws hold there.
    #[test]
    fn laws_hold_over_finite_f64(
        a in proptest::num::f64::NORMAL | proptest::num::f64::ZERO,
        b in proptest::num::f64::NORMAL | proptest::num::f64::ZERO,
        c in proptest::num::f64::NORMAL | proptest::num::f64::ZERO,
    ) {
        prop_assert!(laws_hold(&a, &b, &c));
    }
}

/// The documented NaN caveat, made executable: `NaN` breaks idempotency under
/// `==` (because `NaN != NaN`), which is exactly why the f64 impl is lawful only
/// NaN-free. This mirrors proofs/coq/FloatCaveat.v `nan_breaks_idempotency`.
///
/// INVARIANT-HOOK: LATT-FLOAT-1 — the f32/f64 impls are lawful only NaN-free.
#[test]
fn nan_breaks_idempotency() {
    let nan = f64::NAN;
    assert!(
        nan.join(&nan) != nan,
        "NaN.join(NaN) must not equal NaN under IEEE ==, breaking idempotency"
    );
    // ...and max silently drops NaN when the other operand is finite.
    assert_eq!(nan.join(&1.0), 1.0, "f64::max drops NaN");
    assert_eq!(1.0_f64.join(&nan), 1.0, "f64::max drops NaN");
}

/// `Vec` is a join-semilattice only up to content-equality: its `join` is
/// left-biased so commutativity fails on `Vec` VALUES (documented in
/// src/lib.rs). Checked here up to set-equality, confirming the contract.
fn as_sorted_set(mut v: Vec<i8>) -> Vec<i8> {
    v.sort_unstable();
    v.dedup();
    v
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(256))]

    #[test]
    fn vec_laws_hold_up_to_content_equality(
        a in proptest::collection::vec(-4i8..4, 0..6),
        b in proptest::collection::vec(-4i8..4, 0..6),
        c in proptest::collection::vec(-4i8..4, 0..6),
    ) {
        // idempotency and absorption hold on Vec VALUES: `join` copies the left
        // operand verbatim and only appends right-operand items it lacks, so a
        // self-join (and a join with a subset) returns the left operand exactly.
        prop_assert_eq!(a.join(&a), a.clone());
        prop_assert_eq!(a.join(&a.meet(&b)), a.clone());
        // commutativity and associativity hold up to set-equality (join is
        // left-biased on order, so they do NOT hold on Vec values).
        prop_assert_eq!(as_sorted_set(a.join(&b)), as_sorted_set(b.join(&a)));
        prop_assert_eq!(
            as_sorted_set(a.join(&b).join(&c)),
            as_sorted_set(a.join(&b.join(&c)))
        );
    }
}
