signature Storage =
sig

  include Abbrev


  (* term *)  
  val export_terml : string -> term list -> unit
  val import_terml : string -> term list

  (* tactic data *)
  type lbl = (string * real * goal * goal list)
  type fea = int list
  type tacdata =
    {
    tacfea : (lbl,fea) Redblackmap.dict,
    tacfea_cthy : (lbl,fea) Redblackmap.dict,
    taccov : (string, int) Redblackmap.dict,
    tacdep : (goal, lbl list) Redblackmap.dict
    }
 
  val export_tacfea : string -> (lbl,fea) Redblackmap.dict -> unit
  val import_tacfea : string -> (lbl,fea) Redblackmap.dict 
  val import_tacdata : string list -> tacdata

end