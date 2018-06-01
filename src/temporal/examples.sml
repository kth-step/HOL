(* ---------------------------------------------------------------------------- *)
(* Please set HOL4_SMV_EXECUTABLE env variable before evaluating this file,     *)
(* Tested with NuSMV 2.6.0 by Chun Tian <ctian@fbk.eu> on May 25, 2018.         *)
(* ---------------------------------------------------------------------------- *)

load "temporalLib"; open temporalLib;

(* ---------------------------------------------------------------------------- *)
(* First, we prove that SUNTIL can be expressed by unary temporal operators     *)
(* provided that we use past temporal operators. It is well-known that          *)
(* this is not possible without the past operators, i.e., with NEXT, ALWAYS,    *)
(* and EVENTUAL, we could not define the binary temporal future operators.      *)
(* ---------------------------------------------------------------------------- *)

val SUNTIL_BY_UNARY_OPERATORS = save_thm (
   "SUNTIL_BY_UNARY_OPERATORS",
    LTL_CONV ``(a SUNTIL b) 0
              = (EVENTUAL (\t. b t /\ PNEXT (PALWAYS a) t)) 0``);

val SWHEN_BY_UNARY_OPERATORS = save_thm (
   "SWHEN_BY_UNARY_OPERATORS",
    LTL_CONV ``(a SWHEN b) 0
              = (EVENTUAL (\t. a t /\ b t /\ PNEXT (PALWAYS (\t. ~b t)) t)) 0``);

val SBEFORE_BY_UNARY_OPERATORS = save_thm (
   "SBEFORE_BY_UNARY_OPERATORS",
    LTL_CONV ``(a SBEFORE b) 0
              = (EVENTUAL (\t. a t /\ ~b t /\ PNEXT (PALWAYS (\t. ~b t)) t)) 0``);

(* ---------------------------------------------------------------------------- *)
(* Manna and Pnueli consider several normal forms for temporal logic formulas.  *)
(* One such normal form are the persistence formulas that are of the form:      *)
(* EVENTUAL (ALWAYS phi) 0 where phi must not contain future temporal operators.*)
(* Not any temporal logic formula can be brought into this normal form, but the *)
(* the set of persistence formulas is closed under /\ and \/:                   *)
(* Try to prove the second of the theorems below by hand.                       *)
(* ---------------------------------------------------------------------------- *)

val EVENTUAL_ALWAYS_NF1 = save_thm (
   "EVENTUAL_ALWAYS_NF1",
    LTL_CONV ``(\t. (EVENTUAL (ALWAYS a)) t /\ (EVENTUAL (ALWAYS b)) t)
                = (EVENTUAL (ALWAYS (\t. a t /\ b t )))``);

val EVENTUAL_ALWAYS_NF2 = save_thm (
   "EVENTUAL_ALWAYS_NF2",
    LTL_CONV ``(\t. (EVENTUAL (ALWAYS a)) t \/ (EVENTUAL (ALWAYS b)) t)
           = (EVENTUAL (ALWAYS (\t. a t \/
                                    PNEXT (b PSUNTIL (\t. b t /\ ~a t)) t)))``);

(* ---------------------------------------------------------------------------- *)
(* An important feature of SMV is that it can produce a countermodel if the     *)
(* proof fails. To demonstrate this, we now look at the following examples.     *)
(* ---------------------------------------------------------------------------- *)

LTL_CONV ``(a UNTIL b) 0
                = (EVENTUAL (\t. b t /\ PNEXT (PALWAYS a) t)) 0``;

(* ---------------------------------------------------------------------------- *)
(*      This should produce the following output:                               *)
(*      SMV computes the following countermodel:                                *)
(*      ===============================================                         *)
(*      Formula is not true! Consider the countermodel:                         *)
(*      ===============================================                         *)
(*                                                                              *)
(*      ======== A loop starts here=============                                *)
(*      ================== State0==================                             *)
(*      a = 1                                                                   *)
(*      b = 0                                                                   *)
(*      ell0 = 1                                                                *)
(*      ell1 = 1                                                                *)
(*      ell2 = 1                                                                *)
(*      ell3 = 0                                                                *)
(*      ===============================================                         *)
(*      resources used:                                                         *)
(*      user time: 0 s, system time: 0.01 s                                     *)
(*      BDD nodes allocated: 267                                                *)
(*      Bytes allocated: 917504                                                 *)
(*      BDD nodes representing transition relation: 27 + 1                      *)
(*      ===============================================                         *)
(*      SMV_AUTOMATON_CONV fails now!!!                                         *)
(*      ===============================================                         *)
(*                                                                              *)
(*      uncaught exception HOL_ERR                                              *)
(*        raised at: 1/conv.sml:234.23-234.67                                   *)
(*                                                                              *)
(* ---------------------------------------------------------------------------- *)
(* The ell_i variables have been generated by the conversion. To see what their *)
(* semantics is, you have to invoke the following:                              *)
(* ---------------------------------------------------------------------------- *)

TEMP_DEFS_CONV ``(a UNTIL b) 0
                = (EVENTUAL (\t. b t /\ PNEXT (PALWAYS a) t)) 0``;

(* ---------------------------------------------------------------------------- *)
(* You should obtain the following theorem:                                     *)
(*      val it =                                                                *)
(*        |- ((a UNTIL b) 0 = EVENTUAL (\t. b t /\ PNEXT (PALWAYS a) t) 0) =    *)
(*           (?ell0 ell1 ell2 ell3.                                             *)
(*             (ell0 0 = ell3 0) /\                                             *)
(*             (ell0 = a UNTIL b) /\                                            *)
(*             (ell1 = PNEXT (PALWAYS a)) /\                                    *)
(*             (ell2 = PNEXT (\t. a t /\ ell1 t)) /\                            *)
(*             (ell3 = EVENTUAL (\t. b t /\ ell2 t))) : thm                     *)
(* ---------------------------------------------------------------------------- *)
(* This means ell0 abbreviates a UNTIL b, ell1 abbreviates PNEXT (PALWAYS a),   *)
(* and so on. Now, look again at the counterexample. It says that at the first  *)
(* point of time, a holds, but b not, and this situation is repeated forever    *)
(* (this is said by the phrase "a loop starts here"). Hence, ell0 is true all   *)
(* the time, and therefore a UNTIL b is true all the time. The same holds for   *)
(* PNEXT (PALWAYS a) and PNEXT (\t. a t /\ ell1 t), which is easily seen by the *)
(* semantics of these operators and the values of "a" and "b". However, ell3    *)
(* does never hold, which means that the right hand side of our goal is never   *)
(* true, while the left hand side is always true. Hence, we see that the        *)
(* formula is not true. The problem is that the event "b" does never hold. If   *)
(* this is excluded, the equation would hold. Check this by the following:      *)
(* ---------------------------------------------------------------------------- *)

LTL_CONV ``(EVENTUAL b) 0
                ==> ((a UNTIL b) 0
                     = (EVENTUAL (\t. b t /\ PNEXT (PALWAYS a) t)) 0)``;

(* ---------------------------------------------------------------------------- *)
(* This will be easily proved. However, this does not define UNTIL in any cases.*)
(* To do this, prove the following:                                             *)
(* ---------------------------------------------------------------------------- *)

LTL_CONV ``(a UNTIL b) 0
                = (EVENTUAL (\t. b t /\ PNEXT (PALWAYS a) t)) 0 \/ ALWAYS a 0``;

(* ---------------------------------------------------------------------------- *)
(* An important fact is also that top-level propositional operators can be      *)
(* shifted inwards, when they are applied to formulas that start with temporal  *)
(* operators. Just consider the following theorem for the SUNTIL operator.      *)
(* You may find such elimination laws for the other operators, too, if you      *)
(* recall that SUNTIL can express all the other operators. Negating the right   *)
(* and the left hand sides give also elimination laws for top-level disjunctions.*)
(* ---------------------------------------------------------------------------- *)

val SUNTIL_CONJUNCTIONS = store_thm (
   "SUNTIL_CONJUNCTIONS", ``
        ( (\t. (EVENTUAL b) t /\ (c SUNTIL d) t ) =
                (c
                 SUNTIL
                 (\t. b t /\ (c SUNTIL d) t \/
                      d t /\ (EVENTUAL b) t)
                )
        ) /\
        ( (\t. (ALWAYS a) t /\ (c SUNTIL d) t ) =
                ((\t. a t /\ c t) SUNTIL (\t. d t /\ (ALWAYS a) t) )
        ) /\
        ( (\t. (a SBEFORE b) t /\ (c SUNTIL d) t ) =
                ((\t. ~b t /\ c t)
                 SUNTIL
                 (\t. a t /\ ~b t /\ (c SUNTIL d) t \/
                      d t /\ (a SBEFORE b) t)
                )
        ) /\
        ( (\t. (a SWHEN b) t /\ (c SUNTIL d) t ) =
                ((\t. ~b t/\ c t)
                 SUNTIL
                 (\t. a t /\ b t /\ (c SUNTIL d) t \/
                      d t /\ (a SWHEN b) t)
                )
        ) /\
        ( (\t. (a UNTIL b) t /\ (c SUNTIL d) t ) =
                ((\t. a t /\ c t)
                 SUNTIL
                 (\t. b t /\ (c SUNTIL d) t \/
                      d t /\ (a UNTIL b) t)
                )
        ) /\
        ( (\t. (a BEFORE b) t /\ (c SUNTIL d) t ) =
                ((\t. ~b t /\ c t)
                 SUNTIL
                 (\t. a t /\ ~b t /\ (c SUNTIL d) t \/
                      d t /\ (a BEFORE b) t)
                )
        )  /\
        ( (\t. (a WHEN b) t /\ (c SUNTIL d) t ) =
                ((\t. ~b t/\ c t)
                 SUNTIL
                 (\t. a t /\ b t /\ (c SUNTIL d) t \/
                      d t /\ (a WHEN b) t)
                )
        )
        ``,
        REPEAT CONJ_TAC THEN CONV_TAC LTL_CONV);

(* ---------------------------------------------------------------------------- *)
(* Some operator nestings can be eliminated. Look at the following theorems:    *)
(* ---------------------------------------------------------------------------- *)

val ALWAYS_NESTINGS = store_thm (
   "ALWAYS_NESTINGS",  ``
            ( ALWAYS(ALWAYS a)   = ALWAYS a  ) /\
            ( ALWAYS(a UNTIL b)  = ALWAYS (\t. a t \/ b t)  ) /\
            ( ALWAYS(a WHEN b)   = ALWAYS (\t. a t \/ ~b t)  ) /\
            ( ALWAYS(a BEFORE b) = ALWAYS (\t. ~b t)  ) /\
            ( ALWAYS(a SUNTIL b) = \t. ALWAYS (EVENTUAL b) t /\ ALWAYS (\t. a t \/ b t) t ) /\
            ( ALWAYS(a SWHEN b)  = \t. ALWAYS (EVENTUAL b) t /\ ALWAYS (\t. a t \/ ~b t) t ) /\
            ( ALWAYS(a SBEFORE b)= \t. ALWAYS (EVENTUAL a) t /\ ALWAYS (\t. ~b t) t )
        ``,
        REPEAT CONJ_TAC THEN CONV_TAC LTL_CONV);

val EVENTUAL_NESTINGS = store_thm (
   "EVENTUAL_NESTINGS", ``
            ( EVENTUAL(EVENTUAL a)  = EVENTUAL a ) /\
            ( EVENTUAL(a UNTIL b)   = \t. ALWAYS (EVENTUAL (\t.~a t)) t ==> EVENTUAL b t ) /\
            ( EVENTUAL(a WHEN b)    = \t. ALWAYS (EVENTUAL b) t ==> EVENTUAL(\t. a t /\ b t) t ) /\
            ( EVENTUAL(a BEFORE b)  = \t. ALWAYS (EVENTUAL b) t ==> EVENTUAL(\t. a t /\ ~b t) t ) /\
            ( EVENTUAL(a SUNTIL b)  = EVENTUAL b ) /\
            ( EVENTUAL(a SWHEN b)   = EVENTUAL (\t. a t /\ b t) ) /\
            ( EVENTUAL(a SBEFORE b) = EVENTUAL (\t. a t /\ ~b t) )
        ``,
        REPEAT CONJ_TAC THEN CONV_TAC LTL_CONV);

val UNTIL_NESTINGS = store_thm (
   "UNTIL_NESTINGS", ``
                ( ((NEXT a) UNTIL b)   = \t. b t \/((a WHEN b) t) /\ (NEXT(a UNTIL b)) t) /\
                ( ((ALWAYS a) UNTIL b) = \t.b t \/ (ALWAYS a) t ) /\
                ( ((a UNTIL b) UNTIL c)
                        = \t. ~(c t) ==> ((\t. a t \/ b t) UNTIL c) t /\
                                         ( ((\t. a t ==> b t) WHEN NEXT c) t \/
                                           ((b WHEN (\t. a t ==> b t)) WHEN c) t) ) /\
                ( ((a WHEN b) UNTIL c)
                        = \t.~c t ==> ((\t. b t ==> a t) UNTIL c) t /\
                                      ((b WHEN (NEXT c)) t \/ ((a WHEN b) WHEN c) t) )
                ``,
        REPEAT CONJ_TAC THEN CONV_TAC LTL_CONV);

(* ---------------------------------------------------------------------------- *)
(* Temporal operators are monotonic:                                            *)
(* ---------------------------------------------------------------------------- *)

val MONOTONICITY = store_thm (
   "MONOTONICITY", ``
                 ALWAYS (\t. a t ==> b t) 0 ==>
                         (\t. ALWAYS a t      ==> ALWAYS b t      ) 0 /\
                         (\t. EVENTUAL a t    ==> EVENTUAL b t    ) 0 /\
                         (\t. (a UNTIL c) t   ==> (b UNTIL c) t   ) 0 /\
                         (\t. (a WHEN c) t    ==> (b WHEN c) t    ) 0 /\
                         (\t. (a BEFORE c) t  ==> (b BEFORE c) t  ) 0 /\
                         (\t. (a SUNTIL c) t  ==> (b SUNTIL c) t  ) 0 /\
                         (\t. (a SWHEN c) t   ==> (b SWHEN c) t   ) 0 /\
                         (\t. (a SBEFORE c) t ==> (b SBEFORE c) t ) 0 /\
                         (\t. (c UNTIL a) t   ==> (c UNTIL b) t   ) 0 /\
                         (\t. (c BEFORE b) t  ==> (c BEFORE a) t  ) 0 /\
                         (\t. (c SUNTIL a) t  ==> (c SUNTIL b) t  ) 0 /\
                         (\t. (c SBEFORE b) t ==> (c SBEFORE a) t ) 0
                ``,
        REPEAT STRIP_TAC THEN UNDISCH_TAC ``ALWAYS (\t. a t ==> b t) 0``
        THEN CONV_TAC LTL_CONV);

(* ---------------------------------------------------------------------------- *)
(* The theory "Past_Temporal_Logic" contains separation theorems that show that *)
(* we can separate in any temporal logic formula the past and future temporal   *)
(* operators. We now prove special variants of these separation theorems by our *)
(* SMV based conversion.                                                        *)
(* ---------------------------------------------------------------------------- *)

val SEPARATE_ALWAYS_THM = store_thm (
   "SEPARATE_ALWAYS_THM", ``
                (ALWAYS (\t. a t \/ PNEXT b t)
                 =  \t. (a t \/ PNEXT b t) /\ ALWAYS (\t. NEXT a t \/ b t) t
                ) /\
                (ALWAYS (\t. a t \/ PSNEXT b t)
                 = \t. (a t \/ PSNEXT b t) /\ ALWAYS (\t. NEXT a t \/ b t) t
                ) /\
                (ALWAYS (\t. a t \/ (b PSUNTIL c) t)
                 = \t.
                     (  (b PSUNTIL c) t \/ ((NEXT c) BEFORE (\t. ~a t)) t  )
                     /\ ALWAYS (\t. b t \/ c t \/ ((NEXT c) BEFORE (\t. ~a t)) t) t
                ) /\
                (ALWAYS (\t. a t \/ (b PBEFORE c) t)
                 = \t.
                     (  (b PBEFORE c) t \/ ((NEXT b) BEFORE (\t. ~a t)) t  )
                      /\ ALWAYS (\t. c t ==> ((NEXT b) BEFORE (\t. ~a t)) t) t
                )
                ``,
        REPEAT STRIP_TAC THEN CONV_TAC LTL_CONV);

val SEPARATE_EVENTUAL_THM = store_thm (
   "SEPARATE_EVENTUAL_THM", ``
                (EVENTUAL (\t. a t /\ PNEXT b t)
                 = \t. (a t /\ PNEXT b t) \/ EVENTUAL (\t. NEXT a t /\ b t) t
                ) /\
                (EVENTUAL (\t. a t /\ PSNEXT b t)
                 = \t. (a t /\ PSNEXT b t) \/ EVENTUAL (\t. NEXT a t /\ b t) t
                ) /\
                (EVENTUAL (\t. a t /\ (b PSUNTIL c) t)
                 = \t. (b PSUNTIL c) t /\ ((NEXT b) SUNTIL a) t
                       \/ EVENTUAL (\t. c t /\ ((NEXT b) SUNTIL a) t) t
                ) /\
                (EVENTUAL (\t. a t /\ (b PBEFORE c) t)
                 = \t. (b PBEFORE c) t /\ ((NEXT(\t. ~c t)) SUNTIL a) t
                       \/ EVENTUAL (\t. b t /\ ~c t /\ ((NEXT(\t. ~c t)) SUNTIL a) t) t
                )
                ``,
        REPEAT STRIP_TAC THEN CONV_TAC LTL_CONV);

val SEPARATE_EVENTUAL_ALWAYS_THM = store_thm (
   "SEPARATE_EVENTUAL_ALWAYS_THM", ``
                (EVENTUAL(ALWAYS (\t. a t \/ PNEXT b t))
                 =  EVENTUAL(ALWAYS (\t. NEXT a t \/ b t))
                ) /\
                (EVENTUAL(ALWAYS (\t. a t \/ PSNEXT b t))
                 =  EVENTUAL(ALWAYS (\t. NEXT a t \/ b t))
                ) /\
                (EVENTUAL(ALWAYS (\t. a t \/ (b PSUNTIL c) t)) 0
                =
                if ALWAYS (\t.~c t) 0
                  then EVENTUAL(ALWAYS a) 0
                  else if ALWAYS (EVENTUAL c) 0
                         then EVENTUAL(ALWAYS
                                (\t. b t \/ c t \/ ((NEXT c) BEFORE (\t. ~a t)) t)) 0
                         else if EVENTUAL(ALWAYS a) 0
                                then EVENTUAL(ALWAYS a) 0
                                else EVENTUAL(\t. c t /\ ALWAYS (NEXT b) t) 0

                )
                ``,
        REPEAT STRIP_TAC THEN CONV_TAC LTL_CONV);

(*--------------------------------------------------------------------------*)
