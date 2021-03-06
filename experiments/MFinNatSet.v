Require Import Specif.
Require Import Orders.
Require Import OrdersEx.
Require Import MSets.
Require Import Arith.
Require Import Omega.

Module NatSet := Make Nat_as_OT.
Module NatSetFacts := Facts NatSet.

Section MSet_set.

  Import NatSet.

  Definition has_upper_bound n
    := For_all (gt n).

  Definition MFinNatSet (n:nat) : Type
    := {s: t | has_upper_bound n s}.

  Definition MsingleS (n:nat) (i:nat): MFinNatSet n.
  Proof.
    unfold MFinNatSet.
    case (lt_dec i n); intros H.
    -
      exists (singleton i).
      unfold has_upper_bound, For_all.
      intros x I.
      apply singleton_spec in I.
      omega.
    -
      exists empty.
      unfold has_upper_bound, For_all.
      intros x I.
      apply empty_spec in I.
      contradiction.
  Defined.

  Example MFoo: Empty (inter
                         (proj1_sig (MsingleS 5 2))
                         (proj1_sig (MsingleS 5 1))).
  Proof.
    simpl.
    unfold Empty.
    intros a H.
    apply inter_spec in H.
    destruct H as [H1 H2].
    apply singleton_spec in H1.
    apply singleton_spec in H2.
    congruence.
  Qed.


  (* Unbounded version *)
  Fixpoint NatSet_indexf (n:nat) (f: nat -> bool): NatSet.t :=
    match n with
    | O => empty
    | S j => union
              (if f j then singleton j else empty)
              (NatSet_indexf j f)
    end.


  Lemma empty_upper_bound:
    has_upper_bound 0 empty.
  Proof.
    unfold has_upper_bound.
    unfold For_all.
    intros x H.
    apply empty_spec in H.
    contradiction.
  Qed.

  Lemma lt_gt:
    forall m n, m < n <-> n > m.
  Proof.
    intros m n.
    split; intros;omega.
  Qed.


  Lemma max_lb_l: forall n m p : nat, n > p -> max n m > p.
  Proof.
    intros n m p H.
    assert (D: n < m /\ Nat.max n m = m \/ m <= n /\ Nat.max n m = n) by apply Max.max_spec.
    destruct D; omega.
  Qed.

  Lemma max_lb_r: forall n m p : nat, m > p -> max n m > p.
  Proof.
    intros n m p H.
    assert (D: n < m /\ Nat.max n m = m \/ m <= n /\ Nat.max n m = n) by apply Max.max_spec.
    destruct D; omega.
  Qed.

  Lemma union_upper_bound
        (ba bb:nat)
        (a b: t):
    has_upper_bound ba a -> has_upper_bound bb b ->
    has_upper_bound (max ba bb) (union a b).
  Proof.
    intros A B.
    unfold has_upper_bound, For_all in *.
    intros x I.
    specialize (A x).
    specialize (B x).
    rewrite union_spec in *.
    destruct I as [IA | IB].
    -
      apply A in IA.
      apply max_lb_l, IA.
    -
      apply B in IB.
      apply max_lb_r, IB.
  Qed.

  Lemma singleton_upper_bound:
    forall n, has_upper_bound (S n) (singleton n).
  Proof.
    intros n.
    unfold has_upper_bound, For_all.
    intros x H.
    apply singleton_spec in H.
    omega.
  Qed.

  Lemma weaken_upper_bound:
    forall s n m, m>=n -> has_upper_bound n s -> has_upper_bound m s.
  Proof.
    intros s n m D U.
    unfold has_upper_bound, For_all in *.
    intros x H.
    specialize (U x H).
    omega.
  Qed.

  Lemma max_sn_n:
    forall n : nat, Init.Nat.max (S n) n = S n.
  Proof.
    intros n.
    induction n.
    reflexivity.
    rewrite <- IHn at 3.
    rewrite Max.succ_max_distr.
    reflexivity.
  Qed.

  Definition build_FinNatSet (n:nat) (f: nat -> bool): MFinNatSet n.
  Proof.
    exists (NatSet_indexf n f).
    induction n.
    -
      apply empty_upper_bound.
    -
      simpl.
      replace (S n) with (max (S n) n).
      apply union_upper_bound.
      case (f n).
      + apply singleton_upper_bound.
      + assert (E: has_upper_bound 0 empty) by apply empty_upper_bound.
        apply weaken_upper_bound with (m:=S n) in E.
        apply E.
        omega.
      + apply IHn.
      + apply max_sn_n.
  Defined.

  Definition full_set (n:nat) (m b:nat): MFinNatSet n :=
    build_FinNatSet n (fun _ => true).


End MSet_set.
