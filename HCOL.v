(* Coq defintions for HCOL operator language *)

Require Import Spiral.
Require Import Rtheta.
Require Import SVector.
Require Import HCOLImpl.

Require Import Arith.
Require Import Coq.Arith.Plus.
Require Import Program. (* compose *)
Require Import Morphisms.

Require Import CpdtTactics.
Require Import JRWTactics.
Require Import CaseNaming.
Require Import Coq.Logic.FunctionalExtensionality.

(* CoRN MathClasses *)
Require Import MathClasses.interfaces.abstract_algebra.
Require Import MathClasses.orders.minmax MathClasses.interfaces.orders.
Require Import MathClasses.implementations.peano_naturals.
Require Import MathClasses.theory.rings.
Require Import MathClasses.theory.setoids.

(*  CoLoR *)
Require Import CoLoR.Util.Vector.VecUtil.
Import VectorNotations.
Open Scope vector_scope.

(* === HCOL operators === *)

Section HCOL_Language.

  Class HOperator {i o:nat} (op: svector i -> svector o) :=
    op_proper : Proper ((=) ==> (=)) (op).

  Definition HPrepend {i n} (a:svector n)
    : svector i -> svector (n+i)
    := Vapp a.

  Definition HInfinityNorm {i}
    : svector i -> svector 1
    := Vectorize ∘ InfinityNorm.

  Definition HReduction {i}
             (f: Rtheta->Rtheta->Rtheta)
             `{pF: !Proper ((=) ==> (=) ==> (=)) f}
             (idv:Rtheta)
    : svector i -> svector 1
    := Vectorize ∘ (Reduction f idv).

  Definition HAppend {i n} (a:svector n)
    : svector i -> svector (i+n)
    := fun x => Vapp x a.

  Definition HVMinus {o}
    : svector (o+o) -> svector o
    := VMinus  ∘ (vector2pair o).

  Definition HBinOp {o}
             (f: nat->Rtheta->Rtheta->Rtheta)
             `{pF: !Proper ((=) ==> (=) ==> (=) ==> (=)) f}
    : svector (o+o) -> svector o
    :=  BinOp f ∘ (vector2pair o).

  Definition HEvalPolynomial {n} (a: svector n): svector 1 -> svector 1
    := Lst ∘ EvalPolynomial a ∘ Scalarize.

  Definition HMonomialEnumerator n
    : svector 1 -> svector (S n)
    := MonomialEnumerator n ∘ Scalarize.

  Definition HChebyshevDistance h
    : svector (h+h) -> svector 1
    := Lst ∘ ChebyshevDistance ∘ (vector2pair h).

  Definition HScalarProd {h}
    : svector (h+h) -> svector 1
    := Lst ∘ ScalarProd ∘ (vector2pair h).

  Definition HInduction (n:nat)
             (f: Rtheta->Rtheta->Rtheta)
             `{pF: !Proper ((=) ==> (=) ==> (=)) f}
             (initial:Rtheta)
    : svector 1 -> svector n
    := Induction n f initial ∘ Scalarize.

  Lemma HOperator_functional_extensionality
        {m n: nat}
        `{HOperator m n f}
        `{HOperator m n g}:
    (∀ v, f v = g v) -> f = g.
  Proof.
    unfold HOperator in *.
    assert(Setoid_Morphism g).
    split; try apply vec_Setoid. assumption.
    assert(Setoid_Morphism f).
    split; try apply vec_Setoid. assumption.
    apply ext_equiv_applied_iff.
  Qed.

  Section HCOL_operators.

    Global Instance HScalarProd_HOperator {n}:
      HOperator (@HScalarProd n).
    Proof.
      intros x y E.
      unfold HScalarProd.
      unfold compose, Lst, vector2pair.
      apply Vcons_single_elim.
      rewrite E.
      reflexivity.
    Qed.

    Global Instance HBinOp_HOperator {o}
           (f: nat->Rtheta->Rtheta->Rtheta)
           `{pF: !Proper ((=) ==> (=) ==> (=) ==> (=)) f}:
      HOperator (@HBinOp o f pF).
    Proof.
      intros x y E.
      unfold HBinOp.
      unfold compose, Lst, vector2pair.
      rewrite E.
      reflexivity.
    Qed.

    Global Instance HReduction_HOperator {i}
           (f: Rtheta->Rtheta->Rtheta)
           `{pF: !Proper ((=) ==> (=) ==> (=)) f}
           (idv:Rtheta):
      HOperator (@HReduction i f pF idv).
    Proof.
      intros x y E.
      unfold HReduction .
      unfold compose, Lst, vector2pair.
      apply Vcons_single_elim.
      rewrite E.
      reflexivity.
    Qed.

    Global Instance HEvalPolynomial_HOperator {n} (a: svector n):
      HOperator (@HEvalPolynomial n a).
    Proof.
      intros x y E.
      unfold HEvalPolynomial.
      unfold compose, Lst, vector2pair.
      apply Vcons_single_elim.
      rewrite E.
      reflexivity.
    Qed.

    Global Instance HPrepend_HOperator {i n} (a:svector n):
      HOperator (@HPrepend i n a).
    Proof.
      intros x y E.
      unfold HPrepend.
      unfold compose, Lst, vector2pair.
      apply Vcons_single_elim.
      rewrite E.
      reflexivity.
    Qed.

    Global Instance HMonomialEnumerator_HOperator n:
      HOperator (@HMonomialEnumerator n).
    Proof.
      intros x y E.
      unfold HMonomialEnumerator.
      unfold compose, Lst, vector2pair.
      apply Vcons_single_elim.
      rewrite E.
      reflexivity.
    Qed.

    Global Instance HInfinityNorm_HOperator n:
      HOperator (@HInfinityNorm n).
    Proof.
      intros x y E.
      unfold HInfinityNorm.
      unfold compose, Lst, vector2pair.
      apply Vcons_single_elim.
      rewrite E.
      reflexivity.
    Qed.

    Global Instance HInduction_HOperator {n:nat}
           (f: Rtheta->Rtheta->Rtheta)
           `{pF: !Proper ((=) ==> (=) ==> (=)) f}
           (initial:Rtheta):
      HOperator (HInduction n f initial).
    Proof.
      intros x y E.
      unfold HInduction.
      unfold compose, Lst, vector2pair.
      apply Vcons_single_elim.
      rewrite E.
      reflexivity.
    Qed.

    Global Instance HChebyshevDistance_HOperator h:
      HOperator (HChebyshevDistance h).
    Proof.
      intros x y E.
      unfold HChebyshevDistance.
      unfold compose, Lst, vector2pair.
      apply Vcons_single_elim.
      rewrite E.
      reflexivity.
    Qed.

    Global Instance HVMinus_HOperator h:
      HOperator (@HVMinus h).
    Proof.
      intros x y E.
      unfold HVMinus.
      unfold compose, Lst, vector2pair.
      rewrite E.
      reflexivity.
    Qed.

  End HCOL_operators.
End HCOL_Language.

Section IgnoreIndex_wrapper.

  (* Wrapper to replace index parameter for HBinOp kernel. 2 stands for arity of 'f' *)
  Definition SwapIndex2 {A} (i:nat) (f:nat->A->A->A) := fun (_:nat) => f i.

  Global Instance SwapIndex2_proper `{Setoid A} (i:nat)
         (f:nat->A->A->A) `{f_mor: !Proper ((=) ==> (=) ==> (=) ==> (=)) f}:
    Proper ((=) ==> (=) ==> (=) ==> (=)) (@SwapIndex2 A i f).
  Proof.
    intros a a' Ea b b' Eb y y' Ey.
    unfold SwapIndex2.
    f_equiv; assumption.
  Qed.

  (* Wrapper to ignore index parameter for HBinOp kernal. 2 stands for arity of 'f' *)
  Definition IgnoreIndex2 {A} (f:A->A->A) := fun  (i:nat) => f.

  Lemma IgnoreIndex2_ignores `{Setoid A}
        (f:A->A->A)`{f_mor: !Proper ((=) ==> (=) ==> (=)) f}
    : forall i0 i1,
      (IgnoreIndex2 f) i0 = (IgnoreIndex2 f) i1.
  Proof.
    intros.
    unfold IgnoreIndex2.
    apply f_mor.
  Qed.

  Global Instance IgnoreIndex2_proper:
    (Proper (((=) ==> (=)) ==> (=)) IgnoreIndex2).
  Proof.
    simpl_relation.
    apply H; assumption.
  Qed.

End IgnoreIndex_wrapper.


