Require Import Coq.Strings.String.
Require Import Coq.Arith.Peano_dec.
Require Import MetaCoq.Template.All.

Require Import Helix.Util.Misc.
Require Import Helix.Util.VecSetoid.
Require Import Helix.Util.ListSetoid.
Require Import Helix.Util.OptionSetoid.
Require Import Helix.Util.FinNat.
Require Import Helix.Util.VecUtil.
Require Import Helix.HCOL.HCOL.
Require Import Helix.Util.WriterMonadNoT.
Require Import Helix.SigmaHCOL.Rtheta.
Require Import Helix.SigmaHCOL.SVector.
Require Import Helix.MSigmaHCOL.Memory.
Require Import Helix.MSigmaHCOL.MSigmaHCOL.
Require Import Helix.SigmaHCOL.SigmaHCOL.
Require Import Helix.MSigmaHCOL.MemVecEq.
Require Import Helix.SigmaHCOL.TSigmaHCOL.
Require Import Helix.Tactics.HelixTactics.

Require Import Switch.Switch.

Require Import MathClasses.interfaces.canonical_names.
Require Import MathClasses.misc.util.

(* This import must be after Vector stuff, so `const` will point to
   Basics.const not Vector.const. We need this to be able to unfold it
   in TemplateCoq, which does not understand qualified names (with
   ".") *)
Require Import Coq.Program.Basics.

Import MonadNotation.
Require Import Coq.Lists.List. Import ListNotations.
Open Scope string_scope.

Run TemplateProgram
    (mkSwitch string
              string_beq
              [("Helix.SigmaHCOL.SigmaHCOL.eUnion", "n_eUnion") ;
                 ("Helix.SigmaHCOL.SigmaHCOL.eT", "n_eT") ;
                 ("Helix.SigmaHCOL.SigmaHCOL.SHPointwise", "n_SHPointwise") ;
                 ("Helix.SigmaHCOL.SigmaHCOL.SHBinOp", "n_SHBinOp") ;
                 ("Helix.SigmaHCOL.SigmaHCOL.SHInductor", "n_SHInductor") ;
                 ("Helix.SigmaHCOL.SigmaHCOL.IUnion", "n_IUnion") ;
                 ("Helix.SigmaHCOL.SigmaHCOL.ISumUnion", "n_ISumUnion") ;
                 ("Helix.SigmaHCOL.SigmaHCOL.IReduction", "n_IReduction") ;
                 ("Helix.SigmaHCOL.SigmaHCOL.SHCompose", "n_SHCompose") ;
                 ("Helix.SigmaHCOL.TSigmaHCOL.SafeCast", "n_SafeCast") ;
                 ("Helix.SigmaHCOL.TSigmaHCOL.UnSafeCast", "n_UnSafeCast") ;
                 ("Helix.SigmaHCOL.TSigmaHCOL.HTSUMUnion", "n_HTSUMUnion")
              ]
              "SHCOL_Op_Names" "parse_SHCOL_Op_Name"
    ).

Fixpoint compileSHCOL2MSHCOL (t:term) (fuel: nat) {struct fuel}: TemplateMonad (term) :=
  match fuel with
  | O => tmFail "expression complexity limit reached"
  | S fuel' =>
    match t with
    | tConst cname _ =>
      tmPrint ("Trying to unfold constant" ++ cname) ;;
              et <- tmUnquote t ;;
              (match et with
               | existT_typed_term _ e =>
                 e' <-  tmEval (unfold cname) e ;;
                    t' <- tmQuote e' ;;
                    match t' with
                    | tConst cname' _ =>
                      if string_beq cname cname' then
                        tmFail ("Could not unfold constant " ++ cname')
                      else
                        tmPrint ("Sucessfully nfolded constant " ++ cname) ;;
                                compileSHCOL2MSHCOL t' fuel'
                    | _ =>
                      tmPrint ("Sucessfully nfolded constant " ++ cname) ;;
                              compileSHCOL2MSHCOL t' fuel'
                    end
               end)
    | tLambda (nNamed n) vt b =>
      tmPrint ("lambda " ++ n)  ;;
              c <- compileSHCOL2MSHCOL b fuel' ;;
              tmReturn(tLambda (nNamed n) vt c)
    | tApp (tConst opname u) args =>
      match parse_SHCOL_Op_Name opname, args with
      | Some n_eUnion, [fm ; svalue; o ; b ; bc] =>
        tmPrint "eUnion" ;;
                tmReturn  (tApp (tConst "Helix.MSigmaHCOL.MSigmaHCOL.MSHeUnion" u)
                                [o; b ; bc])
      | Some n_eT, [fm ; svalue; i ; b ; bc] =>
        tmPrint "eT" ;;
                tmReturn  (tApp (tConst "Helix.MSigmaHCOL.MSigmaHCOL.MSHeT" u)
                                [i; b; bc])
      | Some n_SHPointwise, [fm ; svalue; n ; f ; pF ] =>
        tmPrint "SHPointwise" ;;
                tmReturn  (tApp (tConst "Helix.MSigmaHCOL.MSigmaHCOL.MSHPointwise" u)
                                [n; f; pF])
      | Some n_SHBinOp, [fm ; svalue; o ; f ; pF]
        =>
        tmPrint "SHBinOp" ;;
                tmReturn  (tApp (tConst "Helix.MSigmaHCOL.MSigmaHCOL.MSHBinOp" u)
                                [o; f; pF])
      | Some n_SHInductor, [fm ; svalue; n ; f ; pF ; z] =>
        tmPrint "SHInductor" ;;
                tmReturn  (tApp (tConst "Helix.MSigmaHCOL.MSigmaHCOL.MSHInductor" u)
                                [n; f; pF; z])
      | Some n_IUnion, [svalue; i ; o ; n ; f ; pF ; scompat ; op_family] =>
        tmPrint "IUnion" ;;
                c <- compileSHCOL2MSHCOL op_family fuel' ;;
                tmReturn  (tApp (tConst "Helix.MSigmaHCOL.MSigmaHCOL.MSHIUnion" u)
                                [i; o; n; c])
      | Some n_ISumUnion, [i ; o ; n ; op_family] =>
        (* Same as [IUnion] *)
        tmPrint "ISumUnion" ;;
                c <- compileSHCOL2MSHCOL op_family fuel';;
                tmReturn  (tApp (tConst "Helix.MSigmaHCOL.MSigmaHCOL.MSHIUnion" u)
                                [i; o; n; c])
      | Some n_IReduction, [svalue; i ; o ; n ; f ; pF ; scompat ; op_family] =>
        tmPrint "IReduction" ;;
                c <- compileSHCOL2MSHCOL op_family fuel' ;;
                tmReturn  (tApp (tConst "Helix.MSigmaHCOL.MSigmaHCOL.MSHIReduction" u)
                                [i; o; n; svalue; f; pF; c])
      | Some n_SHCompose, [fm ; svalue; i1 ; o2 ; o3 ; op1 ; op2] =>
        tmPrint "SHCompose" ;;
                c1 <- compileSHCOL2MSHCOL op1 fuel' ;;
                c2 <- compileSHCOL2MSHCOL op2 fuel' ;;
                tmReturn  (tApp (tConst "Helix.MSigmaHCOL.MSigmaHCOL.MSHCompose" u)
                                [i1; o2; o3; c1; c2])
      | Some n_SafeCast, [svalue; i ; o ; c] =>
        tmPrint "SafeCast" ;;
                compileSHCOL2MSHCOL c fuel'
      | Some n_UnSafeCast, [svalue; i ; o ; c] =>
        tmPrint "UnSafeCast" ;;
                compileSHCOL2MSHCOL c fuel'
      | Some n_HTSUMUnion, [fm ; i ; o ; svalue; dot ; _ ; _; op1 ; op2] =>
        tmPrint "HTSumunion" ;;
                c1 <- compileSHCOL2MSHCOL op1 fuel' ;;
                c2 <- compileSHCOL2MSHCOL op2 fuel' ;;
                tmReturn  (tApp (tConst "Helix.MSigmaHCOL.MSigmaHCOL.MHTSUMUnion" u)
                                [i; o; dot; c1; c2])
      | None, _ =>
        tmFail ("Usupported function call " ++ opname)
      | _, _ =>
        tmFail ("Usupported arguments "
                  ++ string_of_list string_of_term args
                  ++ "for SHCOL operator " ++ opname)
      end
    | _ as t =>
      tmFail ("Usupported SHCOL syntax " ++ (AstUtils.string_of_term t))
    end
  end.

Fixpoint tmUnfoldList {A:Type} (names:list string) (e:A): TemplateMonad A :=
  match names with
  | [] => tmReturn e
  | x::xs =>  u <- @tmEval (unfold x) A e ;;
               tmUnfoldList xs u
  end.

Definition reifySHCOL {A:Type} (expr: A)
           (fuel: nat)
           (res_name: string)
           (lemma_name:  string): TemplateMonad unit
  :=
    let unfold_names := ["SHFamilyOperatorCompose"; "IgnoreIndex"; "Fin1SwapIndex"; "Fin1SwapIndex2"; "IgnoreIndex2"; "mult_by_nth"; "plus"; "mult"; "const"] in
    eexpr <- tmUnfoldList unfold_names expr ;;
          ast <- @tmQuote A eexpr ;;
          (* tmPrint ("AST" ++ (AstUtils.string_of_term ast)) ;; *)
          mast <- compileSHCOL2MSHCOL ast fuel ;;
          (* tmPrint ("MAST" ++ (AstUtils.string_of_term mast)) ;; *)
          mexpr <- tmUnquote mast ;;
          (match mexpr with
           | existT_typed_term mexprt mexprv =>
             mexpr' <- tmEval (unfold "my_projT1") mexprv ;;
                    mshcol_def <- tmDefinition res_name mexpr'
                    ;; tmReturn tt
           end).

(* Testing only *)
(*
Require Import Omega.
Program Definition foo := @eUnion Monoid_RthetaFlags CarrierAz 10 3 _.
Next Obligation. omega. Defined.

Test Quote foo.

Obligation Tactic := idtac.
Run TemplateProgram (reifySHCOL foo 100 "foo_def" "foo_lemma").
Check foo_def.
Print foo_def.

Lemma foo_lemma:
  SH_MSH_Operator_compat
    (@eUnion Monoid_RthetaFlags CarrierAz 10 3 foo_obligation_1)
    (@MSHeUnion 10 3 foo_obligation_1).
Proof.
  typeclasses eauto.
Qed.
*)
