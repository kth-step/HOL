open HolKernel Parse boolLib bossLib;

val _ = new_theory "smtArray";

val select_def = Q.new_definition("select_def", `select = \arr i. i :> arr`);
val store_def = Q.new_definition("store_def", `store = \arr i v. (i =+ v) arr`);

val apply_to_select_REWR = store_thm ("apply_to_select_REWR",
  ``!array index. (index :> array) = (select array index)``,
  SIMP_TAC std_ss [select_def]
);

val update_to_store_REWR = store_thm ("update_to_store_REWR",
  ``!array index value. ((index =+ value) array) = (store array index value)``,
  SIMP_TAC std_ss [store_def]
);

val _ = export_theory();

