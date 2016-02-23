open Types

type definition_kind   = Data | Hidden | Synonym of type_struct
type defined_type_list = (type_name * definition_kind) list
type constructor_list  = (constructor_name * type_name * type_struct) list
type t = defined_type_list * constructor_list


(* t *)
let empty = ([], [])


(* t -> constructor_name -> type_struct -> type_name -> t *)
let rec add (varntenv : t) (constrnm : constructor_name) (tystr : type_struct) (varntnm : type_name) =
  let (defedtylst, varntenvmain) = varntenv in
    (defedtylst, add_main varntenvmain constrnm tystr varntnm)

(* constructor_list -> constructor_name -> type_struct -> type_name *)
and add_main (varntenvmain : constructor_list) (constrnm : constructor_name) (tystr : type_struct) (varntnm : type_name) =
  match varntenvmain with
  | []                -> [(constrnm, varntnm, tystr)]
  | (c, v, t) :: tail ->
      if c = constrnm then
        (constrnm, varntnm, tystr) :: tail
      else
        (c, v, t) :: (add_main tail constrnm tystr varntnm)


(* defined_type_list -> type_name -> definition_kind *)
let rec find_definition_kind defedtylst tynm =
  match defedtylst with
  | []                            -> raise Not_found
  | (tn, ts) :: tl when tn = tynm -> ts
  | _ :: tl                       -> find_definition_kind tl tynm


let rec is_defined_type_argument (tyargcons : untyped_type_argument_cons) (tyargnm : var_name) =
  match tyargcons with
  | UTEndOfTypeArgument                 -> false
  | UTTypeArgumentCons(_, nm, tailcons) ->
      begin
        print_string ("tyarg: " ^ nm ^ "\n") ;
        if nm = tyargnm then true else is_defined_type_argument tailcons tyargnm
      end


(* t -> untyped_type_argument_cons -> type_struct -> type_struct *)
let rec check_type_defined (varntenv : t) (tyargcons : untyped_type_argument_cons) (tystr : type_struct) =
	let (defedtylst, varntenvmain) = varntenv in
  	match tystr with
    | VariantType(rng, varntnm) ->
        begin
          try
            match find_definition_kind defedtylst varntnm with
            | Data           -> VariantType(rng, varntnm)
            | Hidden         -> VariantType(rng, varntnm)
            | Synonym(tystr) -> TypeSynonym(rng, varntnm, tystr)
          with
          | Not_found ->
              raise (TypeCheckError(
                  "at " ^ (Display.describe_position rng) ^ ":\n"
                ^ "    undefined type '" ^ varntnm ^ "'"))
        end
  	| FuncType(rng, tydom, tycod) -> FuncType(rng, check_type_defined varntenv tyargcons tydom,
                                                   check_type_defined varntenv tyargcons tycod)
  	| ListType(rng, tycont)       -> ListType(rng, check_type_defined varntenv tyargcons tycont)
  	| RefType(rng, tycont)        -> RefType(rng, check_type_defined varntenv tyargcons tycont)
  	| ProductType(rng, tylist)    -> ProductType(rng, List.map (check_type_defined varntenv tyargcons) tylist)
    | TypeArgument(rng, tyargnm)  ->
          if is_defined_type_argument tyargcons tyargnm then
            TypeArgument(rng, tyargnm)
          else
            raise (TypeCheckError(
                "at " ^ (Display.describe_position rng) ^ ":\n"
              ^ "    undefined type argument '" ^ tyargnm ^ "'"))
  	| other                       -> other


let append_module_name mdlnm varntnm =
  match mdlnm with
  | "" -> varntnm
  | _  -> mdlnm ^ "." ^ varntnm


(* t -> type_name -> untyped_type_argument_cons -> t *)
let add_variant (varntenv :t) (tyargcons : untyped_type_argument_cons) (tynm : type_name) =
  let (defedtypelist, varntenvmain) = varntenv in ((tynm, Data) :: defedtypelist, varntenvmain)


let add_hidden_type (mdlnm : module_name) (varntenv : t) (tyargcons : untyped_type_argument_cons) (tynm : type_name) =
  let (defedtypelist, varntenvmain) = varntenv in ((append_module_name mdlnm tynm, Hidden) :: defedtypelist, varntenvmain)


(* t -> type_name -> type_struct -> t *)
let add_type_synonym varntenv tynm tystr =
  let (defedtypelist, varntenvmain) = varntenv in
  let tystr_new = check_type_defined varntenv UTEndOfTypeArgument tystr in
    ((tynm, Synonym(tystr_new)) :: defedtypelist, varntenvmain)


let rec add_cons (mdlnm : module_name) (varntenv : t)
                   (tyargcons : untyped_type_argument_cons) (varntnm : type_name) (utvc : untyped_variant_cons) =
	  add_cons_main mdlnm (add_variant varntenv tyargcons varntnm) tyargcons varntnm utvc

and add_cons_main (mdlnm : module_name) (varntenv : t)
                    (tyargcons : untyped_type_argument_cons) (varntnm : type_name) (utvc : untyped_variant_cons) =
  let (rng, utvcmain) = utvc in
    match utvcmain with
    | UTEndOfVariant                           -> varntenv
    | UTVariantCons(constrnm, tystr, tailcons) ->
        let tystr_new    = check_type_defined varntenv tyargcons tystr in
        let varntenv_new = add varntenv constrnm tystr_new (append_module_name mdlnm varntnm) in
          add_cons_main mdlnm varntenv_new tyargcons varntnm tailcons


(* t -> untyped_mutual_variant_cons -> t *)
let rec add_mutual_cons varntenv mutvarntcons =
  let varntenv_new = add_mutual_variant_type "" varntenv mutvarntcons in
    match mutvarntcons with
    | UTEndOfMutualVariant                                    -> varntenv_new
    | UTMutualVariantCons(tyargcons, varntnm, utvc, tailcons) ->
        add_mutual_cons (add_cons "" varntenv_new tyargcons varntnm utvc) tailcons


(* module_name -> t -> untyped_mutual_variant_cons -> t *)
and add_mutual_cons_hidden mdlnm varntenv mutvarntcons =
  let varntenv_new = add_mutual_variant_type mdlnm varntenv mutvarntcons in
    match mutvarntcons with
    | UTEndOfMutualVariant                                 -> varntenv_new
    | UTMutualVariantCons(tyargcons, varntnm, _, tailcons) ->
        add_mutual_cons_hidden mdlnm (add_hidden_type mdlnm varntenv_new tyargcons varntnm) tailcons


(* module_name -> t -> untyped_mutual_variant_cons *)
and add_mutual_variant_type mdlnm varntenv mutvarntcons =
  match mutvarntcons with
  | UTEndOfMutualVariant                                 -> varntenv
  | UTMutualVariantCons(tyargcons, varntnm, _, tailcons) ->
      add_mutual_variant_type mdlnm (add_variant varntenv tyargcons (append_module_name mdlnm varntnm)) tailcons




(* t -> constructor_name -> (type_name * type_struct) *)
let rec find varntenv constrnm =
	let (_, varntenvmain) = varntenv in find_main varntenvmain constrnm

and find_main varntenvmain constrnm =
    match varntenvmain with
    | []                -> raise Not_found
    | (c, v, t) :: tail -> if c = constrnm then (v, t) else find_main tail constrnm
