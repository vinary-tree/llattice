//! Executable refinement and algebra checks for the v2 layered API.

use llattice::laws::{self, Law, LawViolation};
use llattice::{Bottom, JoinSemilattice, Lattice, MeetSemilattice};
use proptest::prelude::*;
use std::cell::Cell;
use std::collections::hash_map::DefaultHasher;
use std::collections::HashSet;
use std::hash::BuildHasherDefault;
use std::rc::Rc;
use std::thread;

#[test]
fn laws_hold_exhaustively_over_bool() {
    for &a in &[false, true] {
        for &b in &[false, true] {
            for &c in &[false, true] {
                assert_eq!(laws::check_lattice(&a, &b, &c), Ok(()));
                assert_eq!(laws::check_bottom(&a), Ok(()));
            }
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig::with_cases(512))]

    // INVARIANT-HOOK: LATT-LAW-1..5 — lattice algebra and order bridge.
    // INVARIANT-HOOK: LATT-LAYER-1..3 — join-derived order, exact in-place
    // refinement, and bottom.
    #[test]
    fn laws_hold_over_i64(a: i64, b: i64, c: i64) {
        prop_assert_eq!(laws::check_lattice(&a, &b, &c), Ok(()));
        prop_assert_eq!(laws::check_bottom(&a), Ok(()));
    }

    #[test]
    fn laws_hold_over_u32(a: u32, b: u32, c: u32) {
        prop_assert_eq!(laws::check_lattice(&a, &b, &c), Ok(()));
        prop_assert_eq!(laws::check_bottom(&a), Ok(()));
    }

    // INVARIANT-HOOK: LATT-LAYER-5 — Option preserves lawful lattice
    // structure and adjoins None as bottom.
    #[test]
    fn laws_hold_over_option_i64(a: Option<i64>, b: Option<i64>, c: Option<i64>) {
        prop_assert_eq!(laws::check_lattice(&a, &b, &c), Ok(()));
        prop_assert_eq!(laws::check_bottom(&a), Ok(()));
    }

    #[test]
    fn laws_hold_over_hashset_i8(
        a in proptest::collection::hash_set(any::<i8>(), 0..16),
        b in proptest::collection::hash_set(any::<i8>(), 0..16),
        c in proptest::collection::hash_set(any::<i8>(), 0..16),
    ) {
        prop_assert_eq!(laws::check_lattice(&a, &b, &c), Ok(()));
        prop_assert_eq!(laws::check_bottom(&a), Ok(()));
    }
}

#[test]
fn join_assign_contract_is_exact() {
    let mut scalar = 3_u32;
    assert!(!scalar.join_assign(&2));
    assert_eq!(scalar, 3);
    assert!(scalar.join_assign(&5));
    assert_eq!(scalar, 5);
    assert!(!scalar.join_assign(&5));

    let mut optional = None;
    assert!(optional.join_assign(&Some(7_u32)));
    assert_eq!(optional, Some(7));
    assert!(!optional.join_assign(&Some(3)));

    let mut set: HashSet<u32> = [1, 2].into_iter().collect();
    assert!(!set.join_assign(&[1].into_iter().collect()));
    assert!(set.join_assign(&[2, 3].into_iter().collect()));
    assert_eq!(set, [1, 2, 3].into_iter().collect());
}

#[derive(Clone, Debug, PartialEq)]
struct WrongChangeFlag(bool);

impl JoinSemilattice for WrongChangeFlag {
    fn join_assign(&mut self, other: &Self) -> bool {
        self.0 |= other.0;
        false
    }
}

#[test]
fn law_harness_reports_inexact_change_flag() {
    assert_eq!(
        laws::check_join_semilattice(
            &WrongChangeFlag(false),
            &WrongChangeFlag(true),
            &WrongChangeFlag(false),
        ),
        Err(LawViolation {
            law: Law::JoinAssignChangeFlag,
        })
    );
}

#[derive(Clone, Debug, PartialEq)]
struct NonAbsorbing(bool);

impl JoinSemilattice for NonAbsorbing {
    fn join_assign(&mut self, other: &Self) -> bool {
        let changed = !self.0 && other.0;
        self.0 |= other.0;
        changed
    }
}

impl MeetSemilattice for NonAbsorbing {
    fn meet(&self, other: &Self) -> Self {
        Self(self.0 || other.0)
    }
}

impl Lattice for NonAbsorbing {}

// INVARIANT-HOOK: LATT-LAYER-4 — two semilattices need not absorb.
#[test]
fn law_harness_rejects_nonabsorbing_operations() {
    assert_eq!(
        laws::check_lattice(
            &NonAbsorbing(false),
            &NonAbsorbing(true),
            &NonAbsorbing(false),
        ),
        Err(LawViolation {
            law: Law::JoinAbsorbsMeet,
        })
    );
}

#[derive(Clone, Debug, PartialEq)]
struct LocalOnly(Rc<Cell<u32>>);

impl JoinSemilattice for LocalOnly {
    fn join_assign(&mut self, other: &Self) -> bool {
        if self.0.get() < other.0.get() {
            self.0 = Rc::new(Cell::new(other.0.get()));
            true
        } else {
            false
        }
    }
}

#[test]
fn base_algebra_accepts_non_send_non_sync_values() {
    let first = LocalOnly(Rc::new(Cell::new(1)));
    let second = LocalOnly(Rc::new(Cell::new(2)));
    assert_eq!(
        laws::check_join_semilattice(&first, &second, &second),
        Ok(())
    );
}

#[test]
fn hashset_supports_cloneable_custom_hashers() {
    type DeterministicSet<T> = HashSet<T, BuildHasherDefault<DefaultHasher>>;

    let left: DeterministicSet<u32> = [1, 2].into_iter().collect();
    let right: DeterministicSet<u32> = [2, 3].into_iter().collect();
    assert_eq!(left.join(&right), [1, 2, 3].into_iter().collect());
    assert_eq!(left.meet(&right), [2].into_iter().collect());
    assert!(DeterministicSet::<u32>::bottom().is_empty());
}

// INVARIANT-HOOK: LATT-LAYER-7 — collection work uses bounded native stack.
#[test]
fn hashset_operations_do_not_use_input_depth_native_stack() {
    thread::Builder::new()
        .name("llattice-small-stack".into())
        .stack_size(64 * 1024)
        .spawn(|| {
            let mut left: HashSet<u32> = (0..100_000).collect();
            let right: HashSet<u32> = (50_000..150_000).collect();
            assert!(left.join_assign(&right));
            assert_eq!(left.len(), 150_000);
            assert_eq!(left.meet(&right).len(), 100_000);
            assert!(right.leq(&left));
        })
        .expect("spawn small-stack test thread")
        .join()
        .expect("small-stack lattice operations complete");
}

// INVARIANT-HOOK: LATT-FLOAT-1 — raw IEEE floats are intentionally not
// implemented because NaN defeats structural equality and max drops NaN.
#[test]
fn raw_nan_breaks_partial_equality() {
    let nan = f64::NAN;
    assert_ne!(nan, nan);
    assert_eq!(nan.max(1.0), 1.0);
    assert_eq!(1.0_f64.max(nan), 1.0);
}
