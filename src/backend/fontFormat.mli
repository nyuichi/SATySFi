
type file_path = string

type glyph_id

val gid : glyph_id -> int  (* for debug *)

val hex_of_glyph_id : glyph_id -> string

type decoder

exception FailToLoadFontFormatOwingToSize   of file_path
exception FailToLoadFontFormatOwingToSystem of string
exception FontFormatBroken                  of Otfm.error
exception NoGlyphID                         of glyph_id
exception UnsupportedTTC  (* temporary *)
exception CannotFindUnicodeCmap


val get_decoder : file_path -> decoder

type 'a resource =
  | Data           of 'a
  | EmbeddedStream of int

type cmap =
  | PredefinedCMap of string
  | CMapFile       of (string resource) ref  (* temporary;*)

type cid_system_info

module Type1 : sig
  type font
  val of_decoder : decoder -> int -> int -> font
  val to_pdfdict : Pdf.t -> font -> decoder -> Pdf.pdfobject
end

module TrueType : sig
  type font
  val of_decoder : decoder -> int -> int -> font
  val to_pdfdict : Pdf.t -> font -> decoder -> Pdf.pdfobject
end

module Type0 : sig
  type font
  val to_pdfdict : Pdf.t -> font -> decoder -> Pdf.pdfobject
end

module CIDFontType0 : sig
  type font
  val of_decoder : decoder -> cid_system_info -> font
end

module CIDFontType2 : sig
  type font
  val of_decoder : decoder -> cid_system_info -> bool -> font
end

type cid_font =
  | CIDFontType0 of CIDFontType0.font
  | CIDFontType2 of CIDFontType2.font

type font =
  | Type1    of Type1.font
(*  | Type1C *)
(*  | MMType1 *)
(*  | Type3 *)
  | TrueType of TrueType.font
  | Type0    of Type0.font

val type1 : Type1.font -> font
val true_type : TrueType.font -> font
val cid_font_type_0 : CIDFontType0.font -> string -> cmap -> font
val cid_font_type_2 : CIDFontType2.font -> string -> cmap -> font

val get_glyph_metrics : decoder -> glyph_id -> int * int * int
val get_glyph_id : decoder -> Uchar.t -> glyph_id option

val adobe_japan1 : cid_system_info
val adobe_identity : cid_system_info

val get_decoder : file_path -> decoder

val convert_to_ligatures : decoder -> glyph_id list -> glyph_id list

val find_kerning : decoder -> glyph_id -> glyph_id -> int option

type math_kern

type math_kern_info =
  {
    kernTR : math_kern;
    kernTL : math_kern;
    kernBR : math_kern;
    kernBL : math_kern;
  }

type math_decoder

val get_math_decoder : file_path -> math_decoder

val math_base_font : math_decoder -> decoder

val get_math_glyph_info : math_decoder -> Uchar.t -> glyph_id * int * int * int * int option * math_kern_info option

type math_constants =
  {
    superscript_bottom_min   : int;
    superscript_shift_up     : int;
    script_scale_down        : float;
    script_script_scale_down : float;
  }

val get_math_constants : math_decoder -> math_constants

val find_kern_ratio : math_kern -> float -> float
