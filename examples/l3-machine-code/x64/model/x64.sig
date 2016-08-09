(* x64 - generated by L3 - Fri Aug 05 09:06:17 2016 *)

signature x64 =
sig

structure Map: MutableMap

(* -------------------------------------------------------------------------
   Types
   ------------------------------------------------------------------------- *)

datatype Zreg
  = RAX | RCX | RDX | RBX | RSP | RBP | RSI | RDI | zR8 | zR9 | zR10
  | zR11 | zR12 | zR13 | zR14 | zR15

datatype Zeflags = Z_CF | Z_PF | Z_AF | Z_ZF | Z_SF | Z_OF

datatype Zsize = Z16 | Z32 | Z64 | Z8 of bool

datatype Zbase = ZnoBase | ZregBase of Zreg | ZripBase

datatype Zrm
  = Zm of ((BitsN.nbit * Zreg) option) * (Zbase * BitsN.nbit) | Zr of Zreg

datatype Zdest_src
  = Zr_rm of Zreg * Zrm | Zrm_i of Zrm * BitsN.nbit | Zrm_r of Zrm * Zreg

datatype Zimm_rm = Zimm of BitsN.nbit | Zrm of Zrm

datatype Zmonop_name = Zdec | Zinc | Znot | Zneg

datatype Zbinop_name
  = Zadd | Zor | Zadc | Zsbb | Zand | Zsub | Zxor | Zcmp | Zrol | Zror
  | Zrcl | Zrcr | Zshl | Zshr | Ztest | Zsar

datatype Zcond
  = Z_O | Z_NO | Z_B | Z_NB | Z_E | Z_NE | Z_NA | Z_A | Z_S | Z_NS | Z_P
  | Z_NP | Z_L | Z_NL | Z_NG | Z_G | Z_ALWAYS

datatype Zea
  = Zea_i of Zsize * BitsN.nbit
  | Zea_m of Zsize * BitsN.nbit
  | Zea_r of Zsize * Zreg

datatype instruction
  = Zbinop of Zbinop_name * (Zsize * Zdest_src)
  | Zcall of Zimm_rm
  | Zclc
  | Zcmc
  | Zcmpxchg of Zsize * (Zrm * Zreg)
  | Zdiv of Zsize * Zrm
  | Zjcc of Zcond * BitsN.nbit
  | Zjmp of Zrm
  | Zlea of Zsize * Zdest_src
  | Zleave
  | Zloop of Zcond * BitsN.nbit
  | Zmonop of Zmonop_name * (Zsize * Zrm)
  | Zmov of Zcond * (Zsize * Zdest_src)
  | Zmovsx of Zsize * (Zdest_src * Zsize)
  | Zmovzx of Zsize * (Zdest_src * Zsize)
  | Zmul of Zsize * Zrm
  | Znop
  | Zpop of Zrm
  | Zpush of Zimm_rm
  | Zret of BitsN.nbit
  | Zstc
  | Zxadd of Zsize * (Zrm * Zreg)
  | Zxchg of Zsize * (Zrm * Zreg)

datatype Zinst
  = Zdec_fail of string
  | Zfull_inst of
      (BitsN.nbit list) * (instruction * ((BitsN.nbit list) option))

type REX = { B: bool, R: bool, W: bool, X: bool }

datatype maybe_instruction
  = FAIL of string
  | OK of instruction
  | PENDING of string * instruction
  | STREAM of BitsN.nbit list

(* -------------------------------------------------------------------------
   Exceptions
   ------------------------------------------------------------------------- *)

exception BadFlagAccess of string

exception BadMemAccess of BitsN.nbit

exception FAILURE of string

(* -------------------------------------------------------------------------
   Functions
   ------------------------------------------------------------------------- *)

structure Cast:
sig

val natToZreg:Nat.nat -> Zreg
val ZregToNat:Zreg-> Nat.nat
val stringToZreg:string -> Zreg
val ZregToString:Zreg-> string
val natToZeflags:Nat.nat -> Zeflags
val ZeflagsToNat:Zeflags-> Nat.nat
val stringToZeflags:string -> Zeflags
val ZeflagsToString:Zeflags-> string
val natToZmonop_name:Nat.nat -> Zmonop_name
val Zmonop_nameToNat:Zmonop_name-> Nat.nat
val stringToZmonop_name:string -> Zmonop_name
val Zmonop_nameToString:Zmonop_name-> string
val natToZbinop_name:Nat.nat -> Zbinop_name
val Zbinop_nameToNat:Zbinop_name-> Nat.nat
val stringToZbinop_name:string -> Zbinop_name
val Zbinop_nameToString:Zbinop_name-> string
val natToZcond:Nat.nat -> Zcond
val ZcondToNat:Zcond-> Nat.nat
val stringToZcond:string -> Zcond
val ZcondToString:Zcond-> string

end

val EFLAGS: ((bool option) Map.map) ref
val MEM: (BitsN.nbit Map.map) ref
val REG: (BitsN.nbit Map.map) ref
val RIP: BitsN.nbit ref
val REX_B_rupd: REX * bool -> REX
val REX_R_rupd: REX * bool -> REX
val REX_W_rupd: REX * bool -> REX
val REX_X_rupd: REX * bool -> REX
val boolify'8:
  BitsN.nbit ->
  bool * (bool * (bool * (bool * (bool * (bool * (bool * bool))))))
val mem8: BitsN.nbit -> BitsN.nbit
val write'mem8: (BitsN.nbit * BitsN.nbit) -> unit
val mem16: BitsN.nbit -> BitsN.nbit
val write'mem16: (BitsN.nbit * BitsN.nbit) -> unit
val mem32: BitsN.nbit -> BitsN.nbit
val write'mem32: (BitsN.nbit * BitsN.nbit) -> unit
val mem64: BitsN.nbit -> BitsN.nbit
val write'mem64: (BitsN.nbit * BitsN.nbit) -> unit
val Eflag: Zeflags -> bool
val write'Eflag: (bool * Zeflags) -> unit
val FlagUnspecified: Zeflags -> unit
val CF: unit -> bool
val write'CF: bool -> unit
val PF: unit -> bool
val write'PF: bool -> unit
val AF: unit -> bool
val write'AF: bool -> unit
val ZF: unit -> bool
val write'ZF: bool -> unit
val SF: unit -> bool
val write'SF: bool -> unit
val OF: unit -> bool
val write'OF: bool -> unit
val ea_index: ((BitsN.nbit * Zreg) option) -> BitsN.nbit
val ea_base: Zbase -> BitsN.nbit
val ea_Zrm: (Zsize * Zrm) -> Zea
val ea_Zdest: (Zsize * Zdest_src) -> Zea
val ea_Zsrc: (Zsize * Zdest_src) -> Zea
val ea_Zimm_rm: (Zsize * Zimm_rm) -> Zea
val restrictSize: (Zsize * BitsN.nbit) -> BitsN.nbit
val EA: Zea -> BitsN.nbit
val write'EA: (BitsN.nbit * Zea) -> unit
val read_dest_src_ea:
  (Zsize * Zdest_src) -> (Zea * (BitsN.nbit * BitsN.nbit))
val call_dest_from_ea: Zea -> BitsN.nbit
val get_ea_address: Zea -> BitsN.nbit
val jump_to_ea: Zea -> unit
val ByteParity: BitsN.nbit -> bool
val Zsize_width: Zsize -> Nat.nat
val word_size_msb: (Zsize * BitsN.nbit) -> bool
val write_PF: BitsN.nbit -> unit
val write_SF: (Zsize * BitsN.nbit) -> unit
val write_ZF: (Zsize * BitsN.nbit) -> unit
val write_logical_eflags: (Zsize * BitsN.nbit) -> unit
val write_arith_eflags_except_CF_OF: (Zsize * BitsN.nbit) -> unit
val write_arith_eflags: (Zsize * (BitsN.nbit * (bool * bool))) -> unit
val erase_eflags: unit -> unit
val value_width: Zsize -> Nat.nat
val word_signed_overflow_add: (Zsize * (BitsN.nbit * BitsN.nbit)) -> bool
val word_signed_overflow_sub: (Zsize * (BitsN.nbit * BitsN.nbit)) -> bool
val add_with_carry_out:
  (Zsize * (BitsN.nbit * BitsN.nbit)) -> (BitsN.nbit * (bool * bool))
val sub_with_borrow:
  (Zsize * (BitsN.nbit * BitsN.nbit)) -> (BitsN.nbit * (bool * bool))
val write_arith_result:
  (Zsize * ((BitsN.nbit * (bool * bool)) * Zea)) -> unit
val write_arith_result_no_CF_OF: (Zsize * (BitsN.nbit * Zea)) -> unit
val write_logical_result: (Zsize * (BitsN.nbit * Zea)) -> unit
val write_result_erase_eflags: (BitsN.nbit * Zea) -> unit
val SignExtension: (BitsN.nbit * (Zsize * Zsize)) -> BitsN.nbit
val maskShift: (Zsize * BitsN.nbit) -> Nat.nat
val ROL: (Zsize * (BitsN.nbit * BitsN.nbit)) -> BitsN.nbit
val ROR: (Zsize * (BitsN.nbit * BitsN.nbit)) -> BitsN.nbit
val SAR: (Zsize * (BitsN.nbit * BitsN.nbit)) -> BitsN.nbit
val write_binop:
  (Zsize * (Zbinop_name * (BitsN.nbit * (BitsN.nbit * Zea)))) -> unit
val write_monop: (Zsize * (Zmonop_name * (BitsN.nbit * Zea))) -> unit
val read_cond: Zcond -> bool
val x64_pop_aux: unit -> BitsN.nbit
val x64_pop: Zrm -> unit
val x64_pop_rip: unit -> unit
val x64_push_aux: BitsN.nbit -> unit
val x64_push: Zimm_rm -> unit
val x64_push_rip: unit -> unit
val x64_drop: BitsN.nbit -> unit
val dfn'Zbinop: (Zbinop_name * (Zsize * Zdest_src)) -> unit
val dfn'Zcall: Zimm_rm -> unit
val dfn'Zcmpxchg: (Zsize * (Zrm * Zreg)) -> unit
val dfn'Zdiv: (Zsize * Zrm) -> unit
val dfn'Zjcc: (Zcond * BitsN.nbit) -> unit
val dfn'Zjmp: Zrm -> unit
val dfn'Zlea: (Zsize * Zdest_src) -> unit
val dfn'Zleave: unit -> unit
val dfn'Zloop: (Zcond * BitsN.nbit) -> unit
val dfn'Zmonop: (Zmonop_name * (Zsize * Zrm)) -> unit
val dfn'Zmov: (Zcond * (Zsize * Zdest_src)) -> unit
val dfn'Zmovsx: (Zsize * (Zdest_src * Zsize)) -> unit
val dfn'Zmovzx: (Zsize * (Zdest_src * Zsize)) -> unit
val dfn'Zmul: (Zsize * Zrm) -> unit
val dfn'Znop: unit
val dfn'Zpop: Zrm -> unit
val dfn'Zpush: Zimm_rm -> unit
val dfn'Zret: BitsN.nbit -> unit
val dfn'Zxadd: (Zsize * (Zrm * Zreg)) -> unit
val dfn'Zxchg: (Zsize * (Zrm * Zreg)) -> unit
val dfn'Zcmc: unit -> unit
val dfn'Zclc: unit -> unit
val dfn'Zstc: unit -> unit
val Run: instruction -> unit
val oimmediate8:
  ((BitsN.nbit list) option) -> (BitsN.nbit * ((BitsN.nbit list) option))
val immediate8:
  (BitsN.nbit list) -> (BitsN.nbit * ((BitsN.nbit list) option))
val immediate16:
  (BitsN.nbit list) -> (BitsN.nbit * ((BitsN.nbit list) option))
val immediate32:
  (BitsN.nbit list) -> (BitsN.nbit * ((BitsN.nbit list) option))
val immediate64:
  (BitsN.nbit list) -> (BitsN.nbit * ((BitsN.nbit list) option))
val immediate:
  (Zsize * (BitsN.nbit list)) -> (BitsN.nbit * ((BitsN.nbit list) option))
val oimmediate:
  (Zsize * ((BitsN.nbit list) option)) ->
  (BitsN.nbit * ((BitsN.nbit list) option))
val full_immediate:
  (Zsize * (BitsN.nbit list)) -> (BitsN.nbit * ((BitsN.nbit list) option))
val rec'REX: BitsN.nbit -> REX
val reg'REX: REX -> BitsN.nbit
val write'rec'REX: (BitsN.nbit * REX) -> BitsN.nbit
val write'reg'REX: (REX * BitsN.nbit) -> REX
val RexReg: (bool * BitsN.nbit) -> Zreg
val readDisplacement:
  (BitsN.nbit * (BitsN.nbit list)) ->
  (BitsN.nbit * ((BitsN.nbit list) option))
val readSibDisplacement:
  (bool * (BitsN.nbit * (BitsN.nbit list))) ->
  (BitsN.nbit * ((BitsN.nbit list) option))
val readSIB:
  (REX * (BitsN.nbit * (BitsN.nbit list))) ->
  (Zrm * ((BitsN.nbit list) option))
val readModRM:
  (REX * (BitsN.nbit list)) -> (Zreg * (Zrm * ((BitsN.nbit list) option)))
val readOpcodeModRM:
  (REX * (BitsN.nbit list)) ->
  (BitsN.nbit * (Zrm * ((BitsN.nbit list) option)))
val prefixGroup: BitsN.nbit -> Nat.nat
val readPrefix:
  ((Nat.nat list) * ((BitsN.nbit list) * (BitsN.nbit list))) ->
  (((BitsN.nbit list) * (bool * (REX * (BitsN.nbit list)))) option)
val readPrefixes:
  (BitsN.nbit list) ->
  (((BitsN.nbit list) * (bool * (REX * (BitsN.nbit list)))) option)
val OpSize: (bool * (bool * (BitsN.nbit * bool))) -> Zsize
val isZm: Zrm -> bool
val x64_decode: (BitsN.nbit list) -> Zinst
val x64_fetch: unit -> (BitsN.nbit list)
val x64_next: unit -> unit
val e_imm8: BitsN.nbit -> (BitsN.nbit list)
val e_imm16: BitsN.nbit -> (BitsN.nbit list)
val e_imm32: BitsN.nbit -> (BitsN.nbit list)
val e_imm64: BitsN.nbit -> (BitsN.nbit list)
val e_imm: BitsN.nbit -> (BitsN.nbit list)
val e_imm_8_32: BitsN.nbit -> (Nat.nat * (BitsN.nbit list))
val e_ModRM:
  (BitsN.nbit * Zrm) -> ((BitsN.nbit * (BitsN.nbit list)) option)
val rex_prefix: BitsN.nbit -> (BitsN.nbit list)
val e_opsize: (Zsize * BitsN.nbit) -> ((BitsN.nbit list) * BitsN.nbit)
val e_opsize_imm:
  (Zsize * (BitsN.nbit * (BitsN.nbit * bool))) ->
  (((BitsN.nbit list) * (BitsN.nbit * (BitsN.nbit list))) option)
val e_opc: (BitsN.nbit * (BitsN.nbit * Zrm)) -> (BitsN.nbit list)
val e_gen_rm_reg:
  (Zsize *
   (Zrm *
    (BitsN.nbit * ((BitsN.nbit list) * (BitsN.nbit * (BitsN.nbit option)))))) ->
  (BitsN.nbit list)
val e_rm_reg:
  (Zsize * (Zrm * (BitsN.nbit * ((BitsN.nbit list) * BitsN.nbit)))) ->
  (BitsN.nbit list)
val e_rm_imm:
  (Zsize * (Zrm * (BitsN.nbit * (BitsN.nbit * BitsN.nbit)))) ->
  (BitsN.nbit list)
val e_rm_imm8:
  (Zsize * (Zrm * (BitsN.nbit * (BitsN.nbit * BitsN.nbit)))) ->
  (BitsN.nbit list)
val e_rax_imm: (Zsize * (BitsN.nbit * BitsN.nbit)) -> (BitsN.nbit list)
val e_jcc_rel32: instruction -> (BitsN.nbit list)
val not_byte: Zsize -> bool
val is_rax: Zrm -> bool
val encode: instruction -> (BitsN.nbit list)
val stripLeftSpaces: string -> string
val stripSpaces: string -> string
val p_number: string -> (Nat.nat option)
val p_bin_or_hex_number: string -> (Nat.nat option)
val p_signed_number: string -> (IntInf.int option)
val p_imm8: string -> (BitsN.nbit option)
val p_imm16: string -> (BitsN.nbit option)
val p_imm32: string -> (BitsN.nbit option)
val p_imm64: string -> (BitsN.nbit option)
val p_imm_of_size: (Zsize * string) -> (BitsN.nbit option)
val readBytes:
  ((BitsN.nbit list) * (string list)) -> ((BitsN.nbit list) option)
val p_bytes: string -> ((BitsN.nbit list) option)
val p_label: string -> (string option)
val p_register: string -> ((Zsize * Zreg) option)
val p_scale: string -> (BitsN.nbit option)
val p_scale_index: string -> ((BitsN.nbit * Zreg) option)
val p_disp: (bool * string) -> ((bool * BitsN.nbit) option)
val p_rip_disp: string -> ((bool * BitsN.nbit) option)
val p_parts:
  ((((BitsN.nbit * Zreg) option) * ((Zreg option) * (BitsN.nbit option))) *
   string) ->
  (((BitsN.nbit * Zreg) option) * ((Zreg option) * (BitsN.nbit option)))
val p_mem:
  string -> ((((BitsN.nbit * Zreg) option) * (Zbase * BitsN.nbit)) option)
val p_rm: string -> ((Zsize * Zrm) option)
val checkSizeDelim: (Zsize * string) -> (Zsize option)
val p_sz: string -> ((Zsize option) * string)
val s_sz: Zsize -> string
val p_sz_rm: string -> (string * (Zsize * Zrm))
val p_rm_of_size: (Zsize * string) -> (string * Zrm)
val p_rm32: string -> (string * Zrm)
val p_rm64: string -> (string * Zrm)
val p_imm_rm: string -> (string * Zimm_rm)
val p_dest_src:
  (bool * (string * string)) -> (string * ((Zsize * Zdest_src) option))
val p_cond: string -> (Zcond option)
val p_binop: (Zbinop_name * (string * string)) -> maybe_instruction
val p_monop: (Nat.nat * string) -> maybe_instruction
val p_xop: (Nat.nat * (string * string)) -> maybe_instruction
val p_tokens: string -> (string list)
val instructionFromString: string -> maybe_instruction
val s_register: (Zsize * Zreg) -> string
val s_qword: BitsN.nbit -> string
val s_qword0: BitsN.nbit -> string
val s_sib: (BitsN.nbit * Zreg) -> string
val s_rm: (Zsize * Zrm) -> string
val s_imm_rm: Zimm_rm -> string
val s_sz_rm: (Zsize * Zrm) -> string
val s_dest_src: (Zsize * Zdest_src) -> string
val s_cond: Zcond -> string
val s_binop: Zbinop_name -> string
val instructionToString: (instruction * Nat.nat) -> (string * string)
val s_byte: BitsN.nbit -> string
val writeBytesAux: (string * (BitsN.nbit list)) -> string
val writeBytes: (BitsN.nbit list) -> string
val joinString: (string * string) -> string

end