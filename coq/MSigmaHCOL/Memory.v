(*
  Simple memory model. Inspired by Vellvm

  Memory cells all have the same type: `CarrierA`.
 *)

From Coq.FSets Require Import
     FSetAVL
     FSetInterface
     FSetFacts
     FSetProperties
     FSetToFiniteSet
     FMapAVL
     FMapInterface
     FMapFacts.

Require Import Coq.Structures.OrderedTypeEx.
Require Import Coq.Arith.PeanoNat.
Require Import Coq.Arith.Peano_dec.
Require Import Coq.Logic.Decidable.
Require Export Coq.Sets.Ensembles.
Require Import Psatz.

Require Import ExtLib.Structures.Monads.
Require Import ExtLib.Data.Monads.OptionMonad.

Require Import Helix.MSigmaHCOL.CType.
Require Import Helix.Tactics.HelixTactics.
Require Import Helix.Util.OptionSetoid.
Require Import Helix.Util.ListUtil.

Require Import CoLoR.Util.Bool.BoolUtil.

Import MonadNotation.
Open Scope monad_scope.

Definition addr := (nat * nat) % type.
Definition null := (0, 0).

Open Scope nat_scope.

Lemma addr_dec : forall (a b : addr), {a = b} + {a <> b}.
Proof.
  intros [a1 a2] [b1 b2].
  destruct (eq_nat_dec a1 b1);
    destruct (eq_nat_dec a2 b2); subst.
  - left; reflexivity.
  - right. intros H. inversion H; subst. apply n. reflexivity.
  - right. intros H. inversion H; subst. apply n. reflexivity.
  - right. intros H. inversion H; subst. apply n. reflexivity.
Qed.

Module NM := FMapAVL.Make(Nat_as_OT).
Module Import NP := FMapFacts.WProperties_fun(Nat_as_OT)(NM).
Definition NatMap := NM.t.

Module NS := FSetAVL.Make(Nat_as_OT).
Module Import NSP := FSetProperties.WProperties_fun(Nat_as_OT)(NS).
Definition NatSet := NS.t.
Module Import NE := FSetToFiniteSet.WS_to_Finite_set(Nat_as_OT)(NS).

Definition NM_sequence
           {A:Type}
           {m} {M:Monad m}
           (mv: NM.t (m A)): m (NM.t A)
  := NM.fold
       (fun k v acc =>
          v' <- v ;;
             acc' <- acc ;;
             ret (NM.add k v' acc'))
       mv
       (ret (@NM.empty A)).

Lemma NM_NS_In {elt:Type} (k:NM.key) (m:NM.t elt):
  NM.In k m <->
  NS.In k (of_list (map fst (NM.elements  m))).
Proof.
  pose proof (NM.elements_3w m) as U.
  split; intros H.
  -
    rewrite <- NP.of_list_3 with (s:=m) in H.
    unfold NP.of_list, NP.to_list in H.
    generalize dependent (NM.elements m). intros l U H.
    induction l.
    +
      simpl in H.
      apply NP.F.empty_in_iff in H.
      tauto.
    +
      destruct a as [k' v].
      simpl in *.
      destruct (eq_nat_dec k k') as [K|NK].
      *
        (* k=k' *)
        apply NS.add_1.
        auto.
      *
        (* k!=k' *)
        apply NSP.FM.add_neq_iff; try auto.
        apply IHl.
        --
          inversion U.
          auto.
        --
          eapply NP.F.add_neq_in_iff with (x:=k').
          auto.
          apply H.
  -
    rewrite <- NP.of_list_3 with (s:=m).
    unfold NP.of_list, NP.to_list.
    generalize dependent (NM.elements m). intros l U H.
    induction l.
    +
      simpl in H.
      apply NSP.FM.empty_iff in H.
      tauto.
    +
      destruct a as [k' v].
      simpl in *.
      destruct (eq_nat_dec k k') as [K|NK].
      *
        (* k=k' *)
        apply NP.F.add_in_iff.
        auto.
      *
        (* k!=k' *)
        apply NP.F.add_neq_in_iff; auto.
        apply IHl.
        --
          inversion U.
          auto.
        --
          apply NS.add_3 in H; auto.
Qed.


Module Type MBasic (Import CT : CType).

  Definition mem_add k (v:t) := NM.add k v.
  Definition mem_delete k (m:NatMap t) := NM.remove k m.
  Definition mem_member k (m:NatMap t) := NM.mem k m.
  Definition mem_in     k (m:NatMap t) := NM.In k m.
  Definition mem_lookup k (m:NatMap t) := NM.find k m.
  Definition mem_empty := @NM.empty t.

  Definition mem_block := NatMap t.

  Definition mem_keys_lst (m:NatMap t): list nat :=
    List.map fst (NM.elements m).

  Definition mem_value_lst (m:NatMap t): list t :=
    List.map snd (NM.elements m).

  Definition mem_keys_set (m: mem_block): NatSet :=
    NSP.of_list (mem_keys_lst m).

  Definition mem_block_of_list (lst:list t): mem_block :=
    let fix f l n m :=
        match l with
        | nil => m
        | (x::xs) => f xs (S n) (mem_add n x m)
        end
    in
    f lst 0 (mem_empty).

  (* forcefull union of two memory blocks. conflicts are resolved by
   giving preference to elements of the 1st block *)
  Definition mem_union (m1 m2 : mem_block) : mem_block
    := NM.map2 (fun mx my =>
                  match mx with
                  | Some x => Some x
                  | None => my
                  end) m1 m2.

  Definition is_disjoint (a b: NatSet) : bool :=
    NS.is_empty (NS.inter a b).

  Lemma is_disjoint_Disjoint (s s' : NS.t)
    : Ensembles.Disjoint NS.elt (NE.mkEns s) (NE.mkEns s') <-> is_disjoint s s' = true.
  Proof.
    split.
    -
      intros E.
      destruct E as [E].
      unfold is_disjoint.
      apply NS.is_empty_1.
      unfold NS.Empty.
      intros a.
      specialize (E a).
      intros H.
      rewrite NE.In_In in H.
      apply NE.inter_Intersection in H.
      congruence.
    -
      intros D.
      unfold is_disjoint in D.
      apply NS.is_empty_2 in D.
      apply NE.Empty_Empty_set in D.
      apply Disjoint_intro.
      intros x E.
      unfold Ensembles.In in E.
      apply NE.inter_Intersection in E.
      unfold Ensembles.In in E.
      apply D in E. clear D.
      apply Constructive_sets.Noone_in_empty in E.
      tauto.
  Qed.

  Lemma is_disjoint_sym {a b}:
    is_disjoint a b = is_disjoint b a .
  Proof.
    destruct (is_disjoint a b) eqn:AB;
      destruct (is_disjoint a b) eqn:BA; try inversion AB.
    -
      clear AB.
      symmetry.
      rewrite <- is_disjoint_Disjoint.
      rewrite <- is_disjoint_Disjoint in BA.
      apply Disjoint_intro.
      intros x.
      destruct BA as [BA].
      specialize (BA x).
      intros AB.
      contradict BA.
      apply Constructive_sets.Intersection_inv in AB.
      destruct AB as [A B].
      unfold Ensembles.In.
      apply Intersection_intro; auto.
    -
      clear AB. rename BA into AB.
      symmetry.
      apply not_true_is_false.
      rewrite <- is_disjoint_Disjoint.
      apply BoolUtil.false_not_true in AB.
      rewrite <- is_disjoint_Disjoint in AB.
      intros BA.
      contradict AB.
      apply Disjoint_intro.
      intros x.
      destruct BA as [BA].
      specialize (BA x).
      intros AB.
      contradict BA.
      apply Constructive_sets.Intersection_inv in AB.
      destruct AB as [A B].
      unfold Ensembles.In.
      apply Intersection_intro; auto.
  Qed.

  Definition mem_merge (a b: mem_block) : option mem_block
    :=
      let kx := mem_keys_set a in
      let ky := mem_keys_set b in
      if is_disjoint kx ky
      then Some (mem_union a b)
      else None.

  (* merge two memory blocks using given operation to combine values *)
  Definition mem_merge_with (f: t -> t -> t): mem_block -> mem_block -> mem_block
    :=
      NM.map2 (fun a b =>
                 match a,b with
                 | None, None => None
                 | Some x, None => Some x
                 | None, Some y => Some y
                 | Some x, Some y => Some (f x y)
                 end).

  (* Combine non-empty elements of two memory blocks using given operation.
   Unlike [mem_merge_with], combining [Some _] and [None] results in [None].
   *)
  Definition mem_map2 (f: t -> t -> t): mem_block -> mem_block -> mem_block
    := NM.map2 (liftM2 f).

  (* merge two memory blocks in (0..n-1) using given operation to combine values *)
  Definition mem_merge_with_def
             (f: t -> t -> t)
             (default: t)
    : mem_block -> mem_block -> mem_block
    :=
      NM.map2 (fun a b =>
                 match a,b with
                 | None, None => None
                 | Some x, None => Some (f x default)
                 | None, Some y => Some (f default y)
                 | Some x, Some y => Some (f x y)
                 end).

  (* block of memory with indices (0..n-1) set to `v` *)
  Fixpoint mem_const_block (n:nat) (v: t) : mem_block
    :=
      match n with
      | O => mem_empty
      | S n' => mem_add n' v (mem_const_block n' v)
      end.

  (* ------------------ Proofs below ------------------- *)

  Lemma mem_keys_set_In (k:NM.key) (m:mem_block):
    NM.In k m <-> NS.In k (mem_keys_set m).
  Proof.
    apply NM_NS_In.
  Qed.

  Lemma mem_keys_set_in_union_dec
        (m0 m1 : mem_block)
        (k : NM.key):
    NS.In k (mem_keys_set (mem_union m0 m1)) ->
    {NS.In k (mem_keys_set m1)}+{NS.In k (mem_keys_set m0)}.
  Proof.
    intros H.
    unfold mem_union in H.
    apply mem_keys_set_In, NM.map2_2 in H.
    rewrite 2!NP.F.mem_in_iff in H.
    apply orb_true_intro, orb_true_elim in H.
    inversion H; [right|left] ;
      apply mem_keys_set_In, NP.F.mem_in_iff;
      auto.
  Qed.

  Lemma mem_union_as_Union
        (m m0 m1 : mem_block)
        (MM : mem_union m0 m1 = m)
        (k:NM.key)
    :
      mem_in k m <-> ((mem_in k m0) \/ (mem_in k m1)).
  Proof.
    split.
    -
      intros H.
      subst m.
      unfold mem_union in H.
      apply F.in_find_iff in H.
      erewrite F.map2_1bis in H; try reflexivity.
      break_match_hyp.
      +
        left.
        apply F.in_find_iff.
        eapply Some_ne_None.
        eauto.
      +
        right.
        clear Heqo.
        apply F.in_find_iff.
        apply H.
    -
      intros [H1 | H2];
        subst m;
        unfold mem_union;
        apply F.in_find_iff;
        erewrite F.map2_1bis; try reflexivity; break_match; try some_none.
      +
        apply F.in_find_iff in H1.
        congruence.
      +
        apply F.in_find_iff in H2.
        assumption.
  Qed.

  Lemma mem_union_key_dec
        (m m0 m1 : mem_block)
        (MM : mem_union m0 m1 = m)
        (k:NM.key)
    :
      (NM.In k m -> {NM.In k m0}+{NM.In k m1}) *
      ({NM.In k m0}+{NM.In k m1} -> NM.In k m).
  Proof.
    split; intros H; subst m; unfold mem_union in *.
    -
      apply F.in_find_iff in H.
      erewrite F.map2_1bis in H; try reflexivity.
      break_match.
      +
        left.
        apply F.in_find_iff.
        eapply Some_ne_None.
        eauto.
      +
        right.
        apply F.in_find_iff.
        assumption.
    -
      apply F.in_find_iff.
      erewrite F.map2_1bis.
      +
        destruct H.
        *
          break_match; try some_none.
          apply F.in_find_iff in i.
          congruence.
        *
          break_match; try some_none.
          apply F.in_find_iff in i.
          assumption.
      +
        reflexivity.
  Qed.

  Lemma mem_merge_key_dec
        (m m0 m1 : mem_block)
        (MM : mem_merge m0 m1 = Some m)
        (k:NM.key)
    :
      (NM.In k m -> {NM.In k m0}+{NM.In k m1}) *
      ({NM.In k m0}+{NM.In k m1} -> NM.In k m).
  Proof.
    split.
    -
      intros H.
      rename m into mm.
      destruct (NP.F.In_dec m1 k) as [M1 | M1], (NP.F.In_dec m0 k) as [M0|M0]; auto.
      exfalso. (* Could not be in neither. *)
      unfold mem_merge in MM.
      break_if; inversion MM.
      subst mm. clear MM.
      rewrite mem_keys_set_In in M0, M1.
      clear Heqb.
      apply mem_keys_set_In, mem_keys_set_in_union_dec in H.
      destruct H; auto.
    -
      intros H.
      rename m into mm.
      unfold mem_merge, mem_union in MM.
      break_if; try some_none.
      some_inv.
      clear H1 mm.
      apply F.in_find_iff.
      rewrite F.map2_1bis by reflexivity.
      break_match.
      some_none.
      destruct H as [H | H].
      apply F.in_find_iff in H; congruence.
      apply F.in_find_iff, H.
  Qed.

  Lemma mem_merge_key_not_in
        (m m0 m1 : mem_block)
        (MM : mem_merge m0 m1 = Some m)
        (k: NM.key)
    :
      (not (NM.In k m)) <-> (not (NM.In k m0)) /\ (not (NM.In k m1)).
  Proof.
    split.
    -
      intros H.
      unfold mem_merge in MM.
      break_if; inversion MM.
      clear MM Heqb.
      subst m.
      unfold mem_union in H.
      remember
        (fun mx my : option t =>
           match mx with
           | Some x => Some x
           | None => my
           end) as f.

      pose proof (F.map2_1bis) as F.
      assert(FN: f None None = None) by (subst f; reflexivity).
      specialize (F _ _ t m0 m1 k f FN). clear FN.
      apply F.not_find_in_iff in H.
      rewrite F in H. clear F.
      subst f.
      break_match.
      inversion H.
      split.
      apply F.not_find_in_iff in Heqo; auto.
      apply F.not_find_in_iff in H; auto.
    -
      intros [H0 H1].
      intros H.
      apply mem_merge_key_dec with (m0:=m0) (m1:=m1) in H; auto.
      crush.
  Qed.

  Lemma decidable_mem_in (k:NM.key) (m:mem_block): decidable (mem_in k m).
  Proof.
    unfold decidable.
    destruct (NP.F.In_dec m k); auto.
  Qed.

  Lemma mem_keys_disjoint_inr
        (m1 m2: mem_block)
        (k: NM.key):
    is_disjoint (mem_keys_set m1) (mem_keys_set m2) = true
    -> mem_in k m1 -> not (mem_in k m2).
  Proof.
    intros D M1 M2.
    apply mem_keys_set_In in M1.
    apply mem_keys_set_In in M2.
    generalize dependent (mem_keys_set m1).
    generalize dependent (mem_keys_set m2).
    intros s1 M1 s2 D M2.
    clear m1 m2.
    apply is_disjoint_Disjoint in D.
    rewrite NE.In_In in M1.
    rewrite NE.In_In in M2.
    destruct D as [D].
    specialize (D k).
    contradict D.
    unfold Ensembles.In.
    apply Intersection_intro; auto.
  Qed.


  (* TODO: could be proven <-> *)
  Lemma mem_merge_is_Some
        (m0 m1 : mem_block)
    :
      Ensembles.Disjoint nat (NE.mkEns (mem_keys_set m0))
                         (NE.mkEns (mem_keys_set m1)) -> (mem_merge m0 m1 <> None).
  Proof.
    unfold mem_merge.
    unfold mem_keys_set.
    generalize (NSP.of_list (mem_keys_lst m0)) as s0.
    generalize (NSP.of_list (mem_keys_lst m1)) as s1.
    intros s1 s0 H.
    break_if.
    -
      crush.
    -
      apply is_disjoint_Disjoint in H.
      congruence.
  Qed.

  Lemma Disjoint_of_mem_merge
        {m0 m1 m2 m3: mem_block}
        (M: mem_merge m2 m3 = @Some mem_block m1)
        (D1: Ensembles.Disjoint nat (NE.mkEns (mem_keys_set m0)) (NE.mkEns (mem_keys_set m2)))
        (D2: Ensembles.Disjoint nat (NE.mkEns (mem_keys_set m0)) (NE.mkEns (mem_keys_set m3))):
    Ensembles.Disjoint nat (NE.mkEns (mem_keys_set m0)) (NE.mkEns (mem_keys_set m1)).
  Proof.
    apply Disjoint_intro.
    intros k C.
    apply mem_merge_key_dec with (k:=k) in M.
    -
      destruct C as [k C1 C2].
      destruct M as [[M2| M3] _].
      +
        apply mem_keys_set_In in C2.
        apply C2.
      +
        (* k in `m2` *)
        clear D2.
        apply mem_keys_set_In in M2.
        destruct D1 as [D]; specialize (D k).
        contradict D.
        apply Intersection_intro.
        apply C1.
        apply M2.
      +
        (* k in `m1` *)
        clear D1.
        apply mem_keys_set_In in M3.
        destruct D2 as [D]; specialize (D k).
        contradict D.
        apply Intersection_intro.
        apply C1.
        apply M3.
  Qed.

  Lemma mem_merge_as_Union
        (m m0 m1 : mem_block)
        (k: nat)
    :
      mem_merge m0 m1 = Some m ->
      (mem_in k m <->
       ((mem_in k m0) \/ (mem_in k m1))).
  Proof.
    intros M.
    split; intros H.
    -
      unfold mem_in, mem_merge, mem_union in *.
      break_if; try some_none.
      some_inv.
      apply NP.F.in_find_iff in H.
      rewrite <- H1 in H. clear H1.
      rewrite NP.F.map2_1bis in H by reflexivity.
      repeat break_match; try some_none.
      +
        left.
        apply NP.F.in_find_iff.
        rewrite Heqo.
        some_none.
      +
        right.
        apply NP.F.in_find_iff.
        apply H.
    -
      unfold mem_in, mem_merge, mem_union in *.
      break_if; try some_none.
      some_inv. clear m H1.
      apply F.in_find_iff.
      destruct H.
      rewrite NP.F.map2_1bis by reflexivity.
      repeat break_match; try some_none.
      +
        apply F.in_find_iff in H.
        congruence.
      +
        rewrite NP.F.map2_1bis by reflexivity.
        repeat break_match; try some_none.
        apply NP.F.in_find_iff, H.
  Qed.

  Lemma mem_merge_to_mem_union
        (m m0 m1 : mem_block)
    :
      mem_merge m0 m1 = Some m ->
      mem_union m0 m1 = m.
  Proof.
    intros H.
    unfold mem_merge in H.
    break_if; try some_none.
    apply Some_inj_eq.
    apply H.
  Qed.

  Lemma mem_merge_with_as_Union
        (dot : t -> t -> t)
        (m1 m2 : mem_block)
        (k:nat)
    :
      ((mem_in k m1) \/ (mem_in k m2)) <->
      mem_in k (mem_merge_with dot m1 m2).
  Proof.
    split.
    --
      intros H.
      destruct (NP.F.In_dec m1 k) as [M1 | M1], (NP.F.In_dec m2 k) as [M0|M0];
        unfold mem_in, mem_merge_with in *;
        apply NP.F.in_find_iff;
        rewrite NM.map2_1; try apply H;

          rewrite mem_keys_set_In in M0, M1;
          repeat break_match; try some_none;
            apply NP.F.not_find_in_iff in Heqo;
            apply NP.F.not_find_in_iff in Heqo0;
            crush.
    --
      intros H.
      unfold mem_in, mem_merge_with in *.
      apply NP.F.in_find_iff in H.
      rewrite NP.F.map2_1bis in H by reflexivity.
      repeat break_match; try some_none;
        try apply Some_ne_None, NP.F.in_find_iff in Heqo;
        try apply Some_ne_None, NP.F.in_find_iff in Heqo0; crush.
  Qed.

  Lemma mem_merge_with_def_as_Union
        (dot : t -> t -> t)
        (initial: t)
        (m1 m2 : mem_block)
        (k:nat)
    :
      ((mem_in k m1) \/ (mem_in k m2)) <->
      mem_in k (mem_merge_with_def dot initial m1 m2).
  Proof.
    split.
    --
      intros H.
      destruct (NP.F.In_dec m1 k) as [M1 | M1], (NP.F.In_dec m2 k) as [M0|M0];
        unfold mem_in, mem_merge_with_def in *;
        apply NP.F.in_find_iff;
        rewrite NM.map2_1; try apply H;

          rewrite mem_keys_set_In in M0, M1;
          repeat break_match; try some_none;
            apply NP.F.not_find_in_iff in Heqo;
            apply NP.F.not_find_in_iff in Heqo0;
            crush.
    --
      intros H.
      unfold mem_in, mem_merge_with_def in *.
      apply NP.F.in_find_iff in H.
      rewrite NP.F.map2_1bis in H by reflexivity.
      repeat break_match; try some_none;
        try apply Some_ne_None, NP.F.in_find_iff in Heqo;
        try apply Some_ne_None, NP.F.in_find_iff in Heqo0; crush.
  Qed.

  Lemma mem_merge_with_not_as_Union
        (dot : t -> t -> t)
        (m1 m2 : mem_block)
        (k:nat)
    :
      (not (mem_in k m1)) -> (not (mem_in k m2)) ->
      not (mem_in k (mem_merge_with dot m1 m2)).
  Proof.
    intros H0 H1 H.
    apply mem_merge_with_as_Union in H.
    crush.
  Qed.

  Lemma mem_const_block_find
        (n : nat)
        (v : t)
        (j : nat):
    (j < n) -> (NM.find j (mem_const_block n v) = Some v).
  Proof.
    intros jc.
    induction n.
    -
      nat_lt_0_contradiction.
    -
      simpl.
      destruct (eq_nat_dec j n) as [N | NN].
      +
        subst.
        rewrite F.add_eq_o; reflexivity.
      +
        rewrite F.add_neq_o; auto.
        apply IHn.
        lia.
  Qed.

  Lemma mem_const_block_In_oob
        (n : nat)
        (v : t)
        (j : nat):
    (j >= n) -> (not (NM.In j (mem_const_block n v))).
  Proof.
    intros jc.
    induction n.
    -
      simpl.
      unfold mem_empty.
      intros C.
      apply F.empty_in_iff in C.
      tauto.
    -
      simpl.
      unfold mem_add.
      intros C.
      apply F.add_in_iff in C.
      destruct C.
      +
        crush.
      +
        crush.
  Qed.

  Lemma mem_const_block_find_oob
        (n : nat)
        (v : t)
        (j : nat):
    (j >= n) -> (NM.find j (mem_const_block n v) = None).
  Proof.
    intros jc.
    apply F.not_find_in_iff.
    apply mem_const_block_In_oob.
    apply jc.
  Qed.


  Section Memory_Blocks.

    (* memory is a map of memory blocks *)
    Definition memory := NatMap mem_block.

    Definition memory_empty : memory := NM.empty _.

    (* Memory block address *)
    Definition mem_block_id := nat.

    Definition memory_lookup
               (m: memory)
               (n: mem_block_id)
      : option mem_block
      := NM.find n m.

    Definition memory_set
               (m: memory)
               (n: mem_block_id)
               (v: mem_block)
      : memory
      :=
        NM.add n v m.

    Definition memory_remove
               (m: memory)
               (n: mem_block_id)
      : memory
      :=
        NM.remove n m.


    (* memory [m] has block [b] under id [n] *)
    Definition memory_mapsto (m : memory) (n : mem_block_id) (b : mem_block) :=
      NM.MapsTo (elt:=mem_block) n b m.

    Definition mem_block_exists: mem_block_id -> memory -> Prop
      := NM.In (elt:=mem_block).

    Lemma decidable_mem_block_exists (k:NM.key) (m:memory): decidable (mem_block_exists k m).
    Proof.
      unfold decidable.
      destruct (NP.F.In_dec m k); auto.
    Qed.

    Definition memory_keys_lst (m:memory): list nat :=
      List.map fst (NM.elements m).

    Definition memory_keys_set (m: memory): NatSet :=
      NSP.of_list (memory_keys_lst m).

    (* Returns block ID which is guaraneed to be free in [m] *)
    Definition memory_next_key
               (m: memory): mem_block_id
      :=  match NS.max_elt (memory_keys_set m) with
          | None => 0
          | Some k => S k
          end.

    Lemma mem_block_exists_exists (m:memory) (k:nat):
      mem_block_exists k m <-> exists y : mem_block, memory_lookup m k = Some y.
    Proof.
      split; intros H.
      -
        apply NP.F.in_find_iff, is_Some_ne_None, MathClasses.misc.util.is_Some_def in H.
        apply H.
      -
        apply NP.F.in_find_iff, is_Some_ne_None, MathClasses.misc.util.is_Some_def.
        apply H.
    Qed.

    Lemma mem_block_not_exists_exists (m:memory) (k:nat):
      not (mem_block_exists k m) <-> memory_lookup m k = None.
    Proof.
      split; intros H; unfold mem_block_exists in *.
      -
        apply F.not_find_in_iff, H.
      -
        intros H1.
        unfold memory_lookup in H.
        apply F.not_find_in_iff in H1; congruence.
    Qed.

    Lemma memory_is_set_is_Some (m:memory) (k:mem_block_id):
      mem_block_exists k m <-> MathClasses.misc.util.is_Some (memory_lookup m k).
    Proof.
      unfold mem_block_exists, memory_lookup, MathClasses.misc.util.is_Some.
      split; intros H.
      -
        apply NP.F.in_find_iff in H.
        break_match; auto.
      -
        apply NP.F.in_find_iff.
        break_match_hyp; auto.
        some_none.
    Qed.

    Lemma mem_block_exists_memory_remove (k:mem_block_id) (m:memory):
      not (mem_block_exists k (memory_remove m k)).
    Proof.
      unfold mem_block_exists, memory_remove.
      apply NM.remove_1.
      reflexivity.
    Qed.

    Lemma mem_block_exists_memory_remove_neq
          {k k' m}
          (NK:k <> k'):
      mem_block_exists k m <-> mem_block_exists k (memory_remove m k').
    Proof.
      unfold mem_block_exists, memory_remove.
      split; intros H.
      -
        apply NP.F.remove_neq_in_iff; auto.
      -
        apply NP.F.remove_neq_in_iff in H; auto.
    Qed.

    Lemma mem_block_exists_memory_set {k k' m v}:
      mem_block_exists k m ->
      mem_block_exists k (memory_set m k' v).
    Proof.
      unfold mem_block_exists, memory_set.
      intros H.
      destruct (Nat.eq_dec k k').
      -
        apply NP.F.add_in_iff.
        left.
        auto.
      -
        apply NP.F.add_in_iff.
        right.
        auto.
    Qed.

    Lemma mem_block_exists_memory_set_inv {k k' m v}:
      mem_block_exists k (memory_set m k' v) ->
      ((mem_block_exists k m) \/ k=k').
    Proof.
      unfold mem_block_exists, memory_set.
      intros H.
      destruct (Nat.eq_dec k k') as [kc|kc].
      -
        right.
        assumption.
      -
        left.
        apply F.add_in_iff in H.
        destruct H.
        +
          congruence.
        +
          apply H.
    Qed.

    Lemma mem_block_exists_memory_set_eq
          {k k' m v}
          (NK:k = k'):
      mem_block_exists k (memory_set m k' v).
    Proof.
      unfold mem_block_exists, memory_set.
      apply F.add_in_iff.
      auto.
    Qed.

    Lemma mem_block_exists_memory_set_neq
          {k k' m v}
          (NK:k <> k'):
      mem_block_exists k m <-> mem_block_exists k (memory_set m k' v).
    Proof.
      unfold mem_block_exists, memory_set.
      split; intros H.
      -
        apply NP.F.add_neq_in_iff; auto.
      -
        apply NP.F.add_neq_in_iff in H; auto.
    Qed.

    Lemma memory_keys_set_In (k:NM.key) (m:memory):
      NM.In k m <-> NS.In k (memory_keys_set m).
    Proof.
      apply NM_NS_In.
    Qed.

    Lemma memory_next_key_S m n:
      memory_next_key m = S n ->
      mem_block_exists n m.
    Proof.
      intros H.
      unfold memory_next_key in H.
      break_match_hyp ; inv H.
      apply memory_keys_set_In.
      apply Memory.NS.max_elt_1.
      auto.
    Qed.

    Lemma mem_block_exists_memory_next_key
          (m : memory):
      not (mem_block_exists (memory_next_key m) m).
    Proof.
      unfold mem_block_exists, memory_next_key.
      break_match; rename Heqo into H.
      -
        rewrite memory_keys_set_In.
        revert H.
        generalize (memory_keys_set m) as ms.
        intros ms H C.
        clear m.
        apply NS.max_elt_2  with (y:=S e) in H; auto.
      -

        apply NS.max_elt_3 in H.
        rewrite memory_keys_set_In.
        apply MP.empty_is_empty_1 in H.
        unfold NS.Equal in *.
        intros C.
        apply H in C.
        apply FM.empty_iff in C.
        congruence.
    Qed.

    Lemma mem_block_exists_next_key_gt:
      forall k m, mem_block_exists k m -> memory_next_key m > k.
    Proof.
      intros k m H.
      unfold mem_block_exists in H.
      unfold memory_next_key.
      apply memory_keys_set_In in H.
      generalize dependent (memory_keys_set m).
      intros s H.
      clear m.
      break_match.
      -
        apply NS.max_elt_2 with (y:=k) in Heqo.
        lia.
        apply H.
      -
        rename Heqo into E.
        apply NS.max_elt_3 in E.
        apply empty_is_empty_1 in E.
        rewrite E in H.
        apply FM.empty_iff in H.
        inversion H.
    Qed.

    Lemma memory_set_memory_next_key_gt m1 m2 b k:
      m2 = memory_set m1 k b ->
      memory_next_key m2 > k.
    Proof.
      intros H.

      assert(mem_block_exists k m2) as E.
      {
        subst m2.
        apply mem_block_exists_memory_set_eq; reflexivity.
      }
      apply mem_block_exists_next_key_gt, E.
    Qed.

    Lemma memory_lookup_memory_next_key_is_None (m:memory):
      MathClasses.misc.util.is_None (memory_lookup m (memory_next_key m)).
    Proof.
      pose proof (mem_block_exists_memory_next_key m) as P.
      apply mem_block_not_exists_exists in P.
      unfold MathClasses.misc.util.is_None.
      break_match; try some_none; auto.
    Qed.

    (* Also there is an [equiv] version elsewhere *)
    Lemma memory_lookup_not_next {m k v}:
      memory_lookup m k = Some v ->
      k <> memory_next_key m.
    Proof.
      intros H.
      destruct (eq_nat_dec k (memory_next_key m)) as [E|NE]; [exfalso|auto].
      rewrite E in H.
      pose proof (memory_lookup_memory_next_key_is_None m) as N.
      rewrite H in N.
      some_none.
    Qed.

    Lemma memory_mapsto_memory_lookup k v m:
      memory_mapsto m k v <-> memory_lookup m k = Some v.
    Proof.
      unfold memory_mapsto, memory_lookup.
      split.
      - apply NM.find_1.
      - apply NM.find_2.
    Qed.

  End Memory_Blocks.

End MBasic.
