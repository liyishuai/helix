
(* Require Import LibHyps.LibHyps. *)
Require Import Coq.Arith.Arith.
Require Import Psatz.

Require Import Coq.Strings.String.

Import Coq.Strings.String Strings.Ascii.
Open Scope string_scope.
Open Scope char_scope.

Require Import Coq.Lists.List.

Require Import Coq.Numbers.BinNums. (* for Z scope *)
Require Import Coq.ZArith.BinInt.

Require Import Helix.FSigmaHCOL.FSigmaHCOL.
Require Import Helix.FSigmaHCOL.Int64asNT.
Require Import Helix.FSigmaHCOL.Float64asCT.
Require Import Helix.DSigmaHCOL.DSigmaHCOLITree.
Require Import Helix.LLVMGen.Compiler.
Require Import Helix.LLVMGen.Correctness.
Require Import Helix.LLVMGen.Externals.
Require Import Helix.LLVMGen.Data.
Require Import Helix.LLVMGen.Utils.
Require Import Helix.LLVMGen.tmp_aux_Vellvm.
Require Import Helix.Util.OptionSetoid.
Require Import Helix.Util.ErrorSetoid.
Require Import Helix.Util.ListUtil.
Require Import Helix.Tactics.HelixTactics.

Require Import ExtLib.Structures.Monads.
Require Import ExtLib.Data.Map.FMapAList.

Require Import Vellvm.Tactics.
Require Import Vellvm.Util.
Require Import Vellvm.LLVMEvents.
Require Import Vellvm.DynamicTypes.
Require Import Vellvm.Denotation.
Require Import Vellvm.Handlers.Handlers.
Require Import Vellvm.TopLevel.
Require Import Vellvm.LLVMAst.
Require Import Vellvm.CFG.
Require Import Vellvm.InterpreterMCFG.
Require Import Vellvm.InterpreterCFG.
Require Import Vellvm.TopLevelRefinements.
Require Import Vellvm.TypToDtyp.
Require Import Vellvm.LLVMEvents.

Require Import Ceres.Ceres.

Require Import ITree.Interp.TranslateFacts.
Require Import ITree.Basics.CategoryFacts.
Require Import ITree.Events.State.
Require Import ITree.Events.StateFacts.
Require Import ITree.ITree.
Require Import ITree.Eq.Eq.
Require Import ITree.Basics.Basics.
Require Import ITree.Interp.InterpFacts.

Require Import Flocq.IEEE754.Binary.
Require Import Flocq.IEEE754.Bits.

Require Import MathClasses.interfaces.canonical_names.
Require Import MathClasses.misc.decision.

Require Import Omega.

Set Implicit Arguments.
Set Strict Implicit.

Import MDSHCOLOnFloat64.
Import D.
Import ListNotations.
Import MonadNotation.
Local Open Scope monad_scope.

(* A couple of notations to avoid ambiguities while not having to worry about imports and qualified names *)
Notation memoryV := memory_stack.
Notation memoryH := MDSHCOLOnFloat64.memory.


Section MemCopy.


  Axiom int_eq_inv: forall a b, Int64.intval a ≡ Int64.intval b -> a ≡ b.

  Opaque denote_bks.

  (** ** Compilation of MemCopy
      Unclear how to state this at the moment.
      What is on the Helix side? What do the arguments correspond to?
   *)
  Lemma MemCopy_Correct:
    ∀ (size : Int64.int) (x_p y_p : PExpr) (s1 s2 : IRState)
      (σ : evalContext) (memH : memoryH) (fuel : nat) (v : memoryH)
      (nextblock bid_in : block_id) (bks : list (LLVMAst.block typ))
      (g : global_env) (ρ : local_env) (memV : memoryV),
      nextblock ≢ bid_in
      → GenIR_Rel σ s1 (memH, ()) (memV, (ρ, (g, inl bid_in)))
      → evalDSHOperator σ (DSHMemCopy size x_p y_p) memH fuel ≡ Some (inr v)
      → genIR (DSHMemCopy size x_p y_p) nextblock s1 ≡ inr (s2, (bid_in, bks))
      → eutt (GenIR_Rel σ s1)
        (with_err_RB
          (interp_Mem (denoteDSHOperator σ (DSHMemCopy size x_p y_p)) memH))
        (with_err_LB
          (interp_cfg (denote_bks (convert_typ [ ] bks) bid_in) g ρ memV)).
  Proof.
    intros size x_p y_p s1 s2 σ memH fuel v nextblock bid_in bks g ρ memV NEXT BISIM EVAL GEN.
    destruct fuel as [| fuel]; [cbn in *; simp |].
    repeat red in BISIM.

    (* remember (GenIR_Rel σ s1 ⩕ lift_pure_cfg (s1 ≡ s2)) as RR. *)
    cbn* in GEN. simp. hide_strings'. cbn* in *.


    eutt_hide_right. repeat norm_h. unfold denotePExpr. cbn*.
    simp. eutt_hide_right. repeat (norm_h ; [ ]). norm_h.
    2 : {
      cbn*. rewrite Heqo2. reflexivity.
    }
    repeat norm_h.
    2 : {
      cbn*. rewrite Heqo1. reflexivity. 
    }
    rewrite interp_Mem_MemSet. norm_h.

    (* Right hand side... *)
    (* Step 1 : Handle blocks, then focus step by step. *)
    subst. eutt_hide_left.
    unfold add_comments. cbn*.

    rewrite denote_bks_singleton; eauto.
    2:reflexivity.
    cbn*.
    repeat norm_v.
    unfold uvalue_to_dvalue_uop.
    cbn*; repeat norm_v.
    unfold ITree.map. cbn.
    repeat setoid_rewrite translate_bind.
    cbn. repeat norm_v.
    setoid_rewrite translate_bind.
    cbn. repeat norm_v.
    repeat rewrite typ_to_dtyp_equation.

    (* Step 2 : First step focus --- looking up i0 pointer. *)
    focus_single_step_v.
    unfold Traversal.endo, Traversal.Endo_ident.

    (* Use memory invariant to reason about lookup. It must be either
     global or local. *)
    destruct BISIM.
    pose proof mem_is_inv as mem_is_inv'.
    red in mem_is_inv.
    specialize (mem_is_inv _ _ _ _ Heqo4 Heqo0). cbn in mem_is_inv.
    edestruct mem_is_inv as (x_mem_block & x_address & LOOKUP_mem_m &
                            i0_local_or_global & cell_on_memV).
    red in i0_local_or_global.

    break_inner_match.
    - (* Step 2.1 : i0 Is Global *)
      destruct i0_local_or_global as
        (ptr & τ & Pointer_TYPE & g_id_Some & read_memV).
      unfold Traversal.endo. cbn. repeat norm_v.

      (* Woo, we get something out of the mem invariant! *)
      Focus 2. cbn. apply g_id_Some.

      cbn. repeat norm_v. rewrite Heqi1.

    (* Step 3 : Next focus step :-) *)
      cbn*. repeat norm_v.
      do 2 setoid_rewrite translate_ret.
      cbn. repeat norm_v.
      setoid_rewrite translate_ret.
      repeat norm_vD.
      unfold Traversal.endo.

      rewrite interp_cfg_to_L3_LW.
      cbn*. repeat norm_v.
      setoid_rewrite translate_ret.
      repeat norm_v.

      (* Another lookup. *)
      unfold Traversal.Endo_ident.

      pose proof mem_is_inv as mem_is_inv''; red in mem_is_inv'.
      specialize (mem_is_inv' _ _ _ _ Heqo3 Heqo).
      edestruct mem_is_inv' as (i2_mem_block & i2_address & i2_LOOKUP_mem_m &
                               i2_local_or_global & i2_cell_on_memV).
      red in i2_local_or_global.

      break_inner_match.

      + (* Step 3.1 : i2 is Global *)
        destruct i2_local_or_global as
            (i2_ptr & i2_τ & i2_Pointer_TYPE & i2_g_id_Some & i2_read_memV).
        unfold Traversal.endo. cbn. repeat norm_v.

        Focus 2. rewrite Heqi4. apply i2_g_id_Some.

        setoid_rewrite translate_ret. repeat norm_v.
        do 2 setoid_rewrite translate_ret.
        cbn. repeat norm_v.
        setoid_rewrite translate_ret.
        repeat norm_v.

        cbn*. repeat norm_v.
        do 2 setoid_rewrite translate_ret.
        (* IY: Why don't the invocations of translate_ret work in norm_v? *)
        cbn. repeat norm_v.
        setoid_rewrite translate_ret.
        repeat norm_v.

        rewrite interp_cfg_to_L3_LW.
        cbn*. repeat norm_v.
        setoid_rewrite translate_ret.
        repeat norm_v.
        setoid_rewrite translate_ret.
        repeat (norm_v; try setoid_rewrite translate_ret).
        cbn. repeat norm_vD.
        2 : {
          assert (Name (String "l" (string_of_nat (local_count i3))) ≢
                       Name (String "l" (string_of_nat (S (local_count i3))))).
          { admit. }
          eapply lookup_alist_add_ineq in H. 
          setoid_rewrite H. clear H.
          apply lookup_alist_add_eq.
        }
        2 : apply lookup_alist_add_eq.
        cbn*. repeat norm_v.

        rewrite interp_cfg_to_L3_intrinsic.
        2 : {
          cbn. 
          admit. (* IY: This intrinsic is defined in terms of llvm. ?? *)
        }
      cbn; repeat norm_v. subst.

    (* Lemma state_inv_mem_union : *)

    (*   state_invariant σ i3 (memory_set memH m0 (mem_union m1 m2)) *)
    (*     (memV, *)
    (*     (alist_add (Name (String "l" (string_of_nat (S (local_count i3))))) *)
    (*       (UVALUE_Addr i2_ptr) *)
    (*       (alist_add (Name (String "l" (string_of_nat (local_count i3)))) *)
    (*           (UVALUE_Addr ptr) ρ), g)). *)

      (* Step 4: Last step : Prove that the invariants hold. *)
      apply eqit_Ret. cbn*.
      split; cbn; eauto.
        * intros. destruct v.
          -- red. destruct x.
             ++ admit.
             ++ admit.
          -- red. destruct x.
             ++ admit.
             ++ admit.
          -- admit.
        * admit.
        * admit.

      + (* Step 3.2 : i2 is Local *)
        unfold Traversal.endo. cbn. repeat norm_v.

        2 : {
          assert (id0 ≢ Name (String "l" (string_of_nat (local_count i3)))).
          admit.
          eapply lookup_alist_add_ineq in H.
          setoid_rewrite H. cbn. apply i2_local_or_global.
        }

        setoid_rewrite translate_ret. repeat norm_v.
        repeat norm_v. cbn*.
        repeat norm_v.
        do 2 setoid_rewrite translate_ret.
        repeat norm_v. setoid_rewrite translate_ret.
        repeat norm_v.

        rewrite interp_cfg_to_L3_LW.
        cbn*. repeat norm_v.
        setoid_rewrite translate_ret.
        repeat norm_v.
        setoid_rewrite translate_ret.
        repeat (norm_v; try setoid_rewrite translate_ret).
        cbn. repeat norm_vD.
        2 : {
          assert (Name (String "l" (string_of_nat (local_count i3))) ≢
                       Name (String "l" (string_of_nat (S (local_count i3))))).
          { admit. }
          eapply lookup_alist_add_ineq in H. 
          setoid_rewrite H. clear H.
          apply lookup_alist_add_eq.
        }
        2 : apply lookup_alist_add_eq.
        cbn*. repeat norm_v.
        rewrite interp_cfg_to_L3_intrinsic; try reflexivity.
      cbn; repeat norm_v. subst.

      (* Step 4: Last step : Prove that the invariants hold. *)
      apply eqit_Ret. cbn*.
      split; cbn; eauto.
        * intros. destruct v.
          -- red. destruct x.
             ++ admit.
             ++ admit.
          -- red. destruct x.
             ++ admit.
             ++ admit.
          -- admit.
        * admit.
        * admit.
        * admit.

    - (* Step 2.2 : i0 Is Local *)
        unfold Traversal.endo. cbn. repeat norm_v.

        2 : {
          cbn. apply i0_local_or_global.
        }

        setoid_rewrite translate_ret. repeat norm_v.
        repeat norm_v. cbn*. rewrite Heqi1.

    (* Step 3 : Next focus step :-) *)
      cbn*. repeat norm_v.
      do 2 setoid_rewrite translate_ret.
      cbn. repeat norm_v.
      setoid_rewrite translate_ret.
      repeat norm_vD.
      unfold Traversal.endo.

      rewrite interp_cfg_to_L3_LW.
      cbn*. repeat norm_v.
      setoid_rewrite translate_ret.
      repeat norm_v.

      (* Another lookup. *)
      unfold Traversal.Endo_ident.

      pose proof mem_is_inv as mem_is_inv''; red in mem_is_inv'.
      specialize (mem_is_inv' _ _ _ _ Heqo3 Heqo).
      edestruct mem_is_inv' as (i2_mem_block & i2_address & i2_LOOKUP_mem_m &
                               i2_local_or_global & i2_cell_on_memV).
      red in i2_local_or_global.

      break_inner_match.

      + (* Step 3.1 : i2 is Global *)
        destruct i2_local_or_global as
            (i2_ptr & i2_τ & i2_Pointer_TYPE & i2_g_id_Some & i2_read_memV).
        unfold Traversal.endo. cbn. repeat norm_v.

        Focus 2. rewrite Heqi4. apply i2_g_id_Some.

        setoid_rewrite translate_ret. repeat norm_v.
        do 2 setoid_rewrite translate_ret.
        cbn. repeat norm_v.
        setoid_rewrite translate_ret.
        repeat norm_v.

        cbn*. repeat norm_v.
        do 2 setoid_rewrite translate_ret.
        (* IY: Why don't the invocations of translate_ret work in norm_v? *)
        cbn. repeat norm_v.
        setoid_rewrite translate_ret.
        repeat norm_v.

        rewrite interp_cfg_to_L3_LW.
        cbn*. repeat norm_v.
        setoid_rewrite translate_ret.
        repeat norm_v.
        setoid_rewrite translate_ret.
        repeat (norm_v; try setoid_rewrite translate_ret).
        cbn. repeat norm_vD.
        2 : {
          assert (Name (String "l" (string_of_nat (local_count i3))) ≢
                       Name (String "l" (string_of_nat (S (local_count i3))))).
          { admit. }
          eapply lookup_alist_add_ineq in H. 
          setoid_rewrite H. clear H.
          apply lookup_alist_add_eq.
        }
        2 : apply lookup_alist_add_eq.
        cbn*. repeat norm_v.
        rewrite interp_cfg_to_L3_intrinsic; try reflexivity.
      cbn; repeat norm_v. subst.

      (* Step 4: Last step : Prove that the invariants hold. *)
      apply eqit_Ret. cbn*.
      split; cbn; eauto.
        * intros. destruct v.
          -- red. destruct x.
             ++ admit.
             ++ admit.
          -- red. destruct x.
             ++ admit.
             ++ admit.
          -- admit.
        * admit.
        * admit.
        * admit.

      + (* Step 3.2 : i2 is Local *)
        unfold Traversal.endo. cbn. repeat norm_v.

        2 : {
          assert (id0 ≢ Name (String "l" (string_of_nat (local_count i3)))).
          admit.
          eapply lookup_alist_add_ineq in H.
          setoid_rewrite H. cbn. apply i2_local_or_global.
        }

        setoid_rewrite translate_ret. repeat norm_v.
        repeat norm_v. cbn*.
        repeat norm_v.
        do 2 setoid_rewrite translate_ret.
        repeat norm_v. setoid_rewrite translate_ret.
        repeat norm_v.

        rewrite interp_cfg_to_L3_LW.
        cbn*. repeat norm_v.
        setoid_rewrite translate_ret.
        repeat norm_v.
        setoid_rewrite translate_ret.
        repeat (norm_v; try setoid_rewrite translate_ret).
        cbn. repeat norm_vD.
        2 : {
          assert (Name (String "l" (string_of_nat (local_count i3))) ≢
                       Name (String "l" (string_of_nat (S (local_count i3))))).
          { admit. }
          eapply lookup_alist_add_ineq in H. 
          setoid_rewrite H. clear H.
          apply lookup_alist_add_eq.
        }
        2 : apply lookup_alist_add_eq.
        cbn*. repeat norm_v.
        rewrite interp_cfg_to_L3_intrinsic; try reflexivity.
      cbn; repeat norm_v. subst.

      (* Step 4: Last step : Prove that the invariants hold. *)
      apply eqit_Ret. cbn*.
      split; cbn; eauto.
        * intros. destruct v.
          -- red. destruct x.
             ++ admit.
             ++ admit.
          -- red. destruct x.
             ++ admit.
             ++ admit.
          -- admit.
        * admit.
        * admit.
        * admit.
  Admitted.

End MemCopy.
