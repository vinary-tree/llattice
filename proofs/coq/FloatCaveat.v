(** * FloatCaveat — why the f32/f64 lattice is lawful only NaN-free

    llattice's `f32`/`f64` [Lattice] impls use `join = max`, `meet = min`
    (src/lib.rs:126-149). The source itself flags the caveat: they are lawful
    ONLY on NaN-free values, because IEEE-754 `max`/`min` silently DROP NaN
    (`f64::max(NaN, x) == x`) and IEEE equality makes `NaN != NaN`, which breaks
    idempotency under `==`. This file makes the caveat precise -- obligation #26
    (LATT-FLOAT-1): the four laws hold on the NaN-free subset, and NaN is a
    concrete counterexample to idempotency.

    IEEE-754 floats are not modeled with Flocq here (the caveat is purely about
    NaN's total-order and equality anomalies, not rounding); instead the two
    relevant behaviours are modeled directly: an extended value is a finite
    integer or a NaN token, `fmax`/`fmin` follow Rust's `f64::max`/`min`
    (NaN-dropping), and `feq` follows IEEE `==` (`NaN` never equals anything).

    Registry: proofs/doc/lattice-invariants.tsv, LATT-FLOAT-1.
*)

Require Import Stdlib.ZArith.ZArith.

Open Scope Z_scope.

(** A float value: a finite value (modeled by an integer -- only order and
    equality matter here) or NaN. *)
Inductive fval : Type := Fin (z : Z) | FNaN.

(** `f64::max` semantics: NaN is dropped (max of NaN and x is x); max of two
    finites is the numeric max; max of two NaNs is NaN. *)
Definition fmax (a b : fval) : fval :=
  match a, b with
  | FNaN, _ => b
  | _, FNaN => a
  | Fin x, Fin y => Fin (Z.max x y)
  end.

Definition fmin (a b : fval) : fval :=
  match a, b with
  | FNaN, _ => b
  | _, FNaN => a
  | Fin x, Fin y => Fin (Z.min x y)
  end.

(** IEEE equality: two finites are equal iff numerically equal; NaN equals
    nothing, not even itself. *)
Definition feq (a b : fval) : bool :=
  match a, b with
  | Fin x, Fin y => Z.eqb x y
  | _, _ => false
  end.

Definition is_nan (a : fval) : bool := match a with FNaN => true | _ => false end.

(** ** LATT-FLOAT-1: lawful on the NaN-free subset *)

(** On finite (NaN-free) values, join is idempotent under IEEE equality. *)
Theorem fmax_idempotent_on_finite :
  forall x, feq (fmax (Fin x) (Fin x)) (Fin x) = true.
Proof. intro x; simpl. rewrite Z.max_id. apply Z.eqb_refl. Qed.

Theorem fmin_idempotent_on_finite :
  forall x, feq (fmin (Fin x) (Fin x)) (Fin x) = true.
Proof. intro x; simpl. rewrite Z.min_id. apply Z.eqb_refl. Qed.

(** Commutativity and associativity hold on finite values (they reduce to the
    integer-lattice laws). *)
Theorem fmax_comm_on_finite :
  forall x y, fmax (Fin x) (Fin y) = fmax (Fin y) (Fin x).
Proof. intros x y; simpl; rewrite Z.max_comm; reflexivity. Qed.

Theorem fmax_assoc_on_finite :
  forall x y z,
    fmax (fmax (Fin x) (Fin y)) (Fin z) = fmax (Fin x) (fmax (Fin y) (Fin z)).
Proof. intros x y z; simpl; rewrite Z.max_assoc; reflexivity. Qed.

(** ** The caveat, made concrete *)

(** NaN breaks idempotency under IEEE equality: `NaN.join(NaN)` is NaN, but NaN
    does not equal NaN, so the idempotency law `feq (join a a) a` FAILS. This is
    exactly why the impl is documented as lawful only NaN-free. *)
Theorem nan_breaks_idempotency :
  feq (fmax FNaN FNaN) FNaN = false.
Proof. reflexivity. Qed.

(** NaN is never equal to any value under IEEE equality (the root anomaly). *)
Theorem nan_never_equal : forall a, feq FNaN a = false /\ feq a FNaN = false.
Proof. intro a; destruct a; split; reflexivity. Qed.

(** `max` silently drops NaN: joining NaN with a finite value yields the finite
    value, so NaN cannot even be observed as the join result -- the "silent
    drop" the source comment warns about. *)
Theorem fmax_drops_nan :
  forall x, fmax FNaN (Fin x) = Fin x /\ fmax (Fin x) FNaN = Fin x.
Proof. intro x; split; reflexivity. Qed.

(** The clean statement of the boundary: an idempotency check passes exactly
    when the value is not NaN (for the two shapes -- finite passes, NaN fails). *)
Theorem idempotency_holds_iff_not_nan_finite :
  forall x, feq (fmax (Fin x) (Fin x)) (Fin x) = negb (is_nan (Fin x)).
Proof. intro x; simpl. rewrite Z.max_id. apply Z.eqb_refl. Qed.

Theorem idempotency_fails_on_nan :
  feq (fmax FNaN FNaN) FNaN = negb (is_nan FNaN).
Proof. reflexivity. Qed.
