
Require Import VecUtil.
Require Import VecSetoid.
Require Import Spiral.
Require Import Rtheta.

Require Import Coq.Bool.Bool.
Require Import Arith.
Require Import Coq.Logic.FunctionalExtensionality.

Require Import CpdtTactics.
Require Import JRWTactics.
Require Import SpiralTactics.

Require Import MathClasses.interfaces.canonical_names.
Require Import MathClasses.interfaces.abstract_algebra.

Import VectorNotations.

Require Import ExtLib.Structures.Monads.
Require Import WriterMonadNoT.

Open Scope vector_scope.
Open Scope nat_scope.

(* "sparse" vector for CarrierA type elements could be simulated using Rtheta *)
Notation svector n := (vector Rtheta n) (only parsing).

(* Construct vector of Rtheta values from vector of raw values of it's carrier type *)
Definition sparsify {n} (v:avector n): svector n :=
  Vmap mkValue v.

Global Instance sparsify_proper {n:nat}:
  Proper ((=) ==> (=)) (@sparsify n).
Proof.
  intros x y E.
  unfold sparsify.
  rewrite E.
  reflexivity.
Qed.

(* Project out carrier type values from vector of Rheta values *)
Definition densify {n} (v:svector n): avector n :=
  Vmap (A:=Rtheta) (@evalWriter _ _ _) v.

Global Instance densify_proper {n:nat}:
  Proper ((=) ==> (=)) (@densify n).
Proof.
  intros x y E.
  unfold densify.
  rewrite E.
  reflexivity.
Qed.

(* Construct "Zero svector". All values are structural zeros. *)
Definition szero_svector n: svector n := Vconst mkSZero n.

(* "dense" vector means that it does not contain "structural" values *)
Definition svector_is_dense {n} (v:svector n) : Prop :=
  Vforall Is_Val v.

Local Open Scope bool_scope.

Set Implicit Arguments.

Lemma Vnth_sparsify:
  ∀ (n i : nat) (ip : i < n) (v : vector CarrierA n),
    Vnth (sparsify v) ip ≡ mkValue (Vnth v ip).
Proof.
  intros n i ip v.
  unfold sparsify.
  apply Vnth_map.
Qed.

Section PartialMonoids.

  (** Inductive type, restricting set to elements with either:
 1. Special value 'one' (neutral element)
 2. Elements of parent set, satisfying given predicate 'restrict'
 3. Is a result of apply binary operation 'dot' to 2 other elements from the same restricted set (closed under 'dot'
   *)
  Inductive IMonoidRestriction {A:Type}
            (dot : A -> A -> A) (one : A)
            (pred: A -> Prop)
  :
    A -> Prop  :=
  | im_restr_one: IMonoidRestriction dot one pred one
  | im_restr_new a: pred a -> IMonoidRestriction dot one pred a
  | im_restr_close a b: IMonoidRestriction dot one pred a -> IMonoidRestriction dot one pred b -> IMonoidRestriction dot one pred (dot a b).


  Class IMonoid {A:Type} `{!Equiv A}
        (pred: A -> Prop)
        (dot : A -> A -> A) (one : A)
    := {
        idot_assoc: forall x y z, IMonoidRestriction dot one pred x ->
                             IMonoidRestriction dot one pred y ->
                             IMonoidRestriction dot one pred z ->
                             dot x (dot y z) = dot (dot x y) z;
        ione_left: forall x, IMonoidRestriction dot one pred x -> dot one x = x;
        ione_right: forall x, IMonoidRestriction dot one pred x -> dot x one = x
      }.

End PartialMonoids.

Definition Union (dot : CarrierA -> CarrierA -> CarrierA)
  : Rtheta -> Rtheta -> Rtheta := liftM2 dot.

Lemma Union_comm (dot : CarrierA -> CarrierA -> CarrierA)
      `{C: !Commutative dot}:
  Commutative (Union dot).
Proof.
  intros x y.
  unfold Union, equiv, Rtheta_equiv.
  rewrite 2!evalWriter_Rtheta_liftM2.
  apply C.
Qed.

Lemma evalWriterUnion {a b: Rtheta} {dot}:
  evalWriter (Union dot a b) =
  dot (evalWriter a)
      (evalWriter b).
Proof.
  unfold Union.
  rewrite evalWriter_Rtheta_liftM2.
  reflexivity.
Qed.

Global Instance Union_proper:
  Proper (((=) ==> (=) ==> (=)) ==> (=) ==> (=) ==> (=)) Union.
Proof.
  intros dot dot' DP a b H x y E.
  unfold Union, equiv, Rtheta_equiv in *.
  rewrite 2!evalWriter_Rtheta_liftM2.
  apply DP.
  apply H.
  apply E.
Qed.

(* Unary union of vector's elements (left fold) *)
Definition VecUnion
           {n}
           (dot:CarrierA->CarrierA->CarrierA)
           (neutral:CarrierA)
           (v: svector n): Rtheta :=
  Vfold_left_rev (Union dot) (mkStruct neutral) v.

(* Binary element-wise union of two vectors *)
Definition Vec2Union
           {n}
           (dot:CarrierA->CarrierA->CarrierA)
           (a b: svector n): svector n
  := Vmap2 (Union dot) a b.

Global Instance Vec2Union_proper {n}
  :
    Proper (((=) ==> (=) ==> (=)) ==> (=) ==> (=) ==> (=)) (Vec2Union (n:=n)).
Proof.
  intros dot dot' Ed a a' Ea b b' Eb.
  unfold Vec2Union, Union.
  (* TODO: vec_index_equiv from VecSetoid. Move all vector-related stuff there *)
  unfold equiv, vec_Equiv; apply Vforall2_intro_nth; intros j jc.
  rewrite 2!Vnth_map2.
  unfold_Rtheta_equiv.
  rewrite 2!evalWriter_Rtheta_liftM2.
  apply Ed; apply evalWriter_proper; apply Vnth_arg_equiv; assumption.
Qed.


(* Matrix-union. Generalized SumUnion *)
Definition MUnion
           {o n}
           (dot:CarrierA->CarrierA->CarrierA)
           (neutral:CarrierA)
           (v: vector (svector o) n): svector o
  :=  Vfold_left_rev (Vec2Union dot) (Vconst (mkStruct neutral) o) v.

Global Instance MUnion_proper {o n}
  : Proper (((=) ==> (=) ==> (=)) ==> (=) ==> (=) ==> (=)) (@MUnion o n).
Proof.
  intros dot dot' Ed one one' Eo x y E.
  unfold MUnion.
  rewrite 2!Vfold_left_rev_to_Vfold_left_rev_reord.
  apply Vfold_left_rev_reord_proper.
  apply Vec2Union_proper.
  apply Ed.
  rewrite 2!Vconst_to_Vconst_reord.
  apply Vconst_reord_proper.
  rewrite Eo; reflexivity.
  assumption.
Qed.

Definition SumUnion
           {o n}
           (v: vector (svector o) n): svector o
  := MUnion plus zero v.

Global Instance SumUnion_proper {o n}
  : Proper ((=) ==> (=)) (@SumUnion o n).
Proof.
  intros x y E.
  unfold SumUnion.
  rewrite E.
  reflexivity.
Qed.

Lemma VecUnion_cons
      m x (xs : svector m)
      (dot:CarrierA->CarrierA->CarrierA)
      (neutral:CarrierA):
  VecUnion dot neutral (Vcons x xs) ≡ Union dot (VecUnion dot neutral xs) x.
Proof.
  unfold VecUnion.
  rewrite Vfold_left_rev_cons.
  reflexivity.
Qed.

Lemma Vec2Union_comm
      {n}
      (dot:CarrierA->CarrierA->CarrierA)
      `{C: !Commutative dot}
  :
    @Commutative (svector n) _ (svector n) (Vec2Union dot).
Proof.
  intros a b.
  induction n.
  VOtac; reflexivity.
  VSntac a. VSntac b.
  simpl.
  rewrite 2!Vcons_to_Vcons_reord.
  apply Vcons_reord_proper.
  apply IHn.
  apply Union_comm, C.
Qed.

Lemma MUnion_cons {m n}
      (dot:CarrierA->CarrierA->CarrierA)
      (neutral:CarrierA)
      (x: svector m) (xs: vector (svector m) n):
  MUnion dot neutral (Vcons x xs) ≡ Vec2Union dot (MUnion dot neutral xs) x.
Proof.
  unfold MUnion.
  apply Vfold_left_rev_cons.
Qed.

Lemma SumUnion_cons {m n}
      (x: svector m) (xs: vector (svector m) n):
  SumUnion (Vcons x xs) ≡ Vec2Union plus (SumUnion xs) x.
Proof.
  unfold SumUnion.
  apply MUnion_cons.
Qed.

Lemma AbsorbUnionIndexBinary
      (m k : nat)
      (kc : k < m)
      {dot}
      (a b : svector m):
  Vnth (Vec2Union dot a b) kc ≡ Union dot (Vnth a kc) (Vnth b kc).
Proof.
  unfold Vec2Union.
  apply Vnth_map2.
Qed.

Lemma AbsorbMUnionIndex
      (dot:CarrierA->CarrierA->CarrierA)
      `{dot_mor: !Proper ((=) ==> (=) ==> (=)) dot}

      (neutral:CarrierA)
      {m n:nat}
      (x: vector (svector m) n) k (kc: k<m):
  Vnth (MUnion dot neutral x) kc = VecUnion dot neutral (Vmap (fun v => Vnth v kc) x).
Proof.
  induction n.
  + dep_destruct x.
    unfold VecUnion, MUnion, szero_svector; simpl.
    rewrite Vnth_const; reflexivity.
  + dep_destruct x.
    rewrite Vmap_cons, MUnion_cons, AbsorbUnionIndexBinary, IHn, VecUnion_cons.
    reflexivity.
Qed.

Lemma AbsorbSumUnionIndex
      m n (x: vector (svector m) n) k (kc: k<m):
  Vnth (SumUnion x) kc = VecUnion plus zero (Vmap (fun v => Vnth v kc) x).
Proof.
  unfold SumUnion.
  apply AbsorbMUnionIndex.
  apply CarrierAPlus_proper.
Qed.

(* Move indexing from outside of Union into the loop. Called 'union_index' in Vadim's paper notes.
TODO: rename. No actual IUnion here.
 *)
Lemma AbsorbIUnionIndex
      {o n}
      (dot:CarrierA->CarrierA->CarrierA)
      (neutral:CarrierA)
      (body: forall (i : nat) (ic : i < n), svector o)
      k (kc: k<o)
  :
    Vnth (MUnion dot neutral (Vbuild body)) kc ≡
         VecUnion dot neutral
         (Vbuild
            (fun (i : nat) (ic : i < n) =>
               Vnth (body i ic) kc
         )).
Proof.
  induction n.
  - rewrite 2!Vbuild_0.
    apply Vnth_const.
  -
    rewrite Vbuild_cons.
    rewrite MUnion_cons.
    rewrite AbsorbUnionIndexBinary.
    rewrite IHn.
    rewrite <- VecUnion_cons.
    rewrite Vbuild_cons.
    reflexivity.
Qed.

Lemma AbsorbISumUnionIndex
      {o n}
      (body: forall (i : nat) (ic : i < n), svector o)
      k (kc: k<o)
  :
    Vnth
      (SumUnion (Vbuild body)) kc ≡
      VecUnion plus zero
      (Vbuild
         (fun (i : nat) (ic : i < n) =>
            Vnth (body i ic) kc
      )).
Proof.
  apply AbsorbIUnionIndex.
Qed.


Lemma Union_SZero_r x:
  (Union plus x mkSZero) = x.
Proof.
  unfold Union.
  unfold_Rtheta_equiv.
  rewrite evalWriter_Rtheta_liftM2.
  rewrite evalWriter_Rtheta_SZero.
  ring.
Qed.

Lemma Union_SZero_l x:
  (Union plus mkSZero x) = x.
Proof.
  unfold Union.
  unfold_Rtheta_equiv.
  rewrite evalWriter_Rtheta_liftM2.
  rewrite evalWriter_Rtheta_SZero.
  ring.
Qed.

Lemma UnionCollisionFree (a b : Rtheta) {dot}:
  ¬Is_Collision a →
  ¬Is_Collision b →
  ¬(Is_Val a ∧ Is_Val b)
  → ¬Is_Collision (Union dot a b).
Proof.
  intros CA CB C.
  unfold Union, Is_Collision, compose.
  rewrite execWriter_Rtheta_liftM2.
  unfold Is_Collision, Is_Val, compose in *.
  destruct (execWriter a) as [str_a col_a].
  destruct (execWriter b) as [str_b col_b].
  unfold RthetaFlagsAppend.
  unfold IsCollision, IsVal in *.
  destr_bool.
  auto.
Qed.

(* Conditions under which Union produces value *)
Lemma ValUnionIsVal (a b : Rtheta) {dot}:
  Is_Val a \/ Is_Val b <-> Is_Val (Union dot a b).
Proof.
  split.
  - intros [VA | VB];
      (
        unfold Union, Is_Val, compose in *;
        rewrite execWriter_Rtheta_liftM2;
        destruct (execWriter a) as [str_a col_a];
        destruct (execWriter b) as [str_b col_b];
        unfold RthetaFlagsAppend;
        unfold IsVal in *;
        destr_bool; auto).
  -
    intros H.
    unfold Union, Is_Val, compose in *.
    rewrite execWriter_Rtheta_liftM2 in *.
    destruct (execWriter a) as [str_a col_a].
    destruct (execWriter b) as [str_b col_b].
    unfold IsVal in *.
    destr_bool; auto.
Qed.

Lemma Is_Val_VecUnion {n} {v: svector n} {dot} {neutral}:
  Vexists Is_Val v <-> Is_Val (VecUnion dot neutral v).
Proof.
  split.
  - intros H.
    apply Vexists_eq in H.
    unfold VecUnion.
    destruct H as [x [XI XV]].
    induction v.
    + unfold Vin in XI.
      congruence.
    + apply Vin_cons in XI.
      rewrite Vfold_left_rev_cons.
      destruct XI.
      * subst h.
        apply ValUnionIsVal.
        right.
        assumption.
      *
        clear XV.
        apply IHv in H.
        apply ValUnionIsVal.
        left.
        assumption.
  -
    intros H.
    induction v.
    + crush.
    + simpl in *.
      rewrite VecUnion_cons in H.
      apply ValUnionIsVal in H.
      destruct H.
      apply IHv in H.
      right.
      apply H.
      left.
      apply H.
Qed.

Lemma Vbreak_dense_vector {n1 n2} {x: svector (n1+n2)} {x0 x1}:
  Vbreak x ≡ (x0, x1) ->
  svector_is_dense x ->  (svector_is_dense x0) /\ (svector_is_dense x1).
Proof.
  unfold svector_is_dense.
  apply Vbreak_preserves_P.
Qed.

Lemma Vec2Union_szero_svector_r {n} {a: svector n}:
  Vec2Union plus a (szero_svector n) = a.
Proof.
  unfold szero_svector.
  induction n.
  VOtac; reflexivity.
  simpl.
  rewrite Vcons_to_Vcons_reord.
  rewrite IHn by (apply Vforall_tl; assumption). clear IHn.
  rewrite Union_SZero_r.
  rewrite <- Vcons_to_Vcons_reord.
  dep_destruct a.
  crush.
Qed.

Lemma Vec2Union_szero_svector_l {n} {a: svector n}:
  Vec2Union plus (szero_svector n) a = a.
Proof.
  unfold szero_svector.
  induction n.
  VOtac; reflexivity.
  simpl.
  rewrite Vcons_to_Vcons_reord.
  rewrite IHn by (apply Vforall_tl; assumption). clear IHn.
  rewrite Union_SZero_l.
  rewrite <- Vcons_to_Vcons_reord.
  dep_destruct a.
  crush.
Qed.

Lemma szero_svector_all_zeros:
  ∀ n : nat, Vforall Is_ValZero (szero_svector n).
Proof.
  intros n.
  apply Vforall_nth_intro.
  intros i ip.
  unfold szero_svector.
  rewrite Vnth_const.
  apply SZero_is_ValZero.
Qed.

Definition svector_is_collision {n} (v:svector n) :=
  Vexists Is_Collision v.

Definition svector_is_non_collision {n} (v:svector n) :=
  Vforall Not_Collision v.

Lemma sparsify_non_coll: forall n (x:avector n),
    svector_is_non_collision (sparsify x).
Proof.
  intros n x.
  unfold sparsify.
  unfold svector_is_non_collision, Not_Collision, compose.
  apply Vforall_map_intro.
  apply Vforall_intro.
  intros v N.
  auto.
Qed.

Lemma sparsify_is_dense:
  ∀ (i : nat) (x : vector CarrierA i), svector_is_dense (sparsify x).
Proof.
  intros i x.
  unfold sparsify, svector_is_dense.
  apply Vforall_map_intro.
  apply Vforall_intro.
  intros v N.
  apply IsVal_mkValue.
Qed.

Lemma sparsify_densify {n} (x:svector n):
  svector_is_dense x ->
  svector_is_non_collision x ->
  (sparsify (densify x)) ≡ x.
Proof.
  intros D N.
  unfold densify, sparsify.
  rewrite Vmap_map.
  apply Vmap_eq_nth.
  intros i ip.
  unfold svector_is_dense in D.
  apply Vforall_nth with (ip:=ip) in D.
  unfold svector_is_non_collision in N.
  apply Vforall_nth with (ip:=ip) in N.
  generalize dependent (Vnth x ip). clear ip i.
  apply mkValue_evalWriter_VNC.
Qed.

Lemma sparsify_densify_equiv {n} (x:svector n):
  (sparsify (densify x)) = x.
Proof.
  unfold densify, sparsify.
  rewrite Vmap_map.
  vec_index_equiv i ip.
  rewrite Vnth_map.
  generalize dependent (Vnth x ip). clear ip i.
  intros r.
  apply mkValue_evalWriter.
Qed.

Lemma sparsify_densify_id_equiv {n}:
  (@sparsify n ∘ densify) = id.
Proof.
  apply ext_equiv_applied_iff'.
  split; try apply vec_Setoid.
  intros x y E.
  unfold compose.
  rewrite E.
  reflexivity.
  crush.
  apply sparsify_densify_equiv.
Qed.


Section Matrix.
  (* Poor man's matrix is vector of vectors.
     TODO: If it grows, move to separate module. *)

  Set Implicit Arguments.
  Variables (A: Type) (m n:nat).

  Definition row
             {i:nat} (ic: i<m)
             (a: vector (vector A m) n)
    :=
      Vmap (Vnth_aux ic) a.

  Definition col
             {i:nat} (ic: i<n)
             (a: vector (vector A m) n)
    :=
      Vnth a ic.

  Definition transpose
             (a: vector (vector A m) n)
    :=
      Vbuild (fun j jc => row jc a).

End Matrix.

(* "sparse" matrix 'm' rows by 'n' columns *)
Notation smatrix m n := (vector (svector m) n) (only parsing).


Close Scope vector_scope.
Close Scope nat_scope.


