(** * LatticeLaws — the four lattice laws for llattice's built-in impls

    llattice's [Lattice] trait (src/lib.rs) gives every type a `join` (least
    upper bound) and `meet` (greatest lower bound). The four laws documented in
    docs/theory/02 and docs/engineering/01-testing.md -- idempotency,
    commutativity, associativity, absorption -- are the contract every impl must
    satisfy. This file mechanizes them for the two representative built-in
    families: the numeric lattice (join = max, meet = min) modeled over the
    integers, and the boolean lattice (join = OR, meet = AND). It also proves the
    order/operation bridge that ties the algebraic definition to the ordering
    (`a <= b  <->  join a b = b`) -- obligation #26, the formal home of
    LATT-LAW-1..5.

    The exclusion of raw `f32`/`f64` is justified separately in
    [[FloatCaveat]] (LATT-FLOAT-1): a max/min candidate is lawful only on the
    NaN-free subset, which the raw Rust types cannot enforce.

    Registry: proofs/doc/lattice-invariants.tsv, LATT-LAW-1..5.
*)

From Stdlib Require Import ZArith.ZArith Bool.Bool.

Open Scope Z_scope.

(** ** The integer lattice: join = max, meet = min *)

Definition zjoin (a b : Z) : Z := Z.max a b.
Definition zmeet (a b : Z) : Z := Z.min a b.

(** LATT-LAW-1: idempotency. *)
Theorem zjoin_idempotent : forall a, zjoin a a = a.
Proof. intro a; unfold zjoin; apply Z.max_id. Qed.

Theorem zmeet_idempotent : forall a, zmeet a a = a.
Proof. intro a; unfold zmeet; apply Z.min_id. Qed.

(** LATT-LAW-2: commutativity. *)
Theorem zjoin_comm : forall a b, zjoin a b = zjoin b a.
Proof. intros; unfold zjoin; apply Z.max_comm. Qed.

Theorem zmeet_comm : forall a b, zmeet a b = zmeet b a.
Proof. intros; unfold zmeet; apply Z.min_comm. Qed.

(** LATT-LAW-3: associativity. *)
Theorem zjoin_assoc : forall a b c, zjoin (zjoin a b) c = zjoin a (zjoin b c).
Proof. intros; unfold zjoin; symmetry; apply Z.max_assoc. Qed.

Theorem zmeet_assoc : forall a b c, zmeet (zmeet a b) c = zmeet a (zmeet b c).
Proof. intros; unfold zmeet; symmetry; apply Z.min_assoc. Qed.

(** LATT-LAW-4: absorption. *)
Theorem zabsorb_join_meet : forall a b, zjoin a (zmeet a b) = a.
Proof.
  intros a b; unfold zjoin, zmeet. apply Z.max_l. apply Z.le_min_l.
Qed.

Theorem zabsorb_meet_join : forall a b, zmeet a (zjoin a b) = a.
Proof.
  intros a b; unfold zmeet, zjoin. apply Z.min_l. apply Z.le_max_l.
Qed.

(** LATT-LAW-5: the order/operation bridge -- the ordering is recoverable from
    join (and dually from meet), so the algebraic and order-theoretic views
    coincide. *)
Theorem zjoin_order_bridge : forall a b, a <= b <-> zjoin a b = b.
Proof.
  intros a b; unfold zjoin; split.
  - intro H. apply Z.max_r. exact H.
  - intro H. rewrite <- H. apply Z.le_max_l.
Qed.

Theorem zmeet_order_bridge : forall a b, a <= b <-> zmeet a b = a.
Proof.
  intros a b; unfold zmeet; split.
  - intro H. apply Z.min_l. exact H.
  - intro H. rewrite <- H. apply Z.le_min_r.
Qed.

(** ** The boolean lattice: join = OR, meet = AND *)

Definition bjoin (a b : bool) : bool := orb a b.
Definition bmeet (a b : bool) : bool := andb a b.

Theorem bjoin_idempotent : forall a, bjoin a a = a.
Proof. destruct a; reflexivity. Qed.

Theorem bmeet_idempotent : forall a, bmeet a a = a.
Proof. destruct a; reflexivity. Qed.

Theorem bjoin_comm : forall a b, bjoin a b = bjoin b a.
Proof. destruct a, b; reflexivity. Qed.

Theorem bmeet_comm : forall a b, bmeet a b = bmeet b a.
Proof. destruct a, b; reflexivity. Qed.

Theorem bjoin_assoc : forall a b c, bjoin (bjoin a b) c = bjoin a (bjoin b c).
Proof. destruct a, b, c; reflexivity. Qed.

Theorem bmeet_assoc : forall a b c, bmeet (bmeet a b) c = bmeet a (bmeet b c).
Proof. destruct a, b, c; reflexivity. Qed.

Theorem babsorb_join_meet : forall a b, bjoin a (bmeet a b) = a.
Proof. destruct a, b; reflexivity. Qed.

Theorem babsorb_meet_join : forall a b, bmeet a (bjoin a b) = a.
Proof. destruct a, b; reflexivity. Qed.

(** The boolean order bridge: `a <= b` (implication) iff `join a b = b`. *)
Theorem bjoin_order_bridge : forall a b, (implb a b = true) <-> bjoin a b = b.
Proof. destruct a, b; simpl; split; intro H; reflexivity || discriminate H. Qed.
