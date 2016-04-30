
Require Import VecUtil.
Require Import Spiral.
Require Import CarrierType.

Require Import HCOL.
Require Import HCOLImpl.
Require Import THCOL.
Require Import THCOLImpl.

Require Import Arith.
Require Import Compare_dec.
Require Import Coq.Arith.Peano_dec.
Require Import Program.

Require Import CpdtTactics.
Require Import JRWTactics.
Require Import CaseNaming.
Require Import SpiralTactics.

Require Import Coq.Logic.FunctionalExtensionality.

(* CoRN MathClasses *)
Require Import MathClasses.interfaces.abstract_algebra MathClasses.interfaces.orders.
Require Import MathClasses.orders.minmax MathClasses.orders.orders MathClasses.orders.rings.
Require Import MathClasses.theory.rings MathClasses.theory.abs.

(*  CoLoR *)
Require Import CoLoR.Util.Vector.VecUtil.
Import VectorNotations.
Open Scope vector_scope.
Open Scope hcol_scope.

Definition MaxAbs (a b: CarrierA): CarrierA := max (abs a) (abs b).

Global Instance MaxAbs_proper:
  Proper ((=) ==> (=) ==> (=)) (MaxAbs).
Proof.
  intros a a' aE b b' bE.
  unfold MaxAbs.
  rewrite aE, bE.
  reflexivity.
Qed.

Section HCOLBreakdown.

  Lemma Vmap2Indexed_to_VMap2 `{Setoid A} {n} {a b: vector A n}
        (f:A->A->A) `{f_mor: !Proper ((=) ==> (=) ==> (=)) f}
  :
    Vmap2 f a b = Vmap2Indexed (IgnoreIndex2 f) a b.
  Proof.
    unfold equiv, vec_equiv.
    apply Vforall2_intro_nth.
    intros i ip.
    rewrite Vnth_Vmap2Indexed.
    rewrite Vnth_map2.
    reflexivity.
  Qed.

  Theorem breakdown_ScalarProd: forall (n:nat) (a v: avector n),
      ScalarProd (a,v) =
      ((Reduction (+) 0) ∘ (BinOp (IgnoreIndex2 mult))) (a,v).
  Proof.
    intros n a v.
    unfold compose, BinOp, Reduction, ScalarProd.
    rewrite 2!Vfold_right_to_Vfold_right_reord.
    rewrite Vmap2Indexed_to_VMap2.
    reflexivity.
    solve_proper.
  Qed.

  Fact breakdown_OScalarProd: forall {h:nat},
      HScalarProd (h:=h)
      =
      ((HReduction  (+) 0) ⊚ (HBinOp (IgnoreIndex2 mult))).
  Proof.
    intros h.
    apply HOperator_functional_extensionality; intros v.
    unfold HScalarProd, HReduction, HBinOp.
    unfold vector2pair, compose, Lst, Vectorize.
    apply Vcons_single_elim.
    destruct (Vbreak v).
    apply breakdown_ScalarProd.
  Qed.

  Theorem breakdown_EvalPolynomial: forall (n:nat) (a: avector (S n)) (v: CarrierA),
      EvalPolynomial a v = (
        ScalarProd ∘ (pair a) ∘ (MonomialEnumerator n)
      ) v.
  Proof.
    intros n a v.
    unfold compose.
    induction n.
    - simpl (MonomialEnumerator 0 v).
      rewrite EvalPolynomial_reduce.
      dep_destruct (Vtail a).
      simpl.
      ring.

    - rewrite EvalPolynomial_reduce, MonomialEnumerator_cons, ScalarProd_reduce.
      unfold Ptail.
      rewrite ScalarProd_comm.

      Opaque Scale ScalarProd.
      simpl.
      Transparent Scale ScalarProd.

      rewrite ScalarProduct_hd_descale, IHn, mult_1_r, ScalarProd_comm.
      reflexivity.
  Qed.

  Fact breakdown_OEvalPolynomial: forall (n:nat) (a: avector (S n)),
      HEvalPolynomial a =
      (HScalarProd ⊚
                   ((HPrepend  a) ⊚
                                  (HMonomialEnumerator n))).
  Proof.
    intros n a.
    apply HOperator_functional_extensionality; intros v.
    unfold HEvalPolynomial, HScalarProd, HPrepend, HMonomialEnumerator.
    unfold vector2pair, HCompose, compose, Lst, Scalarize.
    rewrite Vcons_single_elim, Vbreak_app.
    apply breakdown_EvalPolynomial.
  Qed.

  Theorem breakdown_TInfinityNorm: forall (n:nat) (v: avector n),
      InfinityNorm v = (Reduction MaxAbs 0) v.
  Proof.
    intros.
    unfold InfinityNorm, Reduction.
    dependent induction v.
    - reflexivity.
    - rewrite Vfold_right_reduce.
      rewrite_clear IHv.
      simpl.

      assert(ABH: (abs (Vfold_right MaxAbs v 0)) =
                  (Vfold_right MaxAbs v 0)).
      {
        unfold MaxAbs.
        dependent induction v.
        + simpl.
          apply abs_0_s.
        + apply CarrierAto.
          rewrite Vfold_right_reduce, IHv, <- abs_max_comm_2nd.
          reflexivity.
      }
      unfold MaxAbs.
      rewrite_clear ABH.
      reflexivity.
  Qed.

  Fact breakdown_OTInfinityNorm:  forall (n:nat),
      HInfinityNorm =
      HReduction MaxAbs 0 (i:=n).
  Proof.
    intros n.
    apply HOperator_functional_extensionality; intros v.
    apply Vcons_single_elim.
    apply breakdown_TInfinityNorm.
  Qed.

  Theorem breakdown_MonomialEnumerator:
    forall (n:nat) (x: CarrierA),
      MonomialEnumerator n x = Induction (S n) (.*.) 1 x.
  Proof.
    intros n x.
    induction n.
    - reflexivity.
    - rewrite MonomialEnumerator_cons.
      rewrite Vcons_to_Vcons_reord.
      rewrite_clear IHn.
      symmetry.
      rewrite Induction_cons.
      rewrite Vcons_to_Vcons_reord.
      unfold Scale.

      rewrite 2!Vmap_to_Vmap_reord.
      setoid_replace (fun x0 : CarrierA => mult x0 x) with (mult x).
      reflexivity.
      +
        compute. intros.
        rewrite H. apply mult_comm.
  Qed.

  Fact breakdown_OMonomialEnumerator:
    forall (n:nat),
      HMonomialEnumerator n =
      HInduction (S n) (.*.) 1.
  Proof.
    intros n.
    apply HOperator_functional_extensionality; intros v.
    apply breakdown_MonomialEnumerator.
  Qed.

  Theorem breakdown_ChebyshevDistance:  forall (n:nat) (ab: (avector n)*(avector n)),
      ChebyshevDistance ab = (InfinityNorm ∘ VMinus) ab.
  Proof.
    intros.
    unfold compose, ChebyshevDistance, VMinus.
    destruct ab.
    reflexivity.
  Qed.

  Fact breakdown_OChebyshevDistance:  forall (n:nat),
      HChebyshevDistance n = (HInfinityNorm ⊚ HVMinus).
  Proof.
    intros n.
    apply HOperator_functional_extensionality; intros v.
    unfold Lst, compose.
    apply Vcons_single_elim.
    apply breakdown_ChebyshevDistance.
  Qed.

  Theorem breakdown_VMinus:  forall (n:nat) (ab: (avector n)*(avector n)),
      VMinus ab =  BinOp (IgnoreIndex2 pneg) ab.
  Proof.
    intros.
    unfold VMinus, BinOp.
    break_let.
    apply Vmap2Indexed_to_VMap2.
    crush.
  Qed.

  Fact breakdown_OVMinus:  forall (n:nat),
      HVMinus = HBinOp (o:=n) (IgnoreIndex2 pneg).
  Proof.
    intros n.
    apply HOperator_functional_extensionality; intros v.
    unfold HVMinus.
    unfold vector2pair.
    apply breakdown_VMinus.
  Qed.

  Fact breakdown_OTLess_Base: forall
      {i1 i2 o}
      `{o1pf: !HOperator (o1: avector i1 -> avector o)}
      `{o2pf: !HOperator (o2: avector i2 -> avector o)},
      HTLess o1 o2 = (HBinOp (IgnoreIndex2 Zless) ⊚ HCross o1 o2).
  Proof.
    intros i1 i2 o o1 po1 o2 po2.
    apply HOperator_functional_extensionality; intros v.
    unfold HTLess, HBinOp, HCross.
    unfold HCompose, compose, BinOp.
    simpl.
    rewrite vp2pv.
    repeat break_let.
    unfold vector2pair in Heqp.
    rewrite Heqp in Heqp1.
    inversion Heqp0.
    inversion Heqp1.
    apply Vmap2Indexed_to_VMap2.
    crush.
  Qed.

End HCOLBreakdown.


(* Our top-level example goal *)
Lemma DynWinOSPL:  forall (a: avector 3),
    (HTLess
       (HEvalPolynomial a)
       (HChebyshevDistance 2))
    =
    (HBinOp (IgnoreIndex2 Zless) ⊚
            HCross
            ((HReduction plus 0 ⊚ HBinOp (IgnoreIndex2 mult)) ⊚ (HPrepend a ⊚ HInduction _ mult 1))
            (HReduction MaxAbs 0 ⊚ HBinOp (o:=2) (IgnoreIndex2 pneg))).
Proof.
  intros a.
  rewrite breakdown_OTLess_Base.
  rewrite breakdown_OEvalPolynomial.
  rewrite breakdown_OScalarProd.
  rewrite breakdown_OMonomialEnumerator.
  rewrite breakdown_OChebyshevDistance.
  rewrite breakdown_OVMinus.
  rewrite breakdown_OTInfinityNorm.
  apply HOperator_functional_extensionality.
  reflexivity.
Qed.

