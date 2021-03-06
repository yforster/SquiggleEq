Require Import bin_rels.
Require Import eq_rel.
Require Import universe.
Require Import LibTactics.
Require Import tactics.
Require Import Coq.Bool.Bool.
Require Import Coq.Program.Tactics.
Require Import Omega.
Require Import Coq.Program.Basics.
Require Import Coq.Lists.List.
Require Import Coq.Init.Notations.
Require Import UsefulTypes.
Require Import Coq.Classes.DecidableClass.
Require Import Coq.Classes.Morphisms.
Require Import list.

Require Import Recdef.
Require Import Eqdep_dec.
Require Import varInterface.

Class GenericTermSig (Opid : Type) : Type :=
{
(** the collection of operators in the language. For example, in lambda calculus, App and Lam are operators *)
(** Arities for each operator. An [Opid] [o] takes 
  [length (OpBindings o)] arguments. The number of bound variables in the ith argument is 
  specified by the ith member of [(OpBindings o)].
  For example this signature for Lambda is [[1]]. And it is [[0,0]] for App.
  A lambda takes one argument and that argument binds 1 variable. An application takes 2 arguments,
  each of which bind 0 variables.*)
  OpBindings : Opid -> list nat;
}.

Generalizable Variable Opid.

Inductive NTerm {NVar Opid} : Type :=
| vterm: NVar -> NTerm
| oterm: Opid -> list BTerm -> NTerm
with BTerm {NVar Opid} : Type :=
| bterm: (list NVar) -> NTerm -> BTerm.

Section terms.

 Context {NVar VarClass} `{VarType NVar VarClass} `{Deq Opid} {gts : GenericTermSig Opid}.
  
 Notation NTerm := (@NTerm NVar Opid).
 Notation BTerm := (@BTerm NVar Opid).

(*
  The [Opid] type contains one element corresponding to every operator
  of the language, e.g. lambda abstraction, funtion application,
  dependent function type constructor. As a more concrete example,
  the [NLambda] is the element of [Opid] that represents lambda
  abstractions.
  To construct a bound term([BTerm]), we need a list of variables and
  an [NTerm] (see the [bterm] constructor). As a concrete example,
   $ \lambda x.y$ is represented in this type
  as [(oterm  NLambda (bterm [x] (vterm y)))].
*)

(**
  It is a mutually inductive definition that simultaneously defines terms
  and bound terms. As mentioned before, the [vterm] constructor
  takes an [NVar] and constructs an [NTerm]. The other constructor([oterm])
  takes an [Opid] and a list of bound terms ([BTerm]s) and constructs an [NTerm].
  Note that not all members of [NTerm] are meaningful(well-formed).
  For example, the [Opid] corresponding to lambda abstractions must be
  provided with exactly one bound term as argument. Moreover, that
  bound term must have exactly one bound variable. So, we have a function
  [OpBindings] in type [Opid -> list nat] that specifies both the
  number of arguments and the number of bound variables in each argument([BTerm]).
  We will use it soon to define the subcollection of well-formed terms.
*)

(* begin hide *)


(*
Definition term_rel := NTerm -> NTerm -> Type.
*)


Definition isvar (t : NTerm) :=
  match t with
    | vterm _ => true
    | _ => false
  end.

Definition isvariable (t : NTerm) :=
  match t with
    | vterm _ => True
    | _ => False
  end.

Definition getOpid (n: NTerm) : option Opid :=
match n with
| vterm _ => None
| oterm o _ => Some o
end. 


(*Notation "x # b" := (bterm [x] b) (at level 70, right associativity).
(*Check [[ btermO (vterm(nvar 0))]] *)
(* Notation "< N >" := (btermO N). *)
Notation "\\ f" :=
  (oterm (Can NLambda) [[f]]) (at level 70, right associativity).

*)


(* ------ CONSTRUCTORS ------ *)


(* --- primitives --- *)

Definition mk_var (nv : NVar)  : NTerm := vterm nv.

(* end hide *)
(** %\noindent% Whenever we talk about the [NTerm] of a [BTerm], this is
what we would mean:

*)
Definition get_nt  (bt: BTerm ) : NTerm :=
 match bt with
 | bterm lv nt => nt
 end.

Definition get_vars  (bt: BTerm ) : list NVar :=
 match bt with
 | bterm lv nt => lv
 end.

Definition num_bvars (bt : BTerm) := length (get_vars bt).

(** % \noindent \\* % We define
    a predicate [nt_wf] on [NTerm] such that
    [nt_wf nt] asserts that [nt] is a well-formed term.  %\\* %
*)
Inductive nt_wf: NTerm -> [univ] :=
| wfvt: forall nv : NVar, nt_wf (vterm nv)
| wfot: forall (o: Opid) (lnt: list BTerm),
        (forall l, LIn l lnt -> bt_wf l)
         -> map (num_bvars) lnt 
            = OpBindings o
         -> nt_wf (oterm o lnt)
with bt_wf : BTerm -> [univ] :=
| wfbt : forall (lnv : list NVar) (nt: NTerm),
         nt_wf nt -> bt_wf (bterm lnv nt).


End terms.
(* closing the section because there is a problem with
  simpl and sections and mutual fixpoints
https://coq.inria.fr/bugs/show_bug.cgi?id=3343  
   *) 

(* --- variables --- *)

(** Just decidability of equality on variables suffices for these definitions.
  The full [VarType] may not be needed until [ssubst]*)
Fixpoint free_vars {NVar} `{Deq NVar} {Opid:Type}
  (t:NTerm) {struct t}: list NVar :=
  match t with
  | vterm v => [v]
  | oterm op bts => flat_map (@free_vars_bterm NVar _ Opid )  bts
  end
 with free_vars_bterm {NVar} `{Deq NVar} {Opid:Type}
    (bt : @BTerm NVar Opid)
  {struct bt} : list NVar :=
  match bt with
  | bterm  lv nt => remove_nvars lv (@free_vars NVar _  Opid nt)
  end.

Fixpoint allVars {NVar}  {Opid:Type}
  (t:NTerm) {struct t}: list NVar :=
  match t with
  | vterm v => [v]
  | oterm op bts => flat_map (@allVars_bterm NVar Opid )  bts
  end
 with allVars_bterm {NVar} {Opid:Type}
    (bt : @BTerm NVar Opid)
  {struct bt} : list NVar :=
  match bt with
  | bterm  lv nt => lv ++ (@allVars NVar  Opid nt)
  end.

Fixpoint bound_vars {NVar} `{Deq NVar} {Opid:Type} (t : NTerm) : list NVar :=
  match t with
  | vterm v => []
  | oterm op bts => flat_map (@bound_vars_bterm NVar _ Opid)  bts
  end
 with bound_vars_bterm {NVar} `{Deq NVar} {Opid:Type} (bt : @BTerm NVar Opid) 
  :list NVar :=
  match bt with
  | bterm lv nt => lv ++ bound_vars nt
  end.

Section termsCont.
Context {NVar VarClass} `{VarType NVar VarClass} `{Deq Opid} {gts : GenericTermSig Opid}.
Definition all_vars (t:@NTerm NVar Opid) : list NVar := free_vars t ++ bound_vars t.


Definition closed (t : @NTerm NVar Opid) := free_vars t = [].
(* Howe's T_0(L) *)
Definition isprogram (t : @NTerm NVar Opid) := closed t # nt_wf t.

Definition getVar (t: @NTerm NVar Opid) : option NVar :=
match t with
| vterm v => Some v
| _ => None
end.

End termsCont.

Fixpoint tmap {V1 V2 O1 O2  :Type} (fv: V1 -> V2) (fo : O1 -> O2) (t : @NTerm V1 O1) 
  : (@NTerm V2 O2) :=
match t with
| vterm v =>  vterm (fv v)
| oterm o lbt => oterm (fo o) (map (tmap_bterm fv fo) lbt)
end
with 
tmap_bterm {V1 V2 O1 O2  :Type} (fv: V1 -> V2) (fo : O1 -> O2) (t : @BTerm V1 O1) 
  : (@BTerm V2 O2) :=
match t with
| bterm lv nt => bterm (map fv lv) (tmap fv fo nt)
end.

Definition tvmap {V1 V2 O  :Type} (fv: V1 -> V2) : (@NTerm V1 O) -> (@NTerm V2 O) :=
tmap fv id.


Require Import String.


Definition flatten (l:list string) : string :=
  List.fold_left append  l EmptyString.

Fixpoint flattenDelim (d:string) (l:list string) {struct l}: string :=
match l with 
| nil => EmptyString
| h::tl => match tl with
          | nil => h
          | m::tm => flatten [h;d; flattenDelim d tl]
          end
end.
(*
Eval vm_compute in (flattenDelim "," []).
Eval vm_compute in (flattenDelim "," ["hello"]).
Eval vm_compute in (flattenDelim "," ["hello"; "how"]).
Eval vm_compute in (flattenDelim "," ["hello"; "how" ; "are"]).
*)

Definition newLineChar : Ascii.ascii := Ascii.ascii_of_nat 10.
Definition newLineString : string := String newLineChar EmptyString.

Fixpoint tprint {V O  :Type} (spaces:string) (fv: V -> string) (fo : O -> string) (t : @NTerm V O) 
  : string :=
match t with
| vterm v =>  flatten [fv v; newLineString]
| oterm o lbt => 
  flatten [(fo o); newLineString; flatten (map (bprint (append " " spaces) fv fo) lbt)]
end
with 
bprint {V O  :Type} (spaces:string) (fv: V -> string) (fo : O -> string) (t : @BTerm V O) 
  : string :=
match t with
| bterm lv nt =>  
  let pv := flattenDelim " " (map fv lv) in
  let pt := tprint spaces fv fo nt in
    flatten [spaces; pv; "." ; pt]
end.

(* Move. and replace in SquiggleEq.terms*)
Definition btMapNt {O O2 V} (f: @NTerm V O  -> @NTerm V O2)
   (b: @BTerm V O) : @BTerm V O2 :=
match b with
|bterm lv nt => bterm lv (f nt)
end.

Definition btSkipBinders {O V} (n:nat)
   (b: @BTerm O V) : @BTerm O V :=
match b with
|bterm lv nt => bterm (skipn n lv) nt
end.

Definition tvmap_bterm := 
fun {V1 V2 O : Type} (fv : V1-> V2) =>
  @tmap_bterm V1 V2 O O fv (@id O).

Definition getFirstBTermVars {V O }(t:list (@BTerm V O)) : list V:=
  match t with
  | (bterm lv _)::_ => lv
  | [] => []
  end.



