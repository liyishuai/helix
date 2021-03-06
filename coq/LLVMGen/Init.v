(* Definitions and lemmas related to correcntess of memory initialization *)

Require Import Helix.LLVMGen.Correctness_Prelude.
Require Import Helix.LLVMGen.Correctness_Invariants.

Import MonadNotation.
Import ITreeNotations.

Set Implicit Arguments.
Set Strict Implicit.
Import List.

(*
Fact initIRGlobals_cons_head_uniq:
  ∀ (a : string * DSHType) (globals : list (string * DSHType))
    (data : list binary64) (res : list binary64 * list (toplevel_entity typ (LLVMAst.block typ * list (LLVMAst.block typ)))),
    initIRGlobals data (a :: globals) ≡ inr res ->
    forall (j : nat) (n : string) (v : DSHType),
      (nth_error globals j ≡ Some (n, v) /\ n ≡ fst a) → False.
Proof.
  intros a globals data res H j n v C.
  unfold initIRGlobals, global_uniq_chk in H.
  cbn in H.
  repeat break_match_hyp; try inl_inr.
  unfold assert_false_to_err in Heqs.
  repeat break_match_hyp; try inl_inr.
  inl_inr_inv.
  subst.
  assert(globals_name_present (fst a) globals ≡ true).
  {
    clear -C.
    apply nth_to_globals_name_present.
    exists (n,v).
    exists j.
    apply C.
  }
  congruence.
Qed.
 *)

(*
(* If [initIRGlobals] suceeds, the names of variables in [globals] were unique *)
Lemma initIRGlobals_names_unique {globals data res}:
  initIRGlobals data globals ≡ inr res → list_uniq fst globals.
Proof.
  revert res data.
  induction globals; intros.
  -
    cbn in H.
    inv H.
    apply list_uniq_nil.
  -
    apply list_uniq_cons.
    split.
    +
      cbn in H.
      break_match_hyp;[inl_inr|].
      break_match_hyp;[inl_inr|].
      break_let; subst.
      break_match_hyp;[inl_inr|].
      break_let; subst.
      inv H.
      eapply IHglobals.
      eauto.
    +
      (* [a] must not be present in [globals] *)
      unfold not.
      intros C.
      destruct C as (j & [n v] & C); cbn in C.
      eapply initIRGlobals_cons_head_uniq; eauto.
Qed.
 *)

(* Note: this could not be proben for arbitrary [chk] function,
   so we prove this only for [no_chk] *)
Lemma init_with_data_app
      {A: Type} (* input values *)
      {B: Type} (* output values we collect *)
      {C: Type} (* data *)
      (f: C -> A -> err (C*B))
      (c c': C) (* initial data *)
      (l0 l1: list A)
      (b: list B)
  :
    init_with_data f no_chk c (l0++l1) ≡ inr (c',b) ->
    ∃ c1 b1 b2,
      (init_with_data f no_chk c l0 ≡ inr (c1,b1) /\
       init_with_data f no_chk c1 l1 ≡ inr (c',b2) /\
       b ≡ (b1 ++ b2)%list).
Proof.
  revert l0 l1 c c' b.
  induction l0; intros.
  -
    cbn in H.
    repeat eexists.
    eauto.
  -
    cbn in H.
    repeat break_match_hyp; try inl_inr.
    inl_inr_inv.
    subst.
    apply IHl0 in Heqs0; clear IHl0.
    destruct Heqs0 as (c1 & b1 & b2 & H1 & H2 & E).
    repeat eexists; cbn.
    +
      rewrite Heqs.
      rewrite H1.
      eauto.
    +
      eauto.
    +
      cbn.
      f_equiv.
      auto.
Qed.

Lemma monadic_fold_left_err_app
         {A B : Type}
         (f : A -> B -> err A)
         (s0 s2 : A)
         (l0 l1 : list B):
  ListSetoid.monadic_fold_left f s0 (l0++l1) ≡ inr s2
  ->
  ∃ s1,
  ListSetoid.monadic_fold_left f s0 l0 ≡ inr s1 /\
  ListSetoid.monadic_fold_left f s1 l1 ≡ inr s2.
Proof.
  revert l0 l1 s0 s2 f.
  induction l0; intros.
  -
    cbn in *.
    eexists; auto.
  -
    cbn in H.
    break_match_hyp; [inl_inr|].
    eapply IHl0 in H.
    destruct H as [s1 [H1 H2]].
    eexists.
    split; [|eauto].
    cbn.
    rewrite Heqs.
    apply H1.
Qed.

(* TODO: This is general-purpose. Move elsewhere? *)
Lemma mapsto_alist_app_1st
      {K V: Type}
      (R : K → K → Prop)
      `{RD: RelDec.RelDec _ R}
      `{RDC: @RelDec.RelDec_Correct K R RD}
      (g g' : alist K V)
      (v : V)
      (n : K):
  mapsto_alist RD g n v ->
  mapsto_alist RD (g ++ g')%list n v.
Proof.
  revert v n.
  induction g; intros.
  -
    inversion H.
  -
    cbn.
    destruct a as [k0 v0].
    apply mapsto_alist_cons; [apply RDC|].
    destruct (RelDec.rel_dec n k0) eqn:K0.
    +
      right.
      split.
      *
        rewrite RelDec.rel_dec_correct in K0.
        apply K0.
      *
        apply mapsto_alist_cons in H ; [| auto].
        destruct H.
        destruct H.
        rewrite RelDec.rel_dec_correct in K0.
        congruence.
        apply H.
    +
      left.
      split.
      *
        apply IHg.
        apply mapsto_alist_cons in H ; [| auto].
        destruct H.
        apply H.
        destruct H.
        apply RelDec.rel_dec_correct in H.
        congruence.
      *
        apply RelDec.neg_rel_dec_correct in K0.
        apply K0.
Qed.

Lemma alist_find_nth_error_list_uniq
      (g : global_env)
      (x : nat)
      (n: raw_id)
      (v : dvalue)
      (U: list_uniq fst g):
  nth_error g x ≡ Some (n, v) →
  alist_find n g ≡ Some v.
Proof.
  revert U.
  revert x v n.
  induction g; intros.
  -
    rewrite nth_error_nil in H.
    some_none.
  -
    cbn.
    break_let.
    break_if.
    +
      unfold RelDec.rel_dec, AstLib.eq_dec_raw_id in Heqb.
      cbn in Heqb.
      break_match; [| inversion Heqb].
      subst.
      destruct x.
      *
        cbn in H.
        some_inv.
        reflexivity.
      *
        cbn in H.
        clear - U H.
        exfalso.
        apply list_uniq_cons in U.
        destruct U.
        contradict H1.
        eexists.
        eexists.
        eauto.
    +
      destruct x.
      *
        clear IHg.
        cbn in *.
        some_inv.
        subst.
        clear - Heqb.
        unfold RelDec.rel_dec, AstLib.eq_dec_raw_id in Heqb.
        cbn in Heqb.
        break_if.
        inversion Heqb.
        contradict n0.
        reflexivity.
      *
        cbn in H.
        eapply IHg.
        eapply list_uniq_de_cons; eauto.
        eapply H.
Qed.

Definition state_invariant_mcfg (σ : evalContext) (s : IRState) : Rel_mcfg_T unit unit :=
  fun '(memH,_) '(memV,((l,sl),(g,_))) =>
      state_invariant σ s memH (memV,(l,g)).

Lemma memory_set_seq2 {E}
      (i1 i2: mem_block_id)
      (b1 b2: mem_block)
      (m0: memoryH)
  :
    (Ret (memory_set (memory_set m0 i1 b1) i2 b2, ()) : itree E _)
    ≈
    ITree.bind (Ret (m0,()))
     (fun '(x,_) => Ret (memory_set (memory_set m0 i1 b1) i2 b2, ())).
Proof.
  cbn; rewrite bind_ret_l; reflexivity.
Qed.

Lemma memory_set_seq {E}
      (i1: mem_block_id)
      (b1: mem_block)
      (m0: memoryH)
  :
    (Ret (memory_set m0 i1 b1, ()) : itree E _)
    ≈
    ITree.bind
      (Ret (m0, ()))
      (fun '(x,_) => Ret (memory_set x i1 b1, ())).
Proof.
  cbn; rewrite bind_ret_l; reflexivity.
Qed.



(* YZ TODO : Move *)
Arguments allocate : simpl never.

Local Ltac pose_interp_to_L3_alloca m' a' A AE:=
  match goal with
  | [|-context[interp_to_L3 ?defs (trigger (Alloca ?t)) ?g ?l ?m]] =>
    pose proof (interp_to_L3_alloca
                  defs
                  m t g l)
      as [m' [a' [A AE]]]
  end.

(* [global_uniq_chk] in succeeds, does not modify state *)
Fact global_uniq_chk_preserves_st:
  forall a globals i0 i1 u,
    global_uniq_chk a globals i0 ≡ inr (i1, u) ->
    i0 ≡ i1.
Proof.
  intros a globals i0 i1 u H.
  unfold global_uniq_chk in H.
  unfold ErrorWithState.err2errS in H.
  break_match_hyp;inv H.
  reflexivity.
Qed.


Fact initOneIRGlobal_state_change:
  forall data nm t g' i0 i1 r,
    initOneIRGlobal data (nm,t) i0 ≡ inr (i1, (g', r))
    -> inr (i1,()) ≡ (addVars [(ID_Global (Name nm), TYPE_Pointer (getIRType t))]) i0.
Proof.
  intros data nm t g' i0 i1 r H.
  unfold initOneIRGlobal in H.
  destruct t.
  - break_let.
    inv H.
    reflexivity.
  - break_let; cbn in H; inl_inr_inv; reflexivity.
  - break_let; cbn in H; inl_inr_inv; reflexivity.
Qed.

Lemma getStateVar_preserves_st
      {s : string}
      {n : nat}
      {st st' r} :
  getStateVar s n st ≡ inr (st', r) ->
  st ≡ st'.
Proof.
  intros.
  unfold getStateVar in H.
  cbn in H.
  unfold ErrorWithState.option2errS in H.
  break_match; inversion H; subst.
  reflexivity.
Qed.

Lemma genMExpr_preserves_Γ
      {m : MExpr}
      {s s' r} :
  genMExpr m s ≡ inr (s', r) ->
  Γ s ≡ Γ s'.
Proof.
  intros.
  unfold genMExpr in H.
  destruct m; [| inversion H].
  destruct p.
  unfold bind in H.
  break_let.
  inversion Heqm; subst ret bind; clear Heqm.
  repeat break_match; inversion H.
  subst.
  apply getStateVar_preserves_st in Heqs0.
  congruence.
Qed.

Transparent incLocal.
Transparent incVoid.
Transparent incBlock.
Transparent incBlockNamed.

Lemma genNExpr_preserves_Γ
      {n : NExpr}
      {s s' r} :
  genNExpr n s ≡ inr (s', r) ->
  Γ s ≡ Γ s'.
Proof.
  intros.
  generalize dependent r.
  generalize dependent s.
  generalize dependent s'.
  induction n.

  { (* base case 1 *)
    intros.
    unfold genNExpr in H.
    unfold bind in H.
    repeat break_let.
    inversion Heqm; subst ret bind; clear Heqm.
    repeat break_match; inversion H; subst; clear H.
    +
      apply getStateVar_preserves_st in Heqs0.
      subst; reflexivity.
    +
      apply getStateVar_preserves_st in Heqs0; subst i.
      apply incLocal_Γ in Heqs1.
      congruence.
  }

  { (* base case 2 *)
    intros.
    cbn in H.
    inversion H; reflexivity.
  }

  (* inductive cases *)
  all: intros; cbn in H.
  all: destruct (genNExpr n1 s)  as [t | [s1 [ae1 ac1]]] eqn:N1; [inl_inr |].
  all: destruct (genNExpr n2 s1) as [t | [s2 [ae2 ac2]]] eqn:N2; [inl_inr |].
  all: inversion_clear H. (* clear H H1 H2. *)
  all: apply IHn1 in N1.
  all: apply IHn2 in N2.
  all: cbn; congruence.
Qed.

Lemma genAExpr_preserves_Γ
      {a : AExpr}
      {s s' r} :
  genAExpr a s ≡ inr (s', r) ->
  Γ s ≡ Γ s'.
Proof.
  intros.
  generalize dependent r.
  generalize dependent s.
  generalize dependent s'.
  induction a.

  { (* base case 1 *)
    intros.
    unfold genAExpr in H.
    unfold bind in H.
    repeat break_let.
    inversion Heqm; subst ret bind; clear Heqm.
    repeat break_match; inversion H; subst; clear H.
    +
      apply getStateVar_preserves_st in Heqs0.
      apply incLocal_Γ in Heqs1.
      congruence.
    +
      apply getStateVar_preserves_st in Heqs0.
      congruence.
  }

  { (* base case 2 *)
    intros.
    cbn in H.
    inversion H; reflexivity.
  }

  {
    intros.
    cbn in H.
    repeat break_match; inversion_clear H.
    subst.
    apply genNExpr_preserves_Γ in Heqs0.
    apply genMExpr_preserves_Γ in Heqs1.
    cbn.
    congruence.
  }

  {
    intros.
    cbn in H.
    destruct (genAExpr a s)  as [t | [s1 [ae1 ac1]]] eqn:A; [inl_inr |].
    apply IHa in A.
    inversion H.
    cbn.
    congruence.
  }

  (* inductive cases *)
  all: intros; cbn in H.
  all: destruct (genAExpr a1 s)  as [t | [s1 [ae1 ac1]]] eqn:A1; [inl_inr |].
  all: destruct (genAExpr a2 s1) as [t | [s2 [ae2 ac2]]] eqn:A2; [inl_inr |].
  all: inversion_clear H. (* clear H H1 H2. *)
  all: apply IHa1 in A1.
  all: apply IHa2 in A2.
  all: cbn; congruence.
Qed.
Lemma resolve_PVar_simple : forall p s s' x v,
    resolve_PVar p s ≡ inr (s', (x, v)) ->
    exists sz n,
      nth_error (Γ s') n ≡ Some (x, TYPE_Pointer (TYPE_Array sz TYPE_Double)) /\
      MInt64asNT.from_Z sz ≡ inr v /\ p ≡ PVar n /\ s ≡ s'.
Proof.
  intros * H.
  unfold resolve_PVar in H.
  cbn* in H.
  simp.
  do 2 eexists; eauto.
Qed.


(* This lemma states that [genIR] if succeeds does not leak
   compiler state variable *)
Lemma genIR_prserves_Γ
      {op: DSHOperator}
      {nextblock: block_id}
      {s s' segment}:
  genIR op nextblock s ≡ inr (s', segment) ->
  Γ s ≡ Γ s'.
Proof.
  intros.
  induction op.
  -
    cbn in H; inversion H; reflexivity.
  -
    unfold genIR in H.
    repeat break_let; subst.
    unfold catch in H.
    repeat break_let; subst.
    unfold ErrorWithState.Exception_errS in Heqm.
    inversion Heqm; subst; clear Heqm.
    remember
      ["--- Operator: " @@ string_of_DSHOperator (DSHAssign (p, n) (p0, n0)) @@ "---"]
      as T; clear HeqT.
    simpl bind in H.
    repeat break_match; try inl_inr; try (inversion H; fail).
    repeat inl_inr_inv; subst.
    inversion H0; subst; clear H0.
    replace i with s in * by
        (apply resolve_PVar_simple in Heqs1;
         destruct Heqs1 as [t1 [t2 H]];
           apply H).
    replace i2 with s in *
      by (apply resolve_PVar_simple in Heqs2;
          destruct Heqs2 as [t1 [t2 H]];
          apply H).
    clear Heqs1 Heqs2 p p0.
    unfold genFSHAssign in Heqs3.
    remember "Assign"%string as A.
    simpl bind in Heqs3.
    repeat break_match; try inl_inr.
    repeat inl_inr_inv; subst.
    apply genNExpr_preserves_Γ in Heqs0.
    apply genNExpr_preserves_Γ in Heqs1.
    cbn in Heqs0, Heqs1.
    congruence.
Admitted.

(* Helper boolean predicate to check if member of [Γ] in [IRState] is global *)
Definition is_var_Global (v:ident * typ): bool :=
  match (fst v) with
  | ID_Global _ => true
  | _ => false
  end.

(* See also: [init_with_data_len] *)
Lemma init_with_data_env_len
      (globals : list (string * DSHType))
      (d0 d1 : list binary64)
      (s0 s1: IRState)
      (chk : string * DSHType → list (string * DSHType) → cerr ())
      (gdecls : list (toplevel_entity typ (LLVMAst.block typ * list (LLVMAst.block typ))))
  :
    init_with_data initOneIRGlobal chk d0 globals s0 ≡ inr (s1, (d1, gdecls)) →
    List.length (Γ s1) ≡
    List.length (List.filter is_var_Global (Γ s0)) + List.length globals.
Proof.
Admitted.

Lemma split_hd_len {A : Type} (l l1 l2 : list A) (n : nat) :
  ListUtil.split l n ≡ Some (l1, l2) -> length l1 ≡ n.
Proof.
  enough (forall acc, ListUtil.split_aux acc l n ≡ Some (l1, l2) -> length l1 ≡ n + length acc).
  {
    intros.
    rewrite H with (acc:=[]).
    cbn.
    apply Nat.add_0_r.
    assumption.
  }
  generalize dependent l.
  induction n.
  -
    intros.
    destruct l.
    all: inversion H; subst.
    all: rewrite ListUtil.rev_append_rev, app_nil_r, rev_length.
    all: reflexivity.
  -
    intros.
    destruct l; [inversion H |].
    cbn in H.
    apply IHn in H.
    cbn in H.
    rewrite plus_Snm_nSm.
    assumption.
Qed.

Lemma split_tl_len {A : Type} (l l1 l2 : list A) (n : nat) :
  ListUtil.split l n ≡ Some (l1, l2) -> length l2 ≡ (length l - n)%nat.
Proof.
  intros.
  copy_apply ListUtil.split_correct H.
  apply split_hd_len in H.
  subst.
  rewrite ListUtil.length_app.
  lia.
Qed.

Fact bind_ret_override
      {A B C : Type}
      {E : Type -> Type}
      (f : A -> A -> C)
      (b : B)
      (i1 i2 : itree E A) :
  (ITree.bind
     (ITree.bind i1
                 (λ a1 : A, ITree.bind i2
                                       (λ a2 : A, Ret (f a1 a2))))
     (λ _ : C, Ret b))
  ≈
  (ITree.bind i1 (λ _, ITree.bind i2 (λ _ : A, Ret b))).
Proof.
  repeat (rewrite bind_bind; apply eutt_eq_bind; intro).
  rewrite bind_ret_l.
  reflexivity.
Qed.

(* QOL, similar to [eutt_eq_bind] *)
Lemma eutt_eq_bind_l :
  forall E R U (t1 t2 : itree E U) (k : U -> itree E R),
    t1 ≈ t2 -> ITree.bind t1 k ≈ ITree.bind t2 k.
Proof.
  intros.
  rewrite H.
  reflexivity.
Qed.

(* TODO: remove when done
Lemma bind_comm {E : Type -> Type} {A B : Type} {x : B} (i1 i2 : itree E A) :
    (exists i, i1 ≈ Ret i) ->
    ITree.bind (ITree.bind i1 (fun _ => i2)) (fun _ => Ret x) ≈
    ITree.bind (ITree.bind i2 (fun _ => i1)) (fun _ => Ret x).
Proof.
  intro I.
  destruct I as [i I].
  setoid_rewrite I.
  rewrite bind_ret_l.
  rewrite bind_bind.
  setoid_rewrite bind_ret_l.
  reflexivity.
Qed.


Lemma build_global_environment_globals_app
      (m_name m_target m_datalayout : option string)
      (m_globals_1 m_globals_2 : list (global dtyp))
      (m_declarations : list (declaration dtyp))
      (m_definitions : list (definition dtyp (cfg dtyp)))
  :
    build_global_environment {|
        m_name := m_name;
        m_target := m_target;
        m_datalayout := m_datalayout;
        m_type_defs := []; (* for simplicity, no type definitions *)
        m_globals := (m_globals_1 ++ m_globals_2)%list;
        m_declarations := m_declarations;
        m_definitions := m_definitions
      |}

    ≈

    ITree.bind
      (build_global_environment {|
           m_name := m_name;
           m_target := m_target;
           m_datalayout := m_datalayout;
           m_type_defs := []; (* for simplicity, no type definitions *)
           m_globals := m_globals_1;
           m_declarations := []; (* no declarations *)
           m_definitions := [] (* no definitions *)
         |})
      (fun _ => ITree.bind
               (build_global_environment {|
                    m_name := m_name;
                    m_target := m_target;
                    m_datalayout := m_datalayout;
                    m_type_defs := []; (* for simplicity, no type definitions *)
                    m_globals := m_globals_2;
                    m_declarations := []; (* no declarations *)
                    m_definitions := [] (* no definitions *)
                  |})
               (fun _ => build_global_environment {|
                          m_name := m_name;
                          m_target := m_target;
                          m_datalayout := m_datalayout;
                          m_type_defs := []; (* for simplicity, no type definitions *)
                          m_globals := []; (* no globals *)
                          m_declarations := m_declarations;
                          m_definitions := m_definitions |})).
Proof.
  Opaque map_monad.
  cbn.
  setoid_rewrite map_monad_app.
  cbn.
  Transparent map_monad.
  cbn.
  repeat progress (try setoid_rewrite bind_ret_l;
                   try setoid_rewrite translate_bind;
                   try setoid_rewrite translate_ret).
  repeat setoid_rewrite bind_ret_override.
  repeat rewrite <-bind_bind.

Abort.

Fact bind_ret_override' {E : Type -> Type} {A B : Type} (i1 i2 : itree E A) (x y : B) :
  forall f,
    (ITree.bind (translate f (ITree.bind i1 (fun _ => Ret x)))
                (fun _ => ITree.bind i2 (fun _ => Ret y))) ≈
    ITree.bind (ITree.bind i1 (fun _ => i2)) (fun _ => Ret y).
Proof.
  intro.
  repeat rewrite bind_bind.

  apply eutt_eq_bind.
  intro.
  rewrite bind_ret_l.
  reflexivity.
Qed.

Let etl := translate _exp_E_to_L0.
Goal
  forall lid lids m X Y,
    interp_mcfg (allocate_globals X ;; etl (T:=()) (initialize_globals Y)) lid lids m
    ≈
    interp_mcfg (etl (initialize_globals Y) ;; allocate_globals X) lid lids m.
Proof.
  intros.
  cbn.
  norm_h.
  setoid_rewrite bind_ret_l.
  setoid_rewrite translate_bind.
  unfold initialize_global.
  setoid_rewrite unfold_translate.                                                            
Admitted.
*)

From ITree Require Import
     Basics.Monad. 

(* similar to [map_monad_app] but for [map_monad_],
   without unnecessary bindings *)
Lemma map_monad_app_
      {m : Type -> Type}
      {Mm : Monad m}
      {EqMm : Eq1 m}
      {HEQP: Eq1Equivalence m}
      {ML: MonadLawsE m}
      {A : Type}
      (f : A -> m unit)
      (l1 l2 : list A)
  :
    (map_monad_ f (l1 ++ l2) ≈
    map_monad_ f l1 ;;
    map_monad_ f l2)%monad.
Proof.
  unfold map_monad_.
  rewrite map_monad_app.
  generalize (map_monad f l1);
    generalize (map_monad f l2);
    intros L1 L2.
  repeat setoid_rewrite bind_bind.
  setoid_rewrite bind_ret_l.
  reflexivity.
Qed.

(* all allocations and initializations operate using [map_monad_].
   It is nicer to work with than [map_monad], so fold it whenver possible *)
Local Ltac fold_map_monad_ :=
  repeat
  match goal with
  | |- context [map_monad ?f ?L;; Ret ()] =>
    replace (map_monad f L;; Ret ())
      with (map_monad_ f L)
      in *
      by reflexivity
  end.


Local Ltac fold_initialization :=
  repeat
  match goal with
  | |- context[map_monad_ allocate_global ?l] =>
    replace (map_monad_ allocate_global l)
      with (allocate_globals l)
      in *
      by reflexivity
  | |- context[map_monad_ allocate_declaration ?l] =>
    replace (map_monad_ allocate_declaration l)
      with (allocate_declarations l)
      in *
      by reflexivity
  | |- context[map_monad_ initialize_global ?l] =>
    replace (map_monad_ initialize_global l)
      with (initialize_globals l)
      in *
      by reflexivity
  end.

(** [memory_invariant] relation must holds after initialization of global variables *)
Lemma memory_invariant_after_init
      (p: FSHCOLProgram)
      (data: list binary64) :
  forall hmem σ s hdata pll,
    helix_intial_memory p data ≡ inr (hmem,hdata,σ) /\
    compile_w_main p data newState ≡ inr (s,pll) ->
    eutt
      (state_invariant_mcfg σ s)
      (Ret (hmem, ()))
      (with_err_LT
         (interp_to_L3 defined_intrinsics
                       (build_global_environment (mcfg_of_tle pll))
                       [] ([],[]) empty_memory_stack)
      ).
Proof.
  intros hmem σ s hdata pll [HI LI].

  unfold state_invariant_mcfg.
  unfold helix_intial_memory in HI.
  cbn in HI.
  repeat break_match_hyp ; try inl_inr.
  rename Heqp0 into Co, Heqp1 into Ci.
  inv HI.
  rename m1 into mg, Heqs0 into G.
  cbn in LI.
  unfold ErrorWithState.option2errS in *.
  repeat break_match_hyp; try inl_inr;
    inv LI; repeat inv_sum; inv Heqs5; inv Heqs4.
  rename Heqs0 into LX, Heqs1 into LG, Heqs6 into IR, Heqs8 into BC, l3 into gdecls.
  rename Heqo1 into Sg. (* split globals *)
  rename Heqo0 into Sxy. (* split fake_x, fake_y *)

  (*  [s0] - state after [initXYplaceholders] *)
  rename i0 into s0.
  (*  [s1] - state after [initIRGlobals], which
      was generated starting with X,Y arguments added to [s0] *)
  rename i1 into s1.
  (*  [s2] - state after [genIR] *)
  rename i6 into s2.
  (*  [s3] - the final state. (after [body_non_empty_cast]) *)
  rename i5 into s3.

  (* [s3] contains two local for X,Y parameter which we drop: *)

  rename l5 into Γ_globals.
  (* these ones are dropped *)
  rename l8 into Γ_fake_xy,
         l6 into Γ_xy_fake_xy,
         l7 into Γ_xy.

  assert (ΓXYFXY : exists x y fake_x fake_y, Γ_xy_fake_xy ≡ [x; y; fake_x; fake_y]).
  {
    clear - Sg Heqb.
    apply split_tl_len in Sg.
    apply Nat.leb_gt in Heqb.
    assert (Datatypes.length Γ_xy_fake_xy ≡ 4)%nat by lia.
    clear - H.
    repeat (destruct Γ_xy_fake_xy; inversion H).
    repeat eexists.
  }
  destruct ΓXYFXY as [x [y [fake_x [fake_y ΓXYFXY]]]].
  subst Γ_xy_fake_xy.
  invc Sxy.
  apply ListUtil.split_correct in Sg.
  rename Sg into Vs3.

  repeat rewrite app_assoc.
  unfold build_global_environment, allocate_globals, map_monad_.
  simpl.
  rewrite 2!interp_to_L3_bind, translate_bind.
  rename e into eg.
  remember (eg ++
               [DSHPtrVal (S (Datatypes.length globals)) o;
                DSHPtrVal (Datatypes.length globals) i])%list as e.

  repeat rewrite ListUtil.flat_map_app.
  simpl.
  (* no more [genMain] *)

  destruct s3.

  rename m into mo, m0 into mi.
  rename p13 into body_instr.

  cbn in *.

  (* only globals defined by [initXYplaceholders] *)
  replace (flat_map (type_defs_of typ) t) with (@nil (ident * typ)) in *.
  2:{
    clear - LX.
    unfold initXYplaceholders in LX.
    repeat break_let.
    cbn in LX.
    inv LX.
    reflexivity.
  }
  replace (flat_map (declarations_of typ) t) with (@nil (declaration typ)) in *.
  2:{
    clear - LX.
    unfold initXYplaceholders in LX.
    repeat break_let.
    cbn in LX.
    inv LX.
    reflexivity.
  }
  replace (flat_map (definitions_of typ) t)
    with (@nil (definition typ (LLVMAst.block typ * list (LLVMAst.block typ))))
    in *.
  2:{
    clear - LX.
    unfold initXYplaceholders in LX.
    repeat break_let.
    cbn in LX.
    inv LX.
    reflexivity.
  }

  (* only globals defined by [initIRGlobals] *)
  replace (flat_map (type_defs_of typ) gdecls) with (@nil (ident * typ)) in *.
  2:{
    clear - LX LG.
    symmetry.

    unfold initXYplaceholders in LX.
    repeat break_let.
    cbn in LX.
    inv LX.

    clear - LG.
    rename l1 into data, l2 into data'.
    revert gdecls data data' LG.
    unfold initIRGlobals.

    cbn.

    generalize [(ID_Local (Name "Y"),
                 TYPE_Pointer (TYPE_Array (Int64.intval o) TYPE_Double));
                (ID_Local (Name "X"),
                 TYPE_Pointer (TYPE_Array (Int64.intval i) TYPE_Double));
                (ID_Global (Anon 1%Z), TYPE_Array (Int64.intval o) TYPE_Double);
                (ID_Global (Anon 0%Z), TYPE_Array (Int64.intval i) TYPE_Double)] as v.

    induction globals; intros v gdecls data data' H.
    -
      cbn in *.
      inl_inr_inv.
      reflexivity.
    -
      cbn in H.
      repeat break_match_hyp; try inl_inr.
      apply global_uniq_chk_preserves_st in Heqs; subst i0.
      inl_inr_inv; subst.
      cbn.
      apply ListUtil.app_nil.
      +
        clear - Heqs0.
        rename Heqs0 into H.
        unfold initOneIRGlobal in H.
        cbn in *.
        repeat break_match.
        all: inv H.
        all: reflexivity.
      +
        destruct a.
        apply initOneIRGlobal_state_change in Heqs0; cbn in Heqs0; inl_inr_inv.
        destruct i1.
        inversion H0.
        erewrite IHglobals with
            (data:=l)
            (data':=data')
            (v:=(ID_Global (Name s), TYPE_Pointer (getIRType d)) :: v)
        ; clear IHglobals; try reflexivity.

        subst Γ. subst.
        apply Heqs1.
  }
  replace (flat_map (declarations_of typ) gdecls) with (@nil (declaration typ)) in *.
  2:{
    clear - LX LG.
    symmetry.

    unfold initXYplaceholders in LX.
    repeat break_let.
    cbn in LX.
    inv LX.

    clear - LG.
    rename l1 into data, l2 into data'.
    revert gdecls data data' LG.
    unfold initIRGlobals.

    cbn.

    generalize [(ID_Local (Name "Y"),
                 TYPE_Pointer (TYPE_Array (Int64.intval o) TYPE_Double));
                (ID_Local (Name "X"),
                 TYPE_Pointer (TYPE_Array (Int64.intval i) TYPE_Double));
                (ID_Global (Anon 1%Z), TYPE_Array (Int64.intval o) TYPE_Double);
                (ID_Global (Anon 0%Z), TYPE_Array (Int64.intval i) TYPE_Double)] as v.

    induction globals; intros v gdecls data data' H.
    -
      cbn in *.
      inl_inr_inv.
      reflexivity.
    -
      cbn in H.
      repeat break_match_hyp; try inl_inr.
      apply global_uniq_chk_preserves_st in Heqs; subst i0.
      inl_inr_inv; subst.
      cbn.
      apply ListUtil.app_nil.
      +
        clear - Heqs0.
        rename Heqs0 into H.
        unfold initOneIRGlobal in H.
        cbn in *.
        repeat break_match.
        all: inv H.
        all: reflexivity.
      +
        destruct a.
        apply initOneIRGlobal_state_change in Heqs0; cbn in Heqs0; inl_inr_inv.
        destruct i1.
        inversion H0.
        erewrite IHglobals with
            (data:=l)
            (data':=data')
            (v:=(ID_Global (Name s), TYPE_Pointer (getIRType d)) :: v)
        ; clear IHglobals; try reflexivity.

        subst Γ. subst.
        apply Heqs1.
  }
  replace (flat_map (definitions_of typ) gdecls)
    with (@nil (definition typ (LLVMAst.block typ * list (LLVMAst.block typ))))
    in *.
  2:{
    clear - LX LG.
    symmetry.

    unfold initXYplaceholders in LX.
    repeat break_let.
    cbn in LX.
    inv LX.

    clear - LG.
    rename l1 into data, l2 into data'.
    revert gdecls data data' LG.
    unfold initIRGlobals.

    cbn.

    generalize [(ID_Local (Name "Y"),
                 TYPE_Pointer (TYPE_Array (Int64.intval o) TYPE_Double));
                (ID_Local (Name "X"),
                 TYPE_Pointer (TYPE_Array (Int64.intval i) TYPE_Double));
                (ID_Global (Anon 1%Z), TYPE_Array (Int64.intval o) TYPE_Double);
                (ID_Global (Anon 0%Z), TYPE_Array (Int64.intval i) TYPE_Double)] as v.

    induction globals; intros v gdecls data data' H.
    -
      cbn in *.
      inl_inr_inv.
      reflexivity.
    -
      cbn in H.
      repeat break_match_hyp; try inl_inr.
      apply global_uniq_chk_preserves_st in Heqs; subst i0.
      inl_inr_inv; subst.
      cbn.
      apply ListUtil.app_nil.
      +
        clear - Heqs0.
        rename Heqs0 into H.
        unfold initOneIRGlobal in H.
        cbn in *.
        repeat break_match.
        all: inv H.
        all: reflexivity.
      +
        destruct a.
        apply initOneIRGlobal_state_change in Heqs0; cbn in Heqs0; inl_inr_inv.
        destruct i1.
        inversion H0.
        erewrite IHglobals with
            (data:=l)
            (data':=data')
            (v:=(ID_Global (Name s), TYPE_Pointer (getIRType d)) :: v)
        ; clear IHglobals; try reflexivity.

        subst Γ. subst.
        apply Heqs1.
  }

  repeat rewrite app_nil_r.
  repeat rewrite app_nil_l.

  
  (* simplification *)
  eutt_hide_rel REL.
  eutt_hide_left DSHM.
  (* The following three tactics are non-straight reasoning.
     I separately computed what the simplification *would* be,
     and then put the [remember]s before the [replace].
     The simplification from it is so nice that it's worth it. *)
  remember {|
     dc_name := Name name;
     dc_type := typ_to_dtyp [ ]
                  (TYPE_Function TYPE_Void
                     [TYPE_Pointer (TYPE_Array (Int64.intval i) TYPE_Double);
                     TYPE_Pointer (TYPE_Array (Int64.intval o) TYPE_Double)]);
     dc_param_attrs := ([ ],
                       [[PARAMATTR_Readonly; PARAMATTR_Align PtrAlignment;
                        PARAMATTR_Nonnull];
                       [PARAMATTR_Align PtrAlignment; PARAMATTR_Nonnull]]);
     dc_linkage := None;
     dc_visibility := None;
     dc_dll_storage := None;
     dc_cconv := None;
     dc_attrs := [ ];
     dc_section := None;
     dc_align := None;
     dc_gc := None |}
    as xy1.
  remember {|
      dc_name := Name "main";
      dc_type := typ_to_dtyp [ ]
                             (TYPE_Function (TYPE_Array (Int64.intval o) TYPE_Double) [ ]);
      dc_param_attrs := ([ ], [ ]);
      dc_linkage := None;
      dc_visibility := None;
      dc_dll_storage := None;
      dc_cconv := None;
      dc_attrs := [ ];
      dc_section := None;
      dc_align := None;
      dc_gc := None |}
    as y1.
  match goal with
  | |- context[map df_prototype ?l] =>
    replace (map df_prototype l) with [xy1; y1] by (subst; reflexivity)
  end.
  match goal with
  | |- context[?h::?tl] => remember (h::tl) as intrinsic_delcs
  end.
  (* /simplification *)
  
  rewrite <-translate_bind.
  repeat rewrite <-interp_to_L3_bind.
  fold_map_monad_.
  repeat unfold fmap, Fmap_list'.

  (* 
     * [t], provided by [LX], contains two globals: "fake X", "fake Y"
     * [gdecls], provided by [LG], contains some list of globals

     There are three steps:
     1. [map_monad_ allocate_global]
        - This step needs to be split into a bind of "allocate t" and "allocate gdecls".
     2. [map_monad_ allocate_declaration]
        - Overall, according to @lord's comment later in this file,
          this part should somehow not matter at all. It was admitted though.
     3. [map_monad_ initialize_global]
        - This, just like (1), needs to be split in two.

     Omitting the [allocate_declaration] part altogether,
     (1) and (3) need to be rearrannged to form

     <allocate gdecls> ;; <initialize gdecls> ;;
     <allocate xy> ;; <initialize xy>

     Notably, the lists under [map_monad_ allocate_global]
     and [map_monad_ initialize_global] are ≡.

   *)

  (* splitting the lists in (1) and (3) *)
  (* just [rewrite map_app] doesn't work for some reason *)
  replace (map (Fmap_global typ dtyp (typ_to_dtyp [ ]))
               (flat_map (globals_of typ) t ++ flat_map (globals_of typ) gdecls))
    with (map (Fmap_global typ dtyp (typ_to_dtyp [ ])) (flat_map (globals_of typ) t) ++
              map (Fmap_global typ dtyp (typ_to_dtyp [ ])) (flat_map (globals_of typ) gdecls))
    by (rewrite map_app; reflexivity).

  (* splitting (1) and (3) into binds *)
  setoid_rewrite map_monad_app_.

  fold_initialization.
  simpl.

  remember (map (Fmap_global typ dtyp (typ_to_dtyp [ ]))
                (flat_map (globals_of typ) t))
    as XY.
  remember (map (Fmap_global typ dtyp (typ_to_dtyp [ ]))
                (flat_map (globals_of typ) gdecls))
    as GLOB.

  (* the [allocate_declaration] part has no correspondence on DSH side
     (at least under the current [REL]). Thus it can/should be [eutt_clo_bind]-ed
     with a fake meaningless ret/bind on DSH side.
     Commutativity will still probably need to be proven for it to make the other necessary
     rearranngements. *)
  (* [allocate_declaration] operates very similarly to [allocate_global],
     so if commutativity needs to be proven, I'd expect it to be
     exactly the same as that for [allocate_global] *)
  remember (allocate_declarations
              (map (Fmap_declaration typ dtyp (typ_to_dtyp [ ])) intrinsic_delcs);;
            allocate_declarations [xy1; y1])
    as DECLS_BLOB.

  (** * rearrangement goes here *)

  (* peel globals from the DSH side *)
  subst DSHM.
  (* Explicit [ITree.bind'] here because Coq can't guess [E]. Note that [bind' x y ~ bind y x] *)
  replace (Ret (memory_set (memory_set mg (S (Datatypes.length globals)) mo)
          (Datatypes.length globals) mi, ()))
    with
      (ITree.bind' (E:=E_mcfg)
                   (fun mg' => mgy <- Ret (memory_set mg' (S (Datatypes.length globals)) mo) ;;
                            Ret (memory_set mgy (Datatypes.length globals) mi, ()))
                   (Ret mg))
    by admit.

  (*
  eapply eutt_clo_bind.
  -
    admit.
  -
    intros.
    repeat break_let.
    subst; cbn.
    
    rewrite translate_bind.

    rewrite interp_to_L3_ret, translate_ret.
    setoid_rewrite bind_ret_l at 2.
    rewrite interp_to_L3_bind, translate_bind.
    rewrite interp_to_L3_bind.
    setoid_rewrite translate_bind.

    repeat rewrite <-app_assoc.
    rewrite map_app.
    repeat break_let.

    rewrite map_monad_app at 1; cbn.
    rewrite interp_to_L3_bind.
    setoid_rewrite translate_bind.
    repeat rewrite bind_bind.
    
    eapply eutt_clo_bind.
    +
      cbn.
      repeat break_let.
      admit.
    +
      intros.
      repeat break_let.
      
      
      



  

  rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)


  unfold body_non_empty_cast in BC.
  cbn in BC.
  break_match_hyp; inv BC.
  cbn.

  remember {|
         block_count := block_count;
         local_count := local_count;
         void_count := void_count;
         Γ := Γ_globals ++ [fake_x; fake_y] |} as s.

  (* from [Rel_mcfg_T] to [Rel_mcfg] *)
  remember ((λ memH '(memV, (l4,_,g)),
             state_invariant
               (eg ++
                   [DSHPtrVal (S (Datatypes.length globals)) o;
                    DSHPtrVal (Datatypes.length globals) i])%list s memH
               (memV, (l4, g))): Rel_mcfg) as R0.

  apply eutt_clo_bind with (UU:=(lift_Rel_mcfg R0) _ _ ).
  -
    (* [map_monad allocate_global] *)

    (* [t] - [initXYplaceholders]. It does not depend on globals *)

    unfold initXYplaceholders in LX.
    repeat break_let.
    cbn in LX.
    inv LX.
    Opaque map_monad.
    cbn in *.

    unfold initIRGlobals in LG.

    unfold Traversal.Fmap_global, Traversal.fmap, Traversal.Fmap_list'.
    cbn.

    match goal with
    | [|- context[map_monad _ (?h::?t)]] =>
      replace (h::t) with ([h]++t)%list
        by apply list_cons_app
    end.

    rewrite map_monad_app.
    cbn.
    rewrite interp_to_L3_bind, translate_bind.
    rewrite 2!memory_set_seq.
    rewrite bind_bind.

    (* peel off just globals init *)
    remember {|
            block_count := block_count;
            local_count := local_count;
            void_count := void_count;
            Γ := Γ_globals ++ [fake_x; fake_y] |} as s.

    (* In [UU] we drop X,Y in σ *)
    apply eutt_clo_bind with (UU:=(lift_Rel_mcfg
                                     (λ (memH : memoryH) '(memV, (l6, _, g)),
                                      state_invariant eg s memH
                                                      (memV, (l6, g))) (TV:=list ()))).
    +
      pose proof (genIR_prserves_Γ IR) as S.
      destruct s1.
      cbn in S.
      subst Γ.

      cbn in Heql3.

      (*
      assert(length globals ≡ length v3) as LV.
      {
        clear - LG.
        apply init_with_data_env_len in LG.
        cbn in LG.
        lia.
      }
       *)

      subst s.
      revert mg gdecls eg (* v3 *) IR LG G (* LV *).
      induction globals; intros.
      *
        cbn in G; inv G.
        cbn in LG; inv LG.
        cbn.
        unfold helix_empty_memory.
        rewrite interp_to_L3_ret.
        rewrite translate_ret.
        apply eutt_Ret.
        cbn.
        split; cbn.
        --
          intros n v τ x H H0.
          clear - H.
          rewrite nth_error_nil in H.
          some_none.
        --
          apply genIR_prserves_Γ in IR.
          inv IR.
          intros v n H.
          rewrite nth_error_nil in H.
          some_none.
        --
          intros id v n H H0.
          clear - H.
          unfold alist_In in H.
          inv H.
      *
        cbn in LG.
        break_match_hyp; [inl_inr|].
        break_let; subst p.
        break_match_hyp; [inl_inr|].
        break_let; subst p.
        break_let; subst p0.
        break_match_hyp; [inl_inr|].
        break_let; subst p.
        break_let; subst p0.
        destruct gdecls as [|g0 gdecls]; inv LG.

        cbn in G.
        break_match_hyp; [inl_inr|].
        break_let; subst p.
        break_match_hyp; [inl_inr|].
        break_let; subst p.
        destruct eg as [|eg0 eg]; inv G.

        destruct v3 as [|v0 v3]; [inv LV|].

        (* Not sure about [mg] *)

        simpl.
        rewrite map_app.
        rewrite map_monad_app.
        cbn.
        rewrite interp_to_L3_bind, translate_bind.
        rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)

        apply eutt_clo_bind with
            (UU:=lift_Rel_mcfg
                   (λ (memH : memoryH) '(memV, (l8, _, g)),
                    state_invariant ([eg0])
                                    {|
                                      block_count := block_count;
                                      local_count := local_count;
                                      void_count := void_count;
                                      Γ := [v0] |} memH (memV, (l8, g))) (TV:=list ())).
        --
          clear IHglobals.
          unfold globals_of.
          unfold initOneIRGlobal in Heqs0.
          break_let.
          break_match_hyp; inv Heqs0.
          ++
            (* ctype *)
            break_let.
            subst.
            inv H0.
            cbn.
            rewrite interp_to_L3_bind, translate_bind.
            rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)

            match goal with
            | [|- context[lift_Rel_mcfg ?r]] => remember r as R0
            end.
            apply eutt_clo_bind with (UU:=(lift_Rel_mcfg R0) _ _ ).
            rewrite interp_to_L3_bind, translate_bind.
            rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
            remember ((λ (memH : memoryH) '(memV, (l8, _, g)),
               state_invariant []
                 {|
                 block_count := block_count;
                 local_count := local_count;
                 void_count := void_count;
                 Γ := [] |} memH (memV, (l8, g))):Rel_mcfg) as R1.

            apply eutt_clo_bind with (UU:=(lift_Rel_mcfg R1) _ _ ).
            cbn.
            pose_interp_to_L3_alloca m' a' A AE.
            unfold non_void.
            rewrite typ_to_dtyp_D.
            intros C. inversion C.
            rewrite_clear AE.
            cbn.
            rewrite translate_ret.
            apply eutt_Ret.
            cbn.
            subst R1.
            split.
            **
              intros n v τ x H H0.
              rewrite nth_error_nil in H.
              some_none.
            **
              unfold WF_IRState.
              unfold evalContext_typechecks.
              cbn.
              intros v n H.
              rewrite nth_error_nil in H.
              some_none.
            **
              admit.
            **
              intros u1 u2 H.
              repeat break_let.
              rewrite interp_to_L3_GW.
              cbn.
              rewrite translate_ret.
              apply eutt_Ret.
              (* R1 -> R0 *)
              admit.
            **
              intros u1 u2 H.
              repeat break_let.

              rewrite interp_to_L3_bind, translate_bind.
              rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
              apply eutt_clo_bind with (UU:=(lift_Rel_mcfg R0) _ _ ).
              rewrite interp_to_L3_ret.
              rewrite translate_ret.
              apply eutt_Ret.
              destruct u0.
              clear - H.
              (* equivalent to [H] up to [TV] argument of [lift_Rel_mcfg] *)
              admit.

              intros u3 u4 H0.
              repeat break_let.
              rewrite interp_to_L3_ret.
              rewrite translate_ret.
              apply eutt_Ret.
              destruct u0.
              clear -H0.
              (* equivalent to [H0] up to [TV] argument of [lift_Rel_mcfg] *)
              admit.
          ++
            (* nat *)
            break_let.
            subst.
            inv H0.
            cbn.
            admit.
        --
          intros u1 u2 H.
          repeat break_let.
          subst.

          setoid_rewrite <- bind_ret_r.
          rewrite interp_to_L3_bind, translate_bind.
          rewrite bind_bind.
          eapply eutt_clo_bind.

          (* specialize (IHglobals mg gdecls eg v3).
          apply IHglobals. *)
          admit.

          intros u0 u2 H0.
          repeat break_let; subst.
          rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
          eapply eutt_clo_bind.
          rewrite interp_to_L3_ret.
          rewrite translate_ret.
          apply eutt_Ret.
          admit.

          intros u2 u3 H1.
          apply eutt_Ret.
          admit.
    +
      intros u1 u2 H.
      (* X,Y *)
      repeat break_let; subst.

      rewrite interp_to_L3_bind, translate_bind.
      eapply eutt_clo_bind.

      rewrite interp_to_L3_bind, translate_bind.
      rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
      eapply eutt_clo_bind.

      rewrite interp_to_L3_bind, translate_bind.
      rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
      eapply eutt_clo_bind.

      (* dealing with Y allocation *)

      pose_interp_to_L3_alloca m' a' A AE.
      rewrite typ_to_dtyp_D_array.
      crush.

      rewrite_clear AE.
      cbn.
      rewrite translate_ret.
      apply eutt_Ret.
      admit.

      intros u1 u2 H0.
      repeat break_let; subst.
      rewrite interp_to_L3_GW.
      cbn.
      rewrite translate_ret.
      apply eutt_Ret.
      admit.

      (* "Y" is dealt with *)

      intros u1 u2 H0.
      repeat break_let; subst.


      rewrite interp_to_L3_bind, translate_bind.
      rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
      eapply eutt_clo_bind.

      rewrite interp_to_L3_bind, translate_bind.
      rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
      eapply eutt_clo_bind.

      rewrite interp_to_L3_bind, translate_bind.
      rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
      eapply eutt_clo_bind.


      (* dealing with X allocation *)

      pose_interp_to_L3_alloca m' a' A AE.
      rewrite typ_to_dtyp_D_array.
      crush.

      rewrite_clear AE.
      cbn.
      rewrite translate_ret.
      apply eutt_Ret.
      admit.

      intros u2 u3 H1.
      repeat break_let; subst.
      rewrite interp_to_L3_GW.
      cbn.
      rewrite translate_ret.
      apply eutt_Ret.
      admit.

      (* "X" is dealt with *)

      intros u2 u3 H1.
      repeat break_let; subst.
      rewrite interp_to_L3_bind, translate_bind.
      rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
      eapply eutt_clo_bind.

      rewrite interp_to_L3_ret, translate_ret.
      apply eutt_Ret.
      admit.

      intros u3 u5 H2.
      repeat break_let; subst.
      rewrite interp_to_L3_ret, translate_ret.
      apply eutt_Ret.
      admit.

      intros u2 u3 H1.
      repeat break_let; subst.
      rewrite interp_to_L3_ret, translate_ret.
      apply eutt_Ret.
      admit.

      intros u1 u2 H0.
      repeat break_let; subst.
      rewrite interp_to_L3_ret, translate_ret.
      apply eutt_Ret.
      admit.
  -
    intros u1 u2 H.
    rewrite translate_bind.
    rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
    apply eutt_clo_bind with (UU:=(lift_Rel_mcfg R0) _ _ ).
    +
      repeat break_let.
      rewrite interp_to_L3_ret, translate_ret.
      apply eutt_Ret.
      unfold lift_Rel_mcfg in *.
      repeat break_let.
      apply H.
    +
      intros u0 u3 H0.
      repeat break_let.
      simpl.
      rewrite interp_to_L3_bind, translate_bind.
      rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
      apply eutt_clo_bind with (UU:=(lift_Rel_mcfg R0) _ _ ).
      *
        cbn.
        rewrite interp_to_L3_bind, translate_bind.
        rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
        apply eutt_clo_bind with (UU:=(lift_Rel_mcfg R0) _ _ ).
        --
          (* allocate_declaration *)

          (* This should not matter, as declarations do not end up
             in \sigma and thus not affect memory invariant *)
          admit.
        --
          intros u4 u5 H1.
          repeat break_let.
          rewrite interp_to_L3_ret.
          rewrite translate_ret.
          apply eutt_Ret.
          unfold lift_Rel_mcfg in *.
          repeat break_let.
          auto.
      *
        intros u4 u5 H1.
        repeat break_let.
        unfold initialize_globals.
        unfold map_monad_.
        cbn.
        rewrite translate_bind.
        rewrite interp_to_L3_bind.
        rewrite translate_bind.
        rewrite <- bind_ret_r. (* Add fake "bind" at LHS *)
        apply eutt_clo_bind with (UU:=(lift_Rel_mcfg R0) _ _ ).
        --
          (* initialize_global *)
          subst.
          admit.
        --
          intros u7 u8 H2.
          repeat break_let.
          rewrite translate_ret.
          rewrite interp_to_L3_ret.
          rewrite translate_ret.
          apply eutt_Ret.
          unfold lift_Rel_mcfg in *.
          repeat break_let.
          auto.
*)
Admitted.

(* with init step  *)
Lemma compiler_correct_aux:
  forall (p:FSHCOLProgram)
    (data:list binary64)
    (pll: toplevel_entities typ (LLVMAst.block typ * list (LLVMAst.block typ))),
    forall s, compile_w_main p data newState ≡ inr (s,pll) ->
    eutt (bisim_full [] s) (semantics_FSHCOL p data) (semantics_llvm pll).
Proof.
Admitted.

(** Relation bewteen the final states of evaluation and execution
    of DHCOL program.

    At this stage we do not care about memory or environemnts, and
    just compare return value of [main] function in LLVM with
    evaulation results of DSHCOL.
 *)

Lemma bisim_partial_memory_subrelation: forall σ helix_state llvm_state,
    let '(mem_helix, _) := helix_state in
    let '(mem_llvm, (ρ, (g, _))) := llvm_state in
    bisim_partial σ newState helix_state llvm_state -> memory_invariant σ newState mem_helix (mem_llvm, (ρ, g)).
Proof.
  intros σ helix_state llvm_state.
  repeat break_let.
  subst.
  intros H.
  auto.
Qed.

(* Lemma bisim_full_partial_subrelation: forall σ helix_state llvm_state, *)
(*     let '(mem_helix, v_helix) := helix_state in *)
(*     let '(m, ((ρ,_), (g, v))) := llvm_state in *)
(*     bisim_full σ helix_state llvm_state -> bisim_partial σ (mem_helix, tt) (mk_LLVM_sub_state_partial_from_mem (inr v) (m, (ρ, g))). *)
(* Proof. *)
(*   intros σ helix_state llvm_state. *)
(*   repeat break_let. *)
(*   subst. *)
(*   intros H. *)
(*   unfold mk_LLVM_sub_state_partial_from_mem. *)
(*   auto. *)
(* Qed. *)

  (* Top-level compiler correctness lemma  *)
  Theorem compiler_correct:
    forall (p:FSHCOLProgram)
      (data:list binary64)
      (pll: toplevel_entities typ (LLVMAst.block typ * list (LLVMAst.block typ))),
    forall s, compile_w_main p data newState ≡ inr (s,pll) ->
      eutt (bisim_final []) (semantics_FSHCOL p data) (semantics_llvm pll).
  Proof.
    intros p data pll s H.
    unfold compile_w_main, compile in H.
    destruct p.
    cbn in *.
    break_match_hyp; try inv_sum.
    break_let; cbn in *.
    break_match_hyp; try inv_sum.
    unfold ErrorWithState.evalErrS in *.
    break_match_hyp; try inv_sum.
    break_match_hyp; cbn in *; repeat try inv_sum.

    (*
    break_let; cbn in *; inv_sum.
    repeat (break_match_hyp || break_let); try inv_sum.

    eutt_hide_left.
    repeat rewrite app_assoc.
    repeat rewrite <- app_assoc.
    match goal with
      |- context[_ :: ?x ++ ?y ++ ?z ++ ?t] => remember x as f1; remember y as f2; remember t as f3; remember z as f4
    end.

    unfold semantics_llvm.
     *)

    (* break_match_goal. *)
    (* mcfg_of_modul *)
    (* Lemma semantics_llvm_red : *)
    (*   forall p, semantics_llvm p ≈ semantics_llvm p. *)
    (* Proof. *)
    (*   unfold semantics_llvm. *)
    (*   intros p. *)
    (*   unfold lift_sem_to_mcfg. *)
    (*   break_match_goal. *)
    (*   { *)
    (*     unfold semantics_llvm_mcfg, model_to_L3, denote_vellvm_init, denote_vellvm, translate_E_vellvm_mcfg. *)
    (*     simpl bind. *)
    (*     rewrite interp_to_L3_bind, translate_bind. *)
    (*     match goal with *)
    (*     | ?t ≈ _ => assert (t ≈ ITree.bind (lift_sem_to_mcfg (fun p =>  *)


    (* setoid_rewrite bind_bind. *)
    (*   unfold translate_E_vellvm_mcfg. *)
    (* setoid_rewrite (interp_to_L3_bind defined_intrinsics . *)

    (* unfold lift_sem_to_mcfg. *)
    (* break_match_goal. *)
    (* { *)
    (*   unfold semantics_llvm_mcfg, model_to_L3, denote_vellvm_init, denote_vellvm. *)
    (*   simpl bind. *)
    (*   unfold translate_E_vellvm_mcfg. *)
    (*   rewrite interp_to_L3_bind, translate_bind. *)

    (*   rewrite modul_of_toplevel_entities *)
    (*           cons, !modul_of_toplevel_entities_app in Heqo0. *)


    (*   repeat match goal with *)
    (*          | h: mcfg_of_modul _ (_ @ _) ≡ _ |- _ => *)
    (*            apply mcfg_of_app_modul in h; *)
    (*              destruct h as (? & ? & ?EQ & ?EQ & <-) *)
    (*          end. *)
    (*   Transparent map_option. *)
    (*   cbn in EQ. *)
    (*   injection EQ; clear EQ; intro EQ. *)
    (*   subst. l0. f1 . *)
    (*   cbn in EQ0. *)


    (* } *)

    (* { *)
    (*   (* The conversion from top level entities to modul failed *) *)
    (*   (* There is a toplevel entity with an empty list of instruction *) *)
    (*   admit. *)
    (* } *)



    (*         unfold global_YX,constArray in EQ1. *)

Admitted.
