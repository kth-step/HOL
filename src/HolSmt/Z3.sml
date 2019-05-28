(* Copyright (c) 2009-2012 Tjark Weber. All rights reserved. *)

(* Functions to invoke the Z3 SMT solver *)

structure Z3 = struct

  (* returns SAT if Z3 reported "sat", UNSAT if Z3 reported "unsat" *)
  fun is_sat_stream instream =
    case Option.map (String.tokens Char.isSpace) (TextIO.inputLine instream) of
      NONE => SolverSpec.UNKNOWN NONE
    | SOME ["sat"] => SolverSpec.SAT NONE
    | SOME ["unsat"] => SolverSpec.UNSAT NONE
    | _ => is_sat_stream instream

  fun is_sat_file path =
    let
      val instream = TextIO.openIn path
    in
      is_sat_stream instream
        before TextIO.closeIn instream
    end

  fun is_configured () =
    Option.isSome (OS.Process.getEnv "HOL4_Z3_EXECUTABLE")

  fun mk_Z3_fun name pre cmd_stem post goal =
    case OS.Process.getEnv "HOL4_Z3_EXECUTABLE" of
      SOME file =>
        SolverSpec.make_solver pre (file ^ cmd_stem) post goal
    | NONE =>
        raise Feedback.mk_HOL_ERR "Z3" name
          "Z3 not configured: set the HOL4_Z3_EXECUTABLE environment variable to point to the Z3 executable file."

  (* Z3 (Linux/Unix), SMT-LIB file format, no proofs *)
  val Z3_SMT_Oracle =
    mk_Z3_fun "Z3_SMT_Oracle"
      (fn goal =>
        let
          val (goal, _) = SolverSpec.simplify (SmtLib.SIMP_TAC false) goal
          val (_, strings) = SmtLib.goal_to_SmtLib goal
        in
          ((), strings)
        end)
      " -smt2 -file:"
      (Lib.K is_sat_file)

  (* e.g. "Z3 version 4.5.0 - 64 bit" *)
  fun parse_Z3_version fname =
    let
      val instrm = TextIO.openIn fname
      val s = TextIO.inputAll instrm before TextIO.closeIn instrm
      val tokens = String.tokens Char.isSpace s
      (* Print Z3 version *)
      val not_nl = (fn c => c <> #"\n")
      val no_nl = String.implode (List.filter not_nl (String.explode s))
      val _ = Feedback.HOL_MESG ("HolSmtLib: Using " ^ no_nl ^ ".")
    in
      List.nth (tokens, 2)
    end

  val Z3version =
      case OS.Process.getEnv "HOL4_Z3_EXECUTABLE" of
          NONE => "0"
        | SOME p =>
          let
            val outfile = OS.FileSys.tmpName()
            val _ = OS.Process.system (p ^ " -version > " ^ outfile)
          in
            parse_Z3_version outfile
          end

  val is_Z3_v2 = String.sub(Z3version, 0) = #"2"

  (* Z3 (Linux/Unix), SMT-LIB file format, with proofs *)
  val Z3_SMT_Prover =
    mk_Z3_fun "Z3_SMT_Prover"
      (fn goal =>
        let
          val (goal, validation) = SolverSpec.simplify (SmtLib.SIMP_TAC true) goal
          val (ty_tm_dict, strings) = SmtLib.goal_to_SmtLib_with_get_proof goal
        in
          (((goal, validation), ty_tm_dict), strings)
        end)
      ((if is_Z3_v2 then " PROOF_MODE=2" else " proof=true") ^ " -smt2 -file:")
      (fn ((goal, validation), (ty_dict, tm_dict)) =>
        fn outfile =>
          let
            val instream = TextIO.openIn outfile
            val result = is_sat_stream instream
          in
            case result of
              SolverSpec.UNSAT NONE =>
              let
                (* invert 'ty_dict' and 'tm_dict', create parsing functions *)
                val ty_dict = Redblackmap.foldl (fn (ty, s, dict) =>
                  (* types don't take arguments *)
                  Redblackmap.insert (dict, s, [SmtLib_Theories.K_zero_zero ty]))
                  (Redblackmap.mkDict String.compare) ty_dict
                val tm_dict = Redblackmap.foldl (fn ((tm, n), s, dict) =>
                  Redblackmap.insert (dict, s, [Lib.K (SmtLib_Theories.zero_args
                    (fn args =>
                      if List.length args = n then
                        Term.list_mk_comb (tm, args)
                      else
                        raise Feedback.mk_HOL_ERR "Z3" ("<" ^ s ^ ">")
                          "wrong number of arguments"))]))
                  (Redblackmap.mkDict String.compare) tm_dict
                (* add relevant SMT-LIB types/terms to dictionaries *)
                val ty_dict = Library.union_dict (Library.union_dict
                  SmtLib_Logics.AUFNIRA.tydict SmtLib_Logics.QF_ABV.tydict)
                  ty_dict
                val tm_dict = Library.union_dict (Library.union_dict
                  SmtLib_Logics.AUFNIRA.tmdict SmtLib_Logics.QF_ABV.tmdict)
                  tm_dict
                (* parse the proof and check it in HOL *)
                val proof = Z3_ProofParser.parse_stream (ty_dict, tm_dict)
                  instream
                  handle err => raise Feedback.mk_HOL_ERR "Z3" "Z3_SMT_Prover"
                    ("failed to parse Z3 proof: [" ^ (exnName err) ^ "] " ^ (exnMessage err))
                val _ = TextIO.closeIn instream
                val thm = Z3_ProofReplay.check_proof proof
                val (As, g) = goal
                val thm = Thm.CCONTR g thm
                val thm = validation [thm]
              in
                SolverSpec.UNSAT (SOME thm)
              end
            | _ => (result before TextIO.closeIn instream)
          end)

end
