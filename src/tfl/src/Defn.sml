structure Defn :> Defn =
struct

open HolKernel Parse Drule Conv 
     Rules wfrecUtils Functional Induction pairTools DefnBase;

type hol_type     = Type.hol_type
type term         = Term.term
type thm          = Thm.thm
type conv         = Abbrev.conv
type tactic       = Abbrev.tactic
type thry         = TypeBase.typeBase
type proofs       = GoalstackPure.proofs
type defn         = DefnBase.defn
type absyn        = Absyn.absyn
type ppstream     = Portable.ppstream
type 'a quotation = 'a Portable.frag list

infixr 3 -->;
infix 3 |->;
infix 4 ##; 

fun ERR func mesg = HOL_ERR{origin_structure = "Defn", 
                            origin_function = func, message = mesg};

(*---------------------------------------------------------------------------
      Miscellaneous support
 ---------------------------------------------------------------------------*)

val monitoring = ref true;

fun enumerate l = map (fn (x,y) => (y,x)) (Lib.enumerate 0 l);

fun drop [] x = x
  | drop (_::t) (_::rst) = drop t rst
  | drop _ _ = raise ERR "drop" "";

fun variants FV vlist =
  fst
    (rev_itlist
       (fn v => fn (V,W) =>
           let val v' = variant W v in (v'::V, v'::W) end) vlist ([],FV));

fun make_definition thry s tm = (Const_def.new_definition(s,tm), thry)

fun head tm = head (rator tm) handle _ => tm;
fun all_fns eqns = 
  mk_set (map (head o lhs o #2 o strip_forall) (strip_conj eqns));

fun dest_hd_eqn eqs = 
  let val hd_eqn = if is_conj eqs then #conj1(dest_conj eqs) else eqs
      val {lhs,rhs} = dest_eq hd_eqn
  in (strip_comb lhs, rhs)
  end;

fun extract_info db = 
 let val (rws,congs) = rev_itlist
     (fn tyinfo => fn (R,C) => 
         (TypeBase.case_def_of tyinfo::R, TypeBase.case_cong_of tyinfo::C))
     (TypeBase.listItems db) ([],[]) 
 in {case_congs=congs, case_rewrites=rws}
 end;


(*---------------------------------------------------------------------------
    Support for automatically building names to store definitions 
    (and the consequences thereof) with in the current theory. Somewhat
    ad hoc, but I don't know a better way!
 ---------------------------------------------------------------------------*)

val ind_suffix = ref "_ind";
val def_suffix = ref "_def";

fun indSuffix s = (s ^ !ind_suffix);
fun defSuffix s = (s ^ !def_suffix);
fun defPrim s   = defSuffix(s^"_primitive");
fun defExtract(s,n) = defSuffix(s^"_extract"^Lib.int_to_string n);
fun argMunge s = defSuffix(s^"_arg_munge");
fun auxStem stem   = stem^"_aux";
fun unionStem stem = stem^"_UNION";

val imp_elim = 
 let val P = mk_var{Name="P",Ty=Type.bool}
     val Q = mk_var{Name="Q",Ty=Type.bool}
     val R = mk_var{Name="R",Ty=Type.bool}
     val PimpQ = mk_imp{ant=P,conseq=Q}
     val PimpR = mk_imp{ant=P,conseq=R}
     val tm = mk_eq{lhs=PimpQ,rhs=PimpR}
     val tm1 = mk_imp{ant=P,conseq=tm}
     val th1 = DISCH tm (DISCH P (ASSUME tm))
     val th2 = ASSUME tm1
     val th2a = ASSUME P 
     val th3 = MP th2 th2a
     val [th4,th5] = CONJUNCTS 
                      (EQ_MP (SPECL[PimpQ, PimpR] boolTheory.EQ_IMP_THM) th3)
     val [th4a,th5a] = map (DISCH P o funpow 2 UNDISCH) [th4,th5]
     val th4b = DISCH PimpQ th4a
     val th5b = DISCH PimpR th5a
     val th6 = DISCH tm1 (IMP_ANTISYM_RULE th4b th5b)
     val th7 = DISCH tm (DISCH P (ASSUME tm))
 in GENL [P,Q,R] 
         (IMP_ANTISYM_RULE th6 th7)
 end;

local open Psyntax
in
fun inject ty [v] = [v]
  | inject ty (v::vs) = 
     let val {Args = [lty,rty],...} = Type.dest_type ty 
         val res = mk_comb(mk_const("INL", lty-->ty),v)
         val inr = curry mk_comb (mk_const("INR", rty-->ty))
     in
       res::map inr (inject rty vs)
     end

fun project ty M = 
 if is_vartype ty then [M]
 else case dest_type ty 
       of ("sum",[lty,rty]) =>
            mk_comb(mk_const("OUTL", type_of M-->lty),M)
            :: project rty (mk_comb(mk_const("OUTR", type_of M-->rty),M))
        |  _  => [M];
end;


(*---------------------------------------------------------------------------*
 * We need a "smart" MP. th1 can be less quantified than th2, so th2 has     *
 * to be specialized appropriately. We assume that all the "local"           *
 * variables are quantified first.                                           *
 *---------------------------------------------------------------------------*)

fun ModusPonens th1 th2 = 
  let val V1 = #1(strip_forall(#ant(dest_imp(concl th1))))
      val V2 = #1(strip_forall(concl th2))
      val diff = Lib.op_set_diff Term.aconv V2 V1
      fun loop th = 
        if is_forall(concl th) 
        then let val {Bvar,Body} = dest_forall (concl th)
             in if Lib.op_mem Term.aconv Bvar diff
                then loop (SPEC Bvar th) else th
             end
        else th
  in 
    MP th1 (loop th2)
  end
  handle _ => raise ERR "ModusPonens" "failed";


(*
fun is_abbrev  (ABBREV _)  = true | is_abbrev _  = false;
fun is_primrec (PRIMREC _) = true | is_primrec _ = false;
fun is_nonrec  (NONREC _)  = true | is_nonrec _  = false;
fun is_nestrec (NESTREC _) = true | is_nestrec _ = false;
fun is_mutrec  (MUTREC _)  = true | is_mutrec _  = false;
*)

fun eqns_of (ABBREV  {eqn, ...}) = eqn
  | eqns_of (NONREC  {eqs, ...}) = eqs
  | eqns_of (PRIMREC {eqs, ...}) = eqs
  | eqns_of (STDREC  {eqs, ...}) = eqs
  | eqns_of (NESTREC {eqs, ...}) = eqs
  | eqns_of (MUTREC  {eqs, ...}) = eqs;

fun eqnl_of d = CONJUNCTS (eqns_of d)

fun aux_defn (NESTREC {aux, ...}) = SOME aux
  | aux_defn     _  = NONE;

fun union_defn (MUTREC {union, ...}) = SOME union
  | union_defn     _  = NONE;

fun ind_of (ABBREV _)           = NONE
  | ind_of (NONREC  {ind, ...}) = SOME ind
  | ind_of (PRIMREC {ind, ...}) = SOME ind
  | ind_of (STDREC  {ind, ...}) = SOME ind
  | ind_of (NESTREC {ind, ...}) = SOME ind
  | ind_of (MUTREC  {ind, ...}) = SOME ind;


fun params_of (ABBREV _)  = []
  | params_of (NONREC _)  = []
  | params_of (PRIMREC _) = []
  | params_of (STDREC  {SV, ...}) = SV
  | params_of (NESTREC {SV, ...}) = SV
  | params_of (MUTREC  {SV, ...}) = SV;

fun schematic defn = not(List.null (params_of defn));

fun tcs_of (ABBREV _)  = []
  | tcs_of (NONREC _)  = []
  | tcs_of (PRIMREC _) = []
  | tcs_of (STDREC  {ind, ...}) = hyp ind
  | tcs_of (NESTREC {ind, ...}) = hyp ind  (* this is wrong! *)
  | tcs_of (MUTREC  {ind, ...}) = hyp ind;


fun reln_of (ABBREV _)  = NONE
  | reln_of (NONREC _)  = NONE
  | reln_of (PRIMREC _) = NONE
  | reln_of (STDREC  {R, ...}) = SOME R
  | reln_of (NESTREC {R, ...}) = SOME R
  | reln_of (MUTREC  {R, ...}) = SOME R;


fun nUNDISCH n th = if n<1 then th else nUNDISCH (n-1) (UNDISCH th)

fun INST_THM theta th =
  let val asl = hyp th
      val th1 = rev_itlist DISCH asl th
      val th2 = INST_TY_TERM theta th1
  in
   nUNDISCH (length asl) th2
  end;

fun isubst (tmtheta,tytheta) tm = subst tmtheta (inst tytheta tm);

fun inst_defn (STDREC{eqs,ind,R,SV,stem}) theta =
      STDREC {eqs=INST_THM theta eqs,
              ind=INST_THM theta ind,
              R=isubst theta R,
              SV=map (isubst theta) SV, stem=stem}
  | inst_defn (NESTREC{eqs,ind,R,SV,aux,stem}) theta =
      NESTREC {eqs=INST_THM theta eqs,
               ind=INST_THM theta ind,
               R=isubst theta R,
               SV=map (isubst theta) SV,
               aux=inst_defn aux theta, stem=stem}
  | inst_defn (MUTREC{eqs,ind,R,SV,union,stem}) theta =
      MUTREC {eqs=INST_THM theta eqs,
              ind=INST_THM theta ind,
              R=isubst theta R,
              SV=map (isubst theta) SV,
              union=inst_defn union theta, stem=stem}
  | inst_defn (PRIMREC{eqs,ind,bind}) theta =
      PRIMREC{eqs=INST_THM theta eqs,
              ind=INST_THM theta ind, bind=bind}
  | inst_defn (NONREC {eqs,ind,stem}) theta = 
      NONREC {eqs=INST_THM theta eqs, 
              ind=INST_THM theta ind, stem=stem}
  | inst_defn (ABBREV {eqn,bind}) theta = 
      ABBREV {eqn=INST_THM theta eqn,bind=bind}
  

fun set_reln def R =
   case reln_of def
    of NONE => def
     | SOME Rpat => inst_defn def (Term.match_term Rpat R);


fun PROVE_HYPL thl th =
  let val thm = itlist PROVE_HYP thl th
  in if null(hyp thm) then thm
     else raise ERR "PROVE_HYPL" "remaining termination conditions"
  end;


(* Should perhaps be extended to existential theorems. *)

fun elim_tcs (STDREC {eqs, ind, R, SV,stem}) thms =
     STDREC{R=R, SV=SV, stem=stem,
            eqs=PROVE_HYPL thms eqs,
            ind=PROVE_HYPL thms ind}
  | elim_tcs (NESTREC {eqs, ind, R,  SV, aux, stem}) thms =
     NESTREC{R=R, SV=SV, stem=stem,
            eqs=PROVE_HYPL thms eqs,
            ind=PROVE_HYPL thms ind,
            aux=elim_tcs aux thms}
  | elim_tcs (MUTREC {eqs, ind, R, SV, union, stem}) thms =
     MUTREC{R=R, SV=SV, stem=stem,
            eqs=PROVE_HYPL thms eqs,
            ind=PROVE_HYPL thms ind,
            union=elim_tcs union thms}
  | elim_tcs x _ = x;


local fun isT M = (#Name(dest_const M) = "T") handle HOL_ERR _ => false
      val lem = let val M = mk_var{Name="M",Ty=Type.bool}
                    val M1 = mk_var{Name="M1",Ty=Type.bool}
                    val P = mk_var{Name="P",Ty=Type.bool}
                    val tm1 = mk_eq{lhs=M,rhs=M1}
                    val tm2 = mk_imp{ant=M,conseq=P}
                in DISCH tm1 (DISCH tm2 (SUBS [ASSUME tm1] (ASSUME tm2)))
                end
in
fun simp_assum conv tm th =
  let val th' = DISCH tm th
      val tmeq = conv tm
      val tm' = rhs(concl tmeq)
  in
    if isT tm' then MP th' (EQT_ELIM tmeq)
    else UNDISCH(MATCH_MP (MATCH_MP lem tmeq) th')
  end
end;

fun SIMP_HYPL conv th = itlist (simp_assum conv) (hyp th) th;

fun simp_tcs (STDREC {eqs, ind, R, SV, stem}) conv =
     STDREC{R=rhs(concl(conv R)), SV=SV, stem=stem,
            eqs=SIMP_HYPL conv eqs,
            ind=SIMP_HYPL conv ind}
  | simp_tcs (NESTREC {eqs, ind, R,  SV, aux, stem}) conv =
     NESTREC{R=rhs(concl(conv R)), SV=SV, stem=stem,
            eqs=SIMP_HYPL conv eqs,
            ind=SIMP_HYPL conv ind,
            aux=simp_tcs aux conv}
  | simp_tcs (MUTREC {eqs, ind, R, SV, union, stem}) conv =
     MUTREC{R=rhs(concl(conv R)), SV=SV, stem=stem,
            eqs=SIMP_HYPL conv eqs,
            ind=SIMP_HYPL conv ind,
            union=simp_tcs union conv}
  | simp_tcs x _ = x;


fun TAC_HYPL tac th = 
  PROVE_HYPL (mapfilter (C (curry Tactical.prove) tac) (hyp th)) th;

fun prove_tcs (STDREC {eqs, ind, R, SV, stem}) tac =
     STDREC{R=R, SV=SV, stem=stem,
            eqs=TAC_HYPL tac eqs,
            ind=TAC_HYPL tac ind}
  | prove_tcs (NESTREC {eqs, ind, R,  SV, aux, stem}) tac =
     NESTREC{R=R, SV=SV, stem=stem,
            eqs=TAC_HYPL tac eqs,
            ind=TAC_HYPL tac ind,
            aux=prove_tcs aux tac}
  | prove_tcs (MUTREC {eqs, ind, R, SV, union, stem}) tac =
     MUTREC{R=R, SV=SV, stem=stem,
            eqs=TAC_HYPL tac eqs,
            ind=TAC_HYPL tac ind,
            union=prove_tcs union tac}
  | prove_tcs x _ = x;


(*---------------------------------------------------------------------------
   Store definition information to disk. Currently, just writes out the
   eqns and induction theorem. A more advanced implementation would 
   write things out so that, when the exported theory is reloaded, the
   defn datastructure is rebuilt. This would give a seamless view of 
   things. I really should do this.

   Note that we would need to save union and aux info only when 
   termination has not been proved for a nested recursion.
 ---------------------------------------------------------------------------*)

fun been_stored s =
  Lib.say ("Definition has been stored under " 
           ^Lib.quote s
           ^".\n");

fun store(stem,eqs,ind) = 
  let val eqs_bind = defSuffix stem
      val ind_bind = indSuffix stem
      val   _  = save_thm(ind_bind, ind)
      val eqns = save_thm(eqs_bind, eqs)
  in 
    Lib.say (String.concat
       [   "Equations stored under ", Lib.quote eqs_bind, 
        ".\nInduction stored under ", Lib.quote ind_bind, ".\n"])
  end;

fun handle_nested (stem,eqs,ind) =
  if null(hyp eqs) 
  then store(stem,eqs,ind)
  else raise ERR "store_defn" 
   "Nested mutually recursive function with unproven termination conditions";

fun save_defn (ABBREV {bind, ...}) = been_stored bind
  | save_defn (PRIMREC{bind, ...}) = been_stored bind
  | save_defn (NONREC {eqs, ind, stem}) = store(stem,eqs,ind)
  | save_defn (STDREC {eqs, ind, stem, ...}) = store(stem,eqs,ind)
  | save_defn (MUTREC {eqs, ind, stem, union, ...}) = 
      (case union 
        of NESTREC _ => handle_nested (stem,eqs,ind)
         | otherwise => store(stem,eqs,ind))
  | save_defn (NESTREC{eqs,ind,stem, ...}) = handle_nested (stem,eqs,ind);


(*---------------------------------------------------------------------------
        Termination condition extraction
 ---------------------------------------------------------------------------*)

fun extraction_thms thy = 
 let val {case_rewrites,case_congs} = extract_info thy
 in 
    (case_rewrites, case_congs@read_congs())
 end;

fun extract FV context_congs f (proto_def,WFR) = 
 let val R = rand WFR
     val CUT_LEM = ISPECL [f,R] relationTheory.RESTRICT_LEMMA
     val restr_fR = rator(rator(#lhs(dest_eq
                      (#conseq(dest_imp (concl (SPEC_ALL CUT_LEM)))))))
     fun mk_restr p = mk_comb{Rator=restr_fR, Rand=p}
 in fn (p,th) => 
    let val nested_ref = ref false
        val th' = CONTEXT_REWRITE_RULE 
                   (mk_restr p, f,FV@free_vars(concl th), nested_ref)
                   {thms=[CUT_LEM], congs=context_congs, th=th}
    in 
      (th', Lib.op_set_diff aconv (hyp th') [proto_def,WFR],!nested_ref)
    end
end;


(*---------------------------------------------------------------------------
 * Pair patterns with termination conditions. The full list of patterns for
 * a definition is merged with the TCs arising from the user-given clauses.
 * There can be fewer clauses than the full list, if the user omitted some 
 * cases. This routine is used to prepare input for mk_induction.
 *---------------------------------------------------------------------------*)

fun merge full_pats TCs =
let fun insert (p,TCs) =
      let fun insrt ((x as (h,[]))::rst) = 
                 if (aconv p h) then (p,TCs)::rst else x::insrt rst
            | insrt (x::rst) = x::insrt rst
            | insrt[] = raise ERR"merge.insert" "pat not found"
      in insrt end
    fun pass ([],ptcl_final) = ptcl_final
      | pass (ptcs::tcl, ptcl) = pass(tcl, insert ptcs ptcl)
in 
  pass (TCs, map (fn p => (p,[])) full_pats)
end;


(*----------------------------------------------------------------------------
 
                     PRINCIPLES OF DEFINITION
 
 ----------------------------------------------------------------------------*)


(*---------------------------------------------------------------------------*
 * This basic principle of definition takes a functional M and a relation R  *
 * and specializes the following theorem                                     *
 *                                                                           *
 *    |- !M R f. (f = WFREC R M) ==> WF R ==> !x. f x = M (f%R,x) x          *
 *                                                                           *
 * to them (getting "th1", say). Then we make the definition "f = WFREC R M" *
 * and instantiate "th1" to the constant "f" (getting th2). Then we use the  *
 * definition to delete the first antecedent to th2. Hence the result in     *
 * the "corollary" field is                                                  *
 *                                                                           *
 *    |-  WF R ==> !x. f x = M (f%R,x) x                                     *
 *                                                                           *
 *---------------------------------------------------------------------------*)

fun prim_wfrec_definition thy name {R, functional} =
 let val {Bvar,...} = dest_abs functional
     val {Name,...} = dest_var Bvar  (* Intended name of definition *)
     val cor1 = ISPEC functional relationTheory.WFREC_COROLLARY
     val cor2 = ISPEC R cor1
     val f_eq_WFREC_R_M = (#ant o dest_imp o #Body o dest_forall o concl) cor2
     val {lhs,rhs} = dest_eq f_eq_WFREC_R_M
     val {Ty, ...} = dest_var lhs
     val def_term = mk_eq{lhs=mk_var{Name=Name,Ty=Ty}, rhs=rhs}
     val (def_thm,thy1) = make_definition thy name def_term
     val f = Lib.trye hd (snd (strip_comb (concl def_thm)))
     val cor3 = ISPEC f cor2
 in 
 {theory = thy1, def=def_thm, corollary=MP cor3 def_thm}
 end
 handle HOL_ERR _ => raise ERR"prim_wfrec_definition" "";




(*--------------------------------------------------------------------------*
 * This is a wrapper for "prim_wfrec_definition": it builds a functional,   *
 * calls "prim_wfrec_definition", then specializes the result. This gives   *
 * a list of rewrite rules where the right hand sides are quite ugly, so we *
 * simplify to get rid of the case statements. In essence, this function    *
 * performs pre- and post-processing for patterns. As well, after           *
 * simplification, termination conditions are extracted.                    *
 *--------------------------------------------------------------------------*)

fun gen_wfrec_definition thy nm {R, eqs} =
 let val {functional,pats} = mk_functional thy eqs
     val given_pats = givens pats
     val {def,corollary,theory} = 
           prim_wfrec_definition thy nm {R=R, functional=functional}
     val {lhs=f,...} = dest_eq(concl def)
     val WFR         = #ant(dest_imp(concl corollary))
     val corollary'  = UNDISCH corollary  (* put WF R on assums *)
     val corollaries = map (C SPEC corollary') given_pats
     val (case_rewrites,context_congs) = extraction_thms thy
     val corollaries'  = map (simplify case_rewrites) corollaries
     val Xtract        = extract [] context_congs f (concl def,WFR)
     val (rules,TCs,_) = unzip3 (map Xtract (zip given_pats corollaries'))
     val mk_cond_rule  = FILTER_DISCH_ALL(not o aconv WFR)
     val rules1        = LIST_CONJ(map mk_cond_rule rules)
     val TCs1          = map (map gen_all) TCs (* for induction *)
 in
   {theory = theory,   (* holds def, if it's needed *)
    rules = rules1,
    full_pats_TCs = merge (map pat_of pats) (zip given_pats TCs1), 
    TCs = TCs1, 
    patterns = pats}
 end;


(*---------------------------------------------------------------------------*
 * Perform TC extraction without making a definition.                        *
 *---------------------------------------------------------------------------*)

type wfrec_eqns_result = {WFR : term, 
                          SV : term list,
                          proto_def : term,
                          extracta  : (thm * term list * bool) list,
                          pats  : pattern list}

fun wfrec_eqns thy eqns =
 let val {functional,pats} = mk_functional thy eqns
     val SV = free_vars functional    (* schematic variables *)
     val {Bvar=f, Body} = dest_abs functional
     val {Bvar=x, ...} = dest_abs Body
     val {Name, Ty=fty} = dest_var f
     val (f_dty, f_rty) = Type.dom_rng fty
     val WFREC_THM0 = ISPEC functional relationTheory.WFREC_COROLLARY
     val R = variant (free_vars eqns) 
                     (#Bvar(dest_forall(concl WFREC_THM0)))
     val WFREC_THM = ISPECL [R, f] WFREC_THM0
     val tmp = fst(wfrecUtils.strip_imp(concl WFREC_THM))
     val proto_def = Lib.trye hd tmp
     val WFR = Lib.trye (hd o tl) tmp
     val R1 = rand WFR
     val corollary' = funpow 2 UNDISCH WFREC_THM
     val given_pats = givens pats
     val corollaries = map (C SPEC corollary') given_pats
     val (case_rewrites,context_congs) = extraction_thms thy
     val corollaries' = map (simplify case_rewrites) corollaries
     val Xtract = extract [R1] context_congs f (proto_def,WFR)
 in 
    {proto_def=proto_def, 
     SV=Lib.sort Term.term_lt SV,
     WFR=WFR, 
     pats=pats,
     extracta = map Xtract (zip given_pats corollaries')}
 end;


(*---------------------------------------------------------------------------*
 * Define the constant after extracting the termination conditions. The      *
 * wellfounded relation used in the definition is computed by using the      *
 * choice operator on the extracted conditions (plus the condition that      *
 * such a relation must be wellfounded).                                     *
 *                                                                           *
 * There are three flavours of recursion: standard, nested, and mutual.      *
 *                                                                           *
 *  A "standard" recursion is one that is not mutual or nested.              *
 *---------------------------------------------------------------------------*)

fun stdrec thy bindstem {proto_def,SV,WFR,pats,extracta} =
 let val R1 = rand WFR
     val f = lhs proto_def
     val (extractants,TCl_0,_) = unzip3 extracta
     fun gen_all away tm = 
        let val FV = free_vars tm
        in itlist (fn v => fn tm =>
              if mem v away then tm else mk_forall{Bvar=v,Body=tm}) FV tm
        end
     val TCs_0 = op_U aconv TCl_0
     val TCl = map (map (gen_all (R1::SV))) TCl_0
     val TCs = op_U aconv TCl
     val full_rqt = WFR::TCs
     val R2 = mk_select{Bvar=R1, Body=list_mk_conj full_rqt}
     val R2abs = rand R2
     val fvar = mk_var{Name = #Name (dest_var f),
                  Ty = itlist (curry op-->) (map type_of SV) (type_of f)}
     val fvar_app = list_mk_comb(fvar,SV)
     val (def,theory) = make_definition thy (defPrim bindstem)
                          (subst [f |-> fvar_app, R1 |-> R2] proto_def)
     val fconst = fst(strip_comb(lhs(snd(strip_forall(concl def)))))
     val disch'd = itlist DISCH (proto_def::WFR::TCs_0) (LIST_CONJ extractants)
     val inst'd = SPEC (list_mk_comb(fconst,SV))
                       (SPEC R2 (GENL [R1, f] disch'd))
     val def' = MP inst'd (SPEC_ALL def)
     val var_wits = LIST_CONJ (map ASSUME full_rqt)
     val TC_choice_thm = 
           MP (BETA_RULE(ISPECL[R2abs, R1] boolTheory.SELECT_AX)) var_wits
 in 
    {theory = theory, R=R1, SV=SV,
     rules = rev_itlist (C ModusPonens) (CONJUNCTS TC_choice_thm) def',
     full_pats_TCs = merge (map pat_of pats) (zip (givens pats) TCl),
     patterns = pats}
 end;


(*---------------------------------------------------------------------------
      Nested recursion.
 ---------------------------------------------------------------------------*)

fun nestrec thy bindstem {proto_def,SV,WFR,pats,extracta} =
 let val R1 = rand WFR
     val {lhs=f,rhs=rhs_proto_def} = dest_eq proto_def
     (* make parameterized definition *)
     val {Name,Ty} = Lib.trye dest_var f
     val aux_name = Name^"_aux"
     val faux = mk_var{Name=aux_name, 
                       Ty = itlist (curry (op-->)) 
                                   (map type_of (R1::SV)) Ty}
     val aux_bindstem = auxStem bindstem
     val (def,theory) = 
           make_definition thy (defSuffix aux_bindstem)
               (mk_eq{lhs=list_mk_comb(faux,R1::SV), rhs=rhs_proto_def})
     val def' = SPEC_ALL def
     val faux_capp = lhs(concl def')
     val faux_const = #1(strip_comb faux_capp)
     val (extractants,TCl_0,_) = unzip3 extracta
     val TCs_0 = op_U aconv TCl_0
     val disch'd = itlist DISCH (proto_def::WFR::TCs_0) (LIST_CONJ extractants)
     val inst'd = GEN R1 (MP (SPEC faux_capp (GEN f disch'd)) def')
     fun kdisch keep th = 
       itlist (fn h => fn th => if op_mem aconv h keep then th else DISCH h th)
              (hyp th) th
     val disch'dl_0 = map (DISCH proto_def o
                           DISCH WFR o kdisch [proto_def,WFR])
                        extractants
     val disch'dl_1 = map (fn d => MP (SPEC faux_capp (GEN f d)) def')
                          disch'dl_0
     fun gen_all away tm = 
        let val FV = free_vars tm
        in itlist (fn v => fn tm =>
              if mem v away then tm else mk_forall{Bvar=v,Body=tm}) FV tm
        end
     val TCl = map (map (gen_all (R1::f::SV) o subst[f |-> faux_capp])) TCl_0
     val TCs = op_U aconv TCl
     val full_rqt = WFR::TCs
     val R2 = mk_select{Bvar=R1, Body=list_mk_conj full_rqt}
     val R2abs = rand R2
     val R2inst'd = SPEC R2 inst'd
     val fvar = mk_var{Name = #Name (dest_var f),
                  Ty = itlist (curry op-->) (map type_of SV) (type_of f)}
     val fvar_app = list_mk_comb(fvar,SV)
     val (def1,theory1) = make_definition thy (defPrim bindstem)
               (mk_eq{lhs=fvar_app, rhs=list_mk_comb(faux_const,R2::SV)})
     val var_wits = LIST_CONJ (map ASSUME full_rqt)
     val TC_choice_thm = 
         MP (BETA_RULE(ISPECL[R2abs, R1] boolTheory.SELECT_AX)) var_wits
     val elim_chosenTCs = 
           rev_itlist (C ModusPonens) (CONJUNCTS TC_choice_thm) R2inst'd
     val rules = simplify [GSYM def1] elim_chosenTCs
     val pat_TCs_list = merge (map pat_of pats) (zip (givens pats) TCl)

     (* and now induction *)

     val aux_ind = Induction.mk_induction theory1
                     {fconst=faux_const, R=R1,SV=SV,pat_TCs_list=pat_TCs_list}
     val nested_guards = op_set_diff aconv (hyp rules) (hyp aux_ind)
     val ics = strip_conj(#ant(dest_imp(#Body(dest_forall(concl aux_ind)))))
     fun dest_ic tm = if is_imp tm then strip_conj (#ant(dest_imp tm)) else []
     val ihs = Lib.flatten (map (dest_ic o snd o strip_forall) ics)
     val nested_ihs = filter (can (find_term (aconv faux_const))) ihs
     (* a nested ih is of the form 

           c1/\.../\ck ==> R a pat ==> P a

        where "aux R N" occurs in "c1/\.../\ck" or "a". In the latter case,
        we have a nested recursion; in the former, there's just a call
        to aux in the context. In both cases, we want to eliminate "R a pat"
        by assuming "c1/\.../\ck ==> R a pat" and doing some work.
     *)
     fun nested_guard tm = 
         let val ngthm = SPEC_ALL (ASSUME tm)
         in if is_imp (concl ngthm) then UNDISCH ngthm else ngthm
         end
     val ng_thms = map nested_guard nested_guards
     val nested_ihs' = map (Rules.simpl_conv ng_thms) nested_ihs
     val nested_ihs''' = nested_ihs'
(*     fun disch_context thm = 
          if length(hyp thm) = 2
          then DISCH (#ant(dest_imp(lhs (concl thm)))) thm
          else thm
     val nested_ihs'' = map disch_context nested_ihs'
     val nested_ihs''' = map (simplify [imp_elim]) nested_ihs''
*)
     val ind0 = simplify nested_ihs''' aux_ind
     val ind1 = UNDISCH_ALL (SPEC R2 (GEN R1 (DISCH_ALL ind0)))
     val ind2 = simplify [GSYM def1] ind1
     val ind3 = itlist PROVE_HYP (CONJUNCTS TC_choice_thm) ind2
 in 
    {rules = rules,
     ind = ind3,
     SV = SV,
     R = R1,
     theory = theory1, aux_def = def, def = def1, 
     aux_rules = LIST_CONJ disch'dl_1,
     aux_ind = aux_ind
     }
 end;

(*---------------------------------------------------------------------------
      Performs tupling and also eta-expansion. 
 ---------------------------------------------------------------------------*)

fun tuple_args alist =
 let open Psyntax
     val find = Lib.C assoc1 alist
   fun tupelo tm =
      case dest_term tm
      of LAMB{Bvar,Body} => mk_abs(Bvar, tupelo Body)
       | _ =>
         let val (g,args) = strip_comb tm
             val args' = map tupelo args
         in case find g
            of NONE => list_mk_comb(g,args')
             | SOME (_,(stem',argtys)) =>
               if length args < length argtys  (* partial application *)
               then let val nvs = map (curry mk_var "a") (drop args argtys)
                        val nvs' = variants (free_varsl args') nvs
                        val comb' = mk_comb(stem',list_mk_pair(args' @nvs'))
                    in list_mk_abs(nvs', comb')
                    end
               else mk_comb(stem', list_mk_pair args')
         end
 in 
   tupelo
 end;


(*---------------------------------------------------------------------------
     Mutual recursion. This is reduced to an ordinary definition by
     use of sum types. The n mutually recursive functions are mapped
     to a single function "mut" having domain and range be sums of 
     the domains and ranges of the given functions. The domain sum 
     has n components. The range sum has k <= n components, built from 
     the set of range types. The arguments of the left hand side of 
     the function are uniformly injected into the domain sum. On the
     right hand side, every occurrence of a function "f a" is translated
     to "OUT(mut (IN a))", where IN is the compound injection function, 
     and OUT brings the result back to the original type of "f a". 
     Finally, each rhs is injected into the range sum. 

     After that translation, "mut" is defined. And then the individual
     functions are defined. Rewriting then brings them out.

     After that, induction is easy to recover from the induction theorem
     for mut. 
 ---------------------------------------------------------------------------*)

fun ndom_rng ty 0 = ([],ty)
  | ndom_rng ty n = 
      let val (dom,rng) = dom_rng ty
          val (L,last) = ndom_rng rng (n-1)
      in (dom::L, last)
      end;
  
fun mutrec thy bindstem eqns =
  let open Psyntax
      val dom_rng = Type.dom_rng
      val genvar = Term.genvar
      val DEPTH_CONV = Conv.DEPTH_CONV
      val BETA_CONV = Thm.BETA_CONV
      val OUTL = sumTheory.OUTL
      val OUTR = sumTheory.OUTR
      val sum_case_def = sumTheory.sum_case_def
      val CONJ = Thm.CONJ
      fun dest_atom tm = (dest_var tm handle HOL_ERR _ => dest_const tm);
      val eqnl = strip_conj eqns
      val lhs_info = mk_set(map ((I##length) o strip_comb o lhs) eqnl)
      val div_tys = map (fn (tm,i) => ndom_rng (type_of tm) i) lhs_info
      val lhs_info1 = zip (map fst lhs_info) div_tys
      val dom_tyl = map (list_mk_prod_type o fst) div_tys
      val rng_tyl = mk_set (map snd div_tys)
      val mut_dom = end_itlist mk_sum_type dom_tyl
      val mut_rng = end_itlist mk_sum_type rng_tyl
      val mut_name = unionStem bindstem
      val mut = mk_var(mut_name, mut_dom --> mut_rng)
      fun inform (f,(doml,rng)) = 
         let val s = fst(dest_atom f)
         in if 1<length doml 
             then (f, (mk_var(s^"_tupled",list_mk_prod_type doml --> rng),doml))
             else (f, (f,doml))
         end
      val eqns' = tuple_args (map inform lhs_info1) eqns
      val eqnl' = strip_conj eqns'
      val (L,R) = unzip (map dest_eq eqnl')
      val fnl' = mk_set (map (fst o strip_comb o lhs) eqnl')
      val fnvar_map = zip lhs_info1 fnl'
      val gvl = map genvar dom_tyl
      val gvr = map genvar rng_tyl
      val injmap = zip fnl' (map2 (C (curry mk_abs)) (inject mut_dom gvl) gvl)
      fun mk_lhs_mut_app (f,arg) = 
          mk_comb(mut,beta_conv (mk_comb(assoc f injmap,arg)))
      val L1 = map (mk_lhs_mut_app o dest_comb) L
      val gv_mut_rng = genvar mut_rng
      val outfns = map (curry mk_abs gv_mut_rng) (project mut_rng gv_mut_rng)
      val ty_outs = zip rng_tyl outfns
      (* now replace each f by \x. outbar(mut(inbar x)) *)
      fun fout f = (f,assoc (#2(dom_rng(type_of f))) ty_outs)
      val RNG_OUTS = map fout fnl'
      fun mk_rhs_mut f v = 
          (f |-> mk_abs(v,beta_conv (mk_comb(assoc f RNG_OUTS, 
                                             mk_lhs_mut_app (f,v)))))
      val R1 = map (Term.subst (map2 mk_rhs_mut fnl' gvl)) R
      val eqnl1 = zip L1 R1
      val rng_injmap = 
            zip rng_tyl (map2 (C (curry mk_abs)) (inject mut_rng gvr) gvr)
      fun f_rng_in f = (f,assoc (#2(dom_rng(type_of f))) rng_injmap)
      val RNG_INS = map f_rng_in fnl'
      val tmp = zip (map (#1 o dest_comb) L) R1
      val R2 = map (fn (f,r) => beta_conv(mk_comb(assoc f RNG_INS, r))) tmp
      val R3 = map (rhs o concl o DEPTH_CONV BETA_CONV) R2
      val mut_eqns = list_mk_conj(map mk_eq (zip L1 R3))
      val wfrec_res = wfrec_eqns thy mut_eqns
      val defn = 
        if exists I (#3(unzip3 (#extracta wfrec_res)))   (* nested *)
        then let val {rules,ind,aux_rules, aux_ind, theory, def,aux_def,...} 
                     = nestrec thy mut_name wfrec_res
             in {rules=rules, ind=ind, theory=theory,
                 aux=SOME{rules=aux_rules, ind=aux_ind}}
              end
        else let val {rules,R,SV,theory,full_pats_TCs,...} 
                      = stdrec thy mut_name wfrec_res
             val f = #1(dest_comb(lhs (concl(Lib.trye CONJUNCT1 rules))))
             val ind = Induction.mk_induction theory
                         {fconst=f, R=R, SV=SV, pat_TCs_list=full_pats_TCs}
             in {rules=rules, ind=ind, theory=theory, aux=NONE}
             end
      val theory1 = #theory defn
      val mut_rules = #rules defn
      val mut_constSV = #1(dest_comb(lhs(#1(dest_conj(concl mut_rules)))))
      val (mut_const,params) = strip_comb mut_constSV
      fun define_subfn (n,((fvar,(argtys,rng)),ftupvar)) thy =
         let val inbar  = assoc ftupvar injmap
             val outbar = assoc ftupvar RNG_OUTS
             val (fvarname,_) = dest_atom fvar
             val defvars = rev 
                  (Lib.with_flag (Globals.priming, SOME"") (variants [fvar])
                     (map (curry Psyntax.mk_var "x") argtys))
             val tup_defvars = list_mk_pair defvars
             val newty = itlist (curry (op-->)) (map type_of params@argtys) rng
             val fvar' = mk_var(fvarname,newty)
             val dlhs  = list_mk_comb(fvar',params@defvars)
             val Uapp  = mk_comb(mut_constSV,
                            beta_conv(mk_comb(inbar,list_mk_pair defvars)))
             val drhs  = beta_conv (mk_comb(outbar,Uapp))
             val thybind = defExtract(mut_name,n)
         in 
           (make_definition thy thybind (mk_eq(dlhs,drhs)) , (Uapp,outbar))
         end
      fun mk_def triple (defl,thy,Uout_map) =
            let val ((d,thy'),Uout) = define_subfn triple thy 
            in (d::defl, thy', Uout::Uout_map)
            end
      val (defns,theory2,Uout_map) = 
            itlist mk_def (Lib.enumerate 0 fnvar_map) ([],theory1,[])
      fun apply_outmap th =
         let fun matches (pat,_) = Lib.can (match_term pat) (lhs (concl th))
             val (_,outf) = Lib.first matches Uout_map
         in AP_TERM outf th
         end
      val mut_rules1 = LIST_CONJ (map apply_outmap (CONJUNCTS mut_rules))
      val simp = Rules.simplify (OUTL::OUTR::map GSYM defns)
      (* finally *)
      val mut_rules2 = simp mut_rules1 

      (* induction *)
      val mut_ind0 = simp (#ind defn)
      val pindices = enumerate (map fst div_tys)
      val vary = Term.variant(Term.all_varsl(concl mut_rules2::hyp mut_rules2))
      fun mkP (tyl,i) def = 
          let val V0 = snd(strip_comb(lhs(snd(strip_forall(concl def)))))
              val V = drop (#SV wfrec_res) V0
              val P = vary (mk_var("P"^Lib.int_to_string i,
                                   list_mk_fun_type (tyl@[bool])))
           in (P, mk_aabs(list_mk_pair V,list_mk_comb(P, V)))
          end
      val (Plist,preds) = unzip (map2 mkP pindices defns)
      val Psum_case = end_itlist (fn P => fn tm => 
           let val Pty = type_of P
               val Pdom = #1(dom_rng Pty)
               val tmty = type_of tm
               val tmdom = #1(dom_rng tmty)
               val sum_ty = Pty --> tmty --> mk_sum_type Pdom tmdom --> bool
           in 
              list_mk_comb(mk_const("sum_case",sum_ty),[P,tm])
           end) preds
      val mut_ind1 = Rules.simplify [sum_case_def] (SPEC Psum_case mut_ind0)
      val (ant,_) = dest_imp (concl mut_ind1)
      fun mkv (i,ty) = mk_var("v"^Lib.int_to_string i,ty)
      val V = map (map mkv)
                  (map (Lib.enumerate 0 o fst) pindices)
      val Vinj = map2 (fn f => fn vlist => 
                        beta_conv(mk_comb(#2 f, list_mk_pair vlist))) injmap V
      val und_mut_ind1 = UNDISCH mut_ind1
      val tmpl = map (fn (vlist,v) => 
                         GENL vlist (Rules.simplify [sum_case_def]
                                     (SPEC v und_mut_ind1)))   (zip V Vinj)
      val mut_ind2 = GENL Plist (DISCH ant (LIST_CONJ tmpl))
  in 
    { rules = mut_rules2,
      ind =  mut_ind2,
      SV = #SV wfrec_res, 
      R = rand (#WFR wfrec_res),
      union = defn,
      theory = theory2
    }
  end;


(*---------------------------------------------------------------------------
       The purpose of pairf is to translate a prospective definition 
       into a completely tupled format. On entry to pairf, we know that 
       f is curried, i.e., of type

              f : ty1 -> ... -> tyn -> rangety

       We build a tupled version of f 

              f_tupled : ty1 * ... * tyn -> rangety 

       and then make a definition

              f x1 ... xn = f_tupled (x1,...,xn)

       We also need to remember how to revert an induction theorem
       into the original domain type. This function is not used for
       mutual recursion, since things are more complicated there.

 ----------------------------------------------------------------------------*)

fun pairf (stem,eqs0) = 
 let val ((f,args),rhs) = dest_hd_eqn eqs0
 in if length args = 1   (* not curried ... do eta-expansion *)
    then (tuple_args[(f,(f,map type_of args))] eqs0, stem, I)
 else 
 let val stem'name = stem^"_tupled"
     val argtys    = map type_of args
     val rng_ty    = type_of rhs
     val tuple_dom   = list_mk_prod_type argtys
     val stem'     = mk_var {Name=stem'name, Ty = tuple_dom --> rng_ty}
     val defvars   = rev (Lib.with_flag (Globals.priming, SOME"")
                               (variants [f])
                               (map (curry Psyntax.mk_var "x") argtys))
     fun untuple_args (rules,induction) =
      let val eq1 = concl(CONJUNCT1 rules handle HOL_ERR _ => rules)
          val {lhs,rhs} = dest_eq(snd(strip_forall eq1))
          val (tuplec,args) = strip_comb lhs
          val (SV,p) = front_last args
          val tuplecSV = list_mk_comb(tuplec,SV)
          val def_args = SV@defvars
          val fvar = mk_var{Name = atom_name f,
                 Ty = list_mk_fun_type (map type_of def_args@[rng_ty])}
          val def  = new_definition (argMunge stem,
                      mk_eq{lhs=list_mk_comb(fvar, def_args),
                         rhs=list_mk_comb(tuplecSV, [list_mk_pair defvars])})
          val rules' = Rewrite.PURE_REWRITE_RULE[GSYM def] rules
          val induction' = 
             let val P   = #Name(dest_var(#Bvar(dest_forall(concl induction))))
                 val Qty = itlist (curry Type.-->) argtys Type.bool
                 val Q   = mk_primed_var{Name=P, Ty=Qty}
                 val tm  = mk_pabs{varstruct=list_mk_pair defvars,
                                   body=list_mk_comb(Q,defvars)}
             in
               GEN Q (CONV_RULE(DEPTH_CONV Let_conv.GEN_BETA_CONV) 
                  (SPEC tm (Rewrite.PURE_REWRITE_RULE [GSYM def] induction)))
             end
      in
         (rules', induction')
      end
 in
    (tuple_args [(f,(stem',argtys))] eqs0, stem'name, untuple_args)
 end end;


local fun is_constructor tm = not (is_var tm orelse is_pair tm)
in
fun non_wfrec_defn (facts,bind,eqns) = 
 let val ((_,args),_) = dest_hd_eqn eqns
 in if Lib.exists is_constructor args
    then case TypeBase.get facts 
                 (#Tyop(Type.dest_type(type_of(first is_constructor args))))
       of NONE => raise ERR "non_wfrec_defn" "unexpected lhs in definition"
        | SOME tyinfo =>
           let val def = Prim_rec.new_recursive_definition
                       {name=bind,def=eqns,rec_axiom=TypeBase.axiom_of tyinfo}
               val ind = TypeBase.induction_of tyinfo
           in PRIMREC{eqs=def, ind=ind, bind=bind}
           end
    else ABBREV {eqn=new_definition (bind,eqns), bind=bind}
 end
end;


fun mutrec_defn (facts,stem,eqns) =
 let val {rules, ind, SV, R, 
          union as {rules=r,ind=i,aux,...},...} = mutrec facts stem eqns
     val union' = case aux
      of NONE => STDREC{eqs=r,ind=i,R=R,SV=SV, stem=unionStem stem}
      | SOME{rules=raux,ind=iaux} => 
         NESTREC{eqs=r,ind=i,R=R,SV=SV, stem=unionStem stem,
                 aux=STDREC{eqs=raux,ind=iaux,R=R,SV=SV,stem=auxStem stem}}
 in MUTREC{eqs=rules, ind=ind, R=R, SV=SV, stem=stem, union=union'}
 end


fun nestrec_defn (fb,(stem,stem'),wfrec_res,untuple) =
  let val {rules,ind,SV,R,aux_rules,aux_ind,...} = nestrec fb stem' wfrec_res
      val (rules', ind') = untuple (rules, ind)
  in NESTREC {eqs=rules', ind=ind', R=R, SV=SV, stem=stem,
              aux=STDREC{eqs=aux_rules, ind=aux_ind, 
                         R=R, SV=SV, stem=auxStem stem'}}
  end;


fun stdrec_defn (facts,(stem,stem'),wfrec_res,untuple) =
 let val {rules,R,SV,full_pats_TCs,...} = stdrec facts stem' wfrec_res
     val ((f,_),_) = dest_hd_eqn (concl rules)
     val ind = Induction.mk_induction facts
                 {fconst=f, R=R, SV=SV, pat_TCs_list=full_pats_TCs}
 in
 case hyp rules
 of []     => raise ERR "stdrec_defn" "Empty hypotheses"
  | [WF_R] =>   (* non-recursive defn via complex patterns *)
       (let val {Rator=WF,Rand=R} = dest_comb WF_R
            val theta     = [Type.alpha |-> hd(#Args(dest_type (type_of R)))]
            val Empty_thm = INST_TYPE theta relationTheory.WF_Empty
            val (r1, i1)  = untuple(rules, ind)
            val r2        = MATCH_MP (DISCH_ALL r1) Empty_thm
            val i2        = MATCH_MP (DISCH_ALL i1) Empty_thm
        in
           NONREC {eqs=r2, ind=i2, stem=stem}
        end handle HOL_ERR _ => raise ERR "stdrec_defn" "")
  | otherwise => 
        let val (rules', ind') = untuple (rules, ind)
        in STDREC {eqs=rules',ind=ind', R=R, SV=SV, stem=stem}
        end
 end;


(*---------------------------------------------------------------------------
    A general, basic, interface to function definitions. First try to 
    use standard existing machinery to make a prim. rec. definition, or 
    an abbreviation. If those attempts fail, try to use a wellfounded
    definition (with pattern matching, wildcard expansion, etc.). Note
    that induction is derived for all wellfounded definitions, but 
    a termination proof is not attempted. For that, use the entrypoints
    in TotalDefn.
 ---------------------------------------------------------------------------*)

fun mk_defn stem eqns =
 let val _ = if Lexis.ok_identifier stem then ()
             else raise ERR "define"
                   (String.concat[Lib.quote stem," is not alphanumeric"])
     val facts = TypeBase.theTypeBase()
 in
  non_wfrec_defn (facts, defSuffix stem, eqns) 
  handle HOL_ERR _ 
  => if 1 < length(all_fns eqns)
     then mutrec_defn (facts,stem,eqns) 
     else
     let val (tup_eqs,stem',untuple) = pairf(stem,eqns)
          handle HOL_ERR _ => raise ERR "mk_defn" 
               "failure in internal translation to tupled format"
         val wfrec_res = wfrec_eqns facts tup_eqs 
     in
        if exists I (#3 (unzip3 (#extracta wfrec_res)))   (* nested *)
        then nestrec_defn (facts,(stem,stem'),wfrec_res,untuple)
        else stdrec_defn  (facts,(stem,stem'),wfrec_res,untuple)
     end 
 end;


fun mk_Rdefn stem R eqs =
  let val defn = mk_defn stem eqs
  in case reln_of defn 
      of NONE => defn
       | SOME Rvar => inst_defn defn (Term.match_term Rvar R)
  end;


(*---------------------------------------------------------------------------
     Quotation interface to definition. This includes a pass for 
     expansion of wildcards in patterns.
 ---------------------------------------------------------------------------*)

fun dollar s = "$"^s;

fun drop_dollar s =
 let open String 
     val n = size s
 in if n=0 then s else 
    if sub(s,0) = #"$" then substring(s,1,n-1) else s
 end;

fun vary s S =
 let fun V n = 
      let val s' = s^Lib.int_to_string n
      in if mem s' S then V (n+1) else (s',s'::S)
      end
 in V 0 end;

(*---------------------------------------------------------------------------
    A wildcard is a contiguous sequence of underscores. This is 
    somewhat cranky, we realize, but restricting to only one
    is not great for readability at times.
 ---------------------------------------------------------------------------*)

local fun underscore #"_" = true  | underscore   _  = false
in
fun wildcard s =
  let val ss = Substring.all s
  in if Substring.isEmpty ss then false
     else Substring.isEmpty (Substring.dropl underscore ss) 
  end
end;

local open Absyn
in
fun vnames_of (VAQ tm) S = union (map (#Name o Term.dest_var) (all_vars tm)) S
  | vnames_of (VIDENT s) S = union [s] S
  | vnames_of (VPAIR(v1,v2)) S = vnames_of v1 (vnames_of v2 S)
  | vnames_of (VTYPED(v,_)) S = vnames_of v S

fun names_of (AQ tm) S = union (map (#Name o Term.dest_var) (all_vars tm)) S
  | names_of (IDENT s) S = union [s] S
  | names_of (APP(M,N)) S = names_of M (names_of N S)
  | names_of (LAM (v,M)) S = names_of M (vnames_of v S)
  | names_of (TYPED(M,_)) S = names_of M S
end;

local val v_vary = vary "v"
      fun tm_exp tm S = 
       let open Term Psyntax
       in case dest_term tm
          of VAR{Name=s,Ty} => 
              if wildcard s
              then let val (s',S') = v_vary S in (mk_var(s',Ty),S') end
              else (tm,S)
          | CONST{Name,...}  => (tm,S)
          | COMB{Rator,Rand} => 
             let val (Rator',S')  = tm_exp Rator S
                 val (Rand', S'') = tm_exp Rand S
             in (mk_comb(Rator', Rand'), S'') 
             end
          | LAMB _ => raise ERR "tm_exp" "abstraction in pattern"
       end
       open Absyn
in
fun exp (AQ tm) S = let val (tm',S') = tm_exp tm S in (AQ tm',S') end
  | exp (IDENT s) S = 
      if wildcard s 
        then let val (s',S') = v_vary S in (IDENT s', S') end
        else (IDENT s, S)
  | exp (APP(M,N)) S = 
      let val (M',S')   = exp M S 
          val (N', S'') = exp N S'
      in (APP (M',N'), S'')
      end
  | exp(TYPED(M,pty)) S = let val (M',S') = exp M S in (TYPED(M',pty),S') end
  | exp(LAM _) _ = raise ERR "exp" "abstraction in pattern"

fun expand_wildcards asy (asyl,S) = 
   let val (asy',S') = exp asy S 
   in (asy'::asyl, S') 
   end
end;


local fun dest_pvar (Absyn.VIDENT s) = s
        | dest_pvar _ = raise ERR "munge" "dest_pvar"
in
fun munge eq (eqs,fset,V) =
 let val (vlist,body) = Absyn.strip_forall eq
     val (lhs,rhs)    = Absyn.dest_eq body
     val   _          = if exists wildcard (names_of rhs [])
                        then raise ERR "munge" "wildcards on rhs" else ()
     val (f,pats)     = Absyn.strip_app lhs
     val fstr         = Absyn.dest_ident f
     val (pats',V')   = rev_itlist expand_wildcards pats 
                            ([],Lib.union V (map dest_pvar vlist))
     val new_eq       = Absyn.list_mk_forall(vlist,
                          Absyn.mk_eq(Absyn.list_mk_app(f,rev pats'), rhs))
 in 
    (new_eq::eqs, insert fstr fset, V')
 end
end;

fun elim_wildcards eqs =
 let val names = names_of eqs []
     val (eql,fset,_) = rev_itlist munge (Absyn.strip_conj eqs) ([],[],names)
 in 
   (Absyn.list_mk_conj (rev eql), fset)
 end;

fun parse_defn q = 
 let val absyn0 = Parse.parse_preTerm q
     val (absyn,fset) = elim_wildcards absyn0
     val fn_names = map drop_dollar fset
     val allfn_names = map dollar fn_names @ fn_names
     val  _   = List.app Parse.hide allfn_names
     val tm = Parse.toTerm (Parse.term_grammar()) absyn
              handle e => (List.app Parse.reveal allfn_names; raise e)
     val _ = List.app Parse.reveal allfn_names
 in 
    (tm, fn_names)
 end;

fun Hol_defn bindstem q = mk_defn bindstem (fst(parse_defn q));

fun Hol_Rdefn bindstem Rquote eqs_quote = 
  let val defn = Hol_defn bindstem eqs_quote
  in case reln_of defn
      of NONE => defn
       | SOME Rvar =>
          let val R = Parse.typedTerm Rquote (type_of Rvar)
          in inst_defn defn (Term.match_term Rvar R) 
          end
  end;


(*---------------------------------------------------------------------------
        Goalstack-based interface to termination proof.
 ---------------------------------------------------------------------------*)

fun TC_TAC defn =
 let open Resolve Rewrite Drule Tactical
     infix THEN
     val E = eqns_of defn
     val I = Option.valOf (ind_of defn)
     val tac = MATCH_MP_TAC
                (PURE_REWRITE_RULE [boolTheory.AND_IMP_INTRO]
                   (GEN_ALL(DISCH_ALL (CONJ E I))))
               THEN PURE_REWRITE_TAC [Conv.GSYM boolTheory.CONJ_ASSOC]
     val goal = ([],Psyntax.mk_conj(concl E, concl I))
 in 
   case tac goal
    of ([([],g)],validation) => (([],g), fn th => validation [th])
     | _  => raise ERR "TC_TAC" "unexpected output"
 end;

fun tgoal0 defn =
   if null (tcs_of defn)
   then raise ERR "tgoal" "no termination conditions"
   else let val (g,validation) = TC_TAC defn
            val goalstack = GoalstackPure.prim_set_goal g validation
        in
          goalstackLib.add goalstack
        end
        handle HOL_ERR _ => raise ERR "tgoal" "";

fun tgoal defn =
  Lib.with_flag (goalstackLib.chatting,false)
       tgoal0 defn;


fun tprove0 (defn,tactic) =
   let val _ = tgoal defn
       val _ = goalstackLib.expand tactic  (* should finish proof off *)
       val th = goalstackLib.top_thm ()
       val _ = goalstackLib.drop()
   in
      (CONJUNCT1 th, CONJUNCT2 th)
   end
   handle HOL_ERR _ => raise ERR "tprove" "Termination proof failed.";

fun tprove p =
  Lib.with_flag (goalstackLib.chatting,false)
       tprove0 p;

end; (* Defn *)
