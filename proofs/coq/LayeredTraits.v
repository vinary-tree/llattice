(** * LayeredTraits — contracts for llattice's layered Rust API

    The version-two API separates a join-semilattice from a meet-semilattice
    and calls their combination a lattice only when absorption is also lawful.
    This module establishes the derived order, the exact observable contract
    of an in-place join, context-free bottom, the lawful [option] lift, and two
    counterexamples that prevent over-broad Rust implementations.

    All hypotheses are section parameters and therefore become explicit
    theorem arguments.  This file declares no axiom, parameter, or admission.

    Registry: proofs/doc/lattice-invariants.tsv, LATT-LAYER-1..6.
*)

From Stdlib Require Import Arith.PeanoNat Bool.Bool Lists.List.
Import ListNotations.

Set Implicit Arguments.

(** ** A join-semilattice induces a partial order *)

Section JoinOrder.

Context {A : Type}.
Variable join : A -> A -> A.
Hypothesis join_idempotent : forall value, join value value = value.
Hypothesis join_commutative : forall left right, join left right = join right left.
Hypothesis join_associative : forall first second third,
  join (join first second) third = join first (join second third).

Definition join_leq (left right : A) : Prop := join left right = right.

Theorem join_leq_reflexive : forall value, join_leq value value.
Proof. intro value; unfold join_leq; apply join_idempotent. Qed.

Theorem join_leq_transitive : forall first second third,
  join_leq first second -> join_leq second third -> join_leq first third.
Proof.
  intros first second third Hfirst Hsecond; unfold join_leq in *.
  rewrite <- Hsecond.
  rewrite <- join_associative.
  now rewrite Hfirst.
Qed.

Theorem join_leq_antisymmetric : forall left right,
  join_leq left right -> join_leq right left -> left = right.
Proof.
  intros left right Hleft Hright; unfold join_leq in *.
  rewrite <- Hright.
  rewrite join_commutative.
  exact Hleft.
Qed.

Theorem join_leq_is_partial_order :
  (forall value, join_leq value value) /\
  (forall first second third,
    join_leq first second -> join_leq second third -> join_leq first third) /\
  (forall left right, join_leq left right -> join_leq right left -> left = right).
Proof.
  split; [exact join_leq_reflexive |].
  split; [exact join_leq_transitive | exact join_leq_antisymmetric].
Qed.

End JoinOrder.

(** ** In-place join returns both the join and an exact change flag *)

Section JoinAssign.

Context {A : Type}.
Variable join : A -> A -> A.
Variable eqb : A -> A -> bool.
Hypothesis eqb_equal : forall left right, eqb left right = true <-> left = right.

Record JoinAssignResult : Type := join_assign_result {
  assigned_value : A;
  assigned_changed : bool
}.

Definition join_assign_model (current incoming : A) : JoinAssignResult :=
  let updated := join current incoming in
  join_assign_result updated (negb (eqb current updated)).

Lemma eqb_false_iff : forall left right,
  eqb left right = false <-> left <> right.
Proof.
  intros left right; split.
  - intros Hfalse Hequal; subst right.
    pose proof (proj2 (eqb_equal left left) eq_refl) as Htrue.
    rewrite Htrue in Hfalse; discriminate.
  - intro Hdifferent.
    destruct (eqb left right) eqn:Hequal; [| reflexivity].
    exfalso; apply Hdifferent; now apply (proj1 (eqb_equal left right)).
Qed.

Theorem join_assign_returns_join : forall current incoming,
  assigned_value (join_assign_model current incoming) = join current incoming.
Proof. reflexivity. Qed.

Theorem join_assign_changed_iff : forall current incoming,
  assigned_changed (join_assign_model current incoming) = true <->
  current <> join current incoming.
Proof.
  intros current incoming; unfold join_assign_model; simpl.
  rewrite negb_true_iff.
  apply eqb_false_iff.
Qed.

End JoinAssign.

(** ** A context-free bottom is least in the join-derived order *)

Section BottomLayer.

Context {A : Type}.
Variable join : A -> A -> A.
Variable bottom : A.
Hypothesis bottom_join_identity : forall value, join bottom value = value.

Theorem bottom_is_least : forall value, join_leq join bottom value.
Proof. intro value; unfold join_leq; apply bottom_join_identity. Qed.

End BottomLayer.

(** ** Separate semilattice laws do not imply lattice absorption *)

Definition counter_join (left right : bool) : bool := orb left right.
Definition counter_meet (left right : bool) : bool := orb left right.

Theorem two_semilattices_need_not_form_lattice :
  (forall value, counter_join value value = value) /\
  (forall left right, counter_join left right = counter_join right left) /\
  (forall first second third,
    counter_join (counter_join first second) third =
    counter_join first (counter_join second third)) /\
  (forall value, counter_meet value value = value) /\
  (forall left right, counter_meet left right = counter_meet right left) /\
  (forall first second third,
    counter_meet (counter_meet first second) third =
    counter_meet first (counter_meet second third)) /\
  counter_meet false (counter_join false true) <> false.
Proof.
  repeat split.
  - intros [|]; reflexivity.
  - intros [|] [|]; reflexivity.
  - intros [|] [|] [|]; reflexivity.
  - intros [|]; reflexivity.
  - intros [|] [|]; reflexivity.
  - intros [|] [|] [|]; reflexivity.
  - discriminate.
Qed.

(** ** [option] lawfully adjoins a fresh bottom *)

Section OptionLift.

Context {A : Type}.
Variable join meet : A -> A -> A.
Hypothesis join_idempotent : forall value, join value value = value.
Hypothesis join_commutative : forall left right, join left right = join right left.
Hypothesis join_associative : forall first second third,
  join (join first second) third = join first (join second third).
Hypothesis meet_idempotent : forall value, meet value value = value.
Hypothesis meet_commutative : forall left right, meet left right = meet right left.
Hypothesis meet_associative : forall first second third,
  meet (meet first second) third = meet first (meet second third).
Hypothesis absorb_join_meet : forall left right, join left (meet left right) = left.
Hypothesis absorb_meet_join : forall left right, meet left (join left right) = left.

Definition option_join (left right : option A) : option A :=
  match left, right with
  | Some left_value, Some right_value => Some (join left_value right_value)
  | Some value, None | None, Some value => Some value
  | None, None => None
  end.

Definition option_meet (left right : option A) : option A :=
  match left, right with
  | Some left_value, Some right_value => Some (meet left_value right_value)
  | _, _ => None
  end.

Theorem option_join_idempotent : forall value, option_join value value = value.
Proof. intros [value |]; simpl; [now rewrite join_idempotent | reflexivity]. Qed.

Theorem option_join_commutative : forall left right,
  option_join left right = option_join right left.
Proof.
  intros [left |] [right |]; simpl; try reflexivity.
  now rewrite join_commutative.
Qed.

Theorem option_join_associative : forall first second third,
  option_join (option_join first second) third =
  option_join first (option_join second third).
Proof.
  intros [first |] [second |] [third |]; simpl; try reflexivity.
  now rewrite join_associative.
Qed.

Theorem option_meet_idempotent : forall value, option_meet value value = value.
Proof. intros [value |]; simpl; [now rewrite meet_idempotent | reflexivity]. Qed.

Theorem option_meet_commutative : forall left right,
  option_meet left right = option_meet right left.
Proof.
  intros [left |] [right |]; simpl; try reflexivity.
  now rewrite meet_commutative.
Qed.

Theorem option_meet_associative : forall first second third,
  option_meet (option_meet first second) third =
  option_meet first (option_meet second third).
Proof.
  intros [first |] [second |] [third |]; simpl; try reflexivity.
  now rewrite meet_associative.
Qed.

Theorem option_absorb_join_meet : forall left right,
  option_join left (option_meet left right) = left.
Proof.
  intros [left |] [right |]; simpl; try reflexivity.
  now rewrite absorb_join_meet.
Qed.

Theorem option_absorb_meet_join : forall left right,
  option_meet left (option_join left right) = left.
Proof.
  intros [left |] [right |]; simpl; try reflexivity.
  - now rewrite absorb_meet_join.
  - now rewrite meet_idempotent.
Qed.

Theorem option_none_is_bottom : forall value, option_join None value = value.
Proof. now intros [value |]. Qed.

End OptionLift.

(** ** Input-sized work is an explicit, strictly decreasing machine

    This transition system is the formal target for collection-backed Rust
    implementations.  A transition consumes exactly one pending element and
    stores all evolving state in the value, so the implementation can refine
    it with a loop instead of input-depth native recursion. *)

Section ExplicitWorklist.

Context {A : Type}.
Variable combine : A -> A -> A.

Record WorkState : Type := work_state {
  pending : list A;
  accumulator : A
}.

Definition work_step (state : WorkState) : option WorkState :=
  match pending state with
  | [] => None
  | current :: rest =>
      Some (work_state rest (combine (accumulator state) current))
  end.

Theorem explicit_worklist_progress : forall state,
  (work_step state = None <-> pending state = []) /\
  (forall next,
    work_step state = Some next ->
    length (pending next) < length (pending state)).
Proof.
  intros [remaining accumulated]; destruct remaining as [|current rest]; simpl.
  - split; [split; reflexivity | intros next H; discriminate].
  - split.
    + split; intro H; discriminate.
    + intros next H; inversion H; subst; simpl.
      apply Nat.lt_succ_diag_r.
Qed.

End ExplicitWorklist.

(** ** A left-biased raw sequence is not a structural join-semilattice *)

Definition add_missing_bool (accumulator : list bool) (value : bool) : list bool :=
  if existsb (Bool.eqb value) accumulator then accumulator
  else accumulator ++ [value].

Definition list_join (left right : list bool) : list bool :=
  fold_left add_missing_bool right left.

Theorem raw_sequence_join_is_not_commutative :
  list_join [false] [true] <> list_join [true] [false].
Proof. cbv [list_join add_missing_bool]; discriminate. Qed.

Print Assumptions join_leq_is_partial_order.
Print Assumptions join_assign_changed_iff.
Print Assumptions bottom_is_least.
Print Assumptions two_semilattices_need_not_form_lattice.
Print Assumptions option_absorb_join_meet.
Print Assumptions explicit_worklist_progress.
Print Assumptions raw_sequence_join_is_not_commutative.
