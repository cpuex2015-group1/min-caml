open Id
open Syntax
open KNormal
open Closure

let margin = 192
let max_indent = 48

type fundef_t   = FdSy of Syntax.t  | FdKn of KNormal.t
type let_t      = LSy of Syntax.t   | LKn of KNormal.t | LCl of Closure.t
type lettuple_t = LtSy of Syntax.t  | LtId of Id.t
type ifop_t     = IoKn of KNormal.t | IoCl of Closure.t

(* id_emit : Id.t -> unit *)
(* 識別子情報を表示する *)
let id_emit id = Format.print_string id

(* label_emit : Id.l -> unit *)
let label_emit (L l) = Format.print_string l

(* type_emit : Type.t -> unit *)
(* 型情報を1文字で表示する *)
let rec type_emit = function
    Type.Unit    -> Format.print_string "u"
  | Type.Bool    -> Format.print_string "b"
  | Type.Int     -> Format.print_string "i"
  | Type.Float   -> Format.print_string "d"
  | Type.Fun _   -> Format.print_string "f"
  | Type.Tuple _ -> Format.print_string "t"
  | Type.Array _ -> Format.print_string "a"
  | Type.Var rt  -> (Format.print_string "v{";
		     (match !rt with
		      | None   -> Format.print_string "None"
		      | Some t -> type_emit t);
		     Format.print_string "}")

(** parser_emit用の関数 *)
(* id_ty_list_iter : (Id.t * Type.t) list -> unit *)
let rec id_ty_list_iter = function
    [] -> ()
  | [(id, ty)] -> (Format.open_hbox ();
		   Format.print_string "(";
		   id_emit id;
		   Format.print_space ();
		   Format.print_string ":";
		   Format.print_space ();
		   type_emit ty;
		   Format.print_string ")";
		   Format.close_box ())
  | (id, ty) :: l -> (Format.open_hbox ();
		      Format.print_string "(";
		      id_emit id;
		      Format.print_space ();
		      Format.print_string ":";
		      Format.print_space ();
		      type_emit ty;
		      Format.print_string ");";
		      Format.close_box ();
		      Format.print_space ();
		      id_ty_list_iter l)

(** parser_emit関係 *)
(* parser_emit : out_channel -> Syntax.t -> unit *)
(* pretty printer of Syntax.t *)
(* NB. Only this function changes out_channel to emitting Parser.t *)
let rec parser_emit oc s =
  (Format.set_formatter_out_channel oc;
   Format.set_margin margin;
   Format.set_max_indent max_indent;
   Format.open_vbox 0;
   parser_iter s;
   Format.print_space ();
   Format.close_box ();
   Format.print_flush ())
and parser_monop_emit name t =
  (Format.open_box 0;
   Format.print_string ("(" ^ name);
   Format.print_space ();
   parser_iter t;
   Format.print_string ")";
   Format.close_box ())
and parser_binop_emit name t0 t1 =
  (Format.open_box 1;
   Format.print_string ("(" ^ name);
   Format.print_space ();
   Format.open_box 0;
   parser_iter t0;
   Format.print_space ();
   parser_iter t1;
   Format.close_box ();
   Format.print_string ")";
   Format.close_box ())
(* parsr_iter : Syntax.t -> unit *)
and parser_iter s =
  begin
    Format.open_box 2;
    begin
      match s with
      | Syntax.Unit ->
	 Format.print_string "Unit"
      | Syntax.Bool b ->
	 (Format.open_hbox ();
	  Format.print_string "(Bool";
	  Format.print_space ();
	  Format.print_bool b;
	  Format.print_string ")";
	  Format.close_box ())
      | Syntax.Int i ->
	 (Format.open_hbox ();
	  Format.print_string "(Int";
	  Format.print_space ();
	  Format.print_int i;
	  Format.print_string ")";
	  Format.close_box ())
      | Syntax.Float f ->
	 (Format.open_hbox ();
	  Format.print_string "(Float";
	  Format.print_space ();
	  Format.print_float f;
	  Format.print_string ")";
	  Format.close_box ())
      | Syntax.Not t -> parser_monop_emit "Not" t
      | Syntax.Neg t -> parser_monop_emit "Neg" t
      | Syntax.Add (t0, t1)  -> parser_binop_emit "Add" t0 t1
      | Syntax.Sub (t0, t1)  -> parser_binop_emit "Sub" t0 t1
      | Syntax.FNeg t        -> parser_monop_emit "FNeg" t
      | Syntax.FAdd (t0, t1) -> parser_binop_emit "Fadd" t0 t1
      | Syntax.FSub (t0, t1) -> parser_binop_emit "FSub" t0 t1
      | Syntax.FMul (t0, t1) -> parser_binop_emit "FMul" t0 t1
      | Syntax.FDiv (t0, t1) -> parser_binop_emit "FDib" t0 t1
      | Syntax.Eq (t0, t1)   -> parser_binop_emit "Eq" t0 t1
      | Syntax.LE (t0, t1)   -> parser_binop_emit "LE" t0 t1
      | Syntax.If (t0, t1, t2) ->
	 (Format.open_hbox ();
	  Format.print_string "(If";
	  Format.print_space ();
	  Format.open_vbox 0;
	  parser_iter t0;
	  Format.print_space ();
	  parser_iter t1;
	  Format.print_space ();
	  parser_iter t2;
	  Format.close_box ();
	  Format.print_string ")";
	  Format.close_box ())
      | Syntax.Let ((id, ty), t0, t1) ->
	 let_emit id ty (LSy t0) (LSy t1)
      | Syntax.Var id ->
	 (Format.print_string "(Var";
	  Format.print_space ();
	  id_emit id;
	  Format.print_string ")")
      | Syntax.LetRec ({name = (id, ty); args = lst; body = tb}, t) ->
	 (Format.open_vbox 1;
	  Format.print_string "(LetRec";
	  Format.print_space ();
	  fundef_emit id ty lst (FdSy tb);
	  Format.print_space ();
	  parser_iter t;
	  Format.print_string ")";
	  Format.close_box ())
      | Syntax.App (t0, t1_list) ->
	 (Format.print_string "(App";
	  Format.print_space ();
	  parser_iter t0;
	  Format.print_space ();
	  parser_list_emit t1_list;
	  Format.print_string ")")
      | Syntax.Tuple t_list ->
	 (Format.print_string "(Tuple";
	  Format.print_space ();
	  parser_list_emit t_list;
	  Format.print_string ")")
      | Syntax.LetTuple (tuple, t0, t1) ->
	 lettuple_emit tuple (LtSy t0) (LSy t1)
      | Syntax.Array (t0, t1) ->
	 (Format.print_string "[Array";
	  Format.print_space ();
	  parser_iter t0;
	  Format.print_string ",";
	  Format.print_space ();
	  parser_iter t1;
	  Format.print_string "]")
      | Syntax.Get (t0, t1) -> parser_binop_emit "Get" t0 t1
      | Syntax.Put (t0, t1, t2) ->
	 (Format.print_string "(Put";
	  Format.print_space ();
	  parser_iter t0;
	  Format.print_space ();
	  parser_iter t1;
	  Format.print_space ();
	  parser_iter t2;
	  Format.print_string ")")
    end;
    Format.close_box ()
  end
(* let_emit : Id.t -> Type.t -> let_t -> let_t -> unit *)
and let_emit id ty t0 t1 =
  (Format.open_vbox 1;
   Format.print_string "(";
   (* definition *)
   Format.open_box 2;
   Format.print_string "Let";
   Format.print_space ();
   id_emit id;
   Format.print_space ();
   Format.print_string ":";
   Format.print_space ();
   type_emit ty;
   Format.print_space ();
   Format.print_string "=";
   Format.print_space ();
   (match t0 with
    | LSy tt -> parser_iter tt
    | LKn tt -> kNormal_iter tt
    | LCl tt -> closure_iter tt);
   Format.close_box ();
   Format.print_space ();
   (* body *)
   Format.open_hbox ();
   Format.print_string "in";
   Format.print_space ();
   (match t1 with
    | LSy tt -> parser_iter tt
    | LKn tt -> kNormal_iter tt
    | LCl tt -> closure_iter tt);
   Format.close_box ();
   Format.print_string ")";
   Format.close_box ())
(* fundef_emit : Id.t -> Type.t -> (Id.t * Type.t) list -> fundef_t -> unit *)
and fundef_emit id ty lst t =
  (Format.open_vbox 1;
   Format.print_string "{";
   (* name *)
   Format.open_hbox ();
   Format.print_string "name = ";
   id_emit id;
   Format.print_space ();
   Format.print_string ":";
   Format.print_space ();
   type_emit ty;
   Format.print_string ";";
   Format.close_box ();
   Format.print_space ();
   (* args *)
   Format.open_hbox ();
   Format.print_string "args = ";
   Format.open_box 1;
   Format.print_string "[";
   id_ty_list_iter lst;
   Format.print_string "]";
   Format.close_box ();
   Format.print_string ";";
   Format.close_box ();
   Format.print_space ();
   (* body *)
   Format.open_box 2;
   Format.print_string "body = ";
   Format.open_box 0;
   (match t with
    | FdSy tt -> parser_iter tt
    | FdKn tt -> kNormal_iter tt);
   Format.close_box ();
   Format.close_box ();
   Format.print_string "}";
   Format.close_box ())
(* parser_list_emit : Type.t list -> unit *)
and parser_list_emit = function
    [] -> ()
  | [x]   -> parser_iter x;
  | x::xs -> (parser_iter x;
	      Format.print_space ();
	      parser_list_emit xs)
(* lettuple_emit : (Id.t * Type.t) -> lettuple_t -> let_t -> unit *)
and lettuple_emit tuple t0 t1 =
  (Format.open_vbox 2;
   Format.print_string "(";
   Format.open_box 2;
   Format.print_string "LetTuple";
   Format.print_space ();
   (* タプル *)
   Format.open_box 1;
   Format.print_string "(";
   id_ty_list_iter tuple;
   Format.print_string ")";
   Format.close_box ();
   Format.print_space ();
   Format.print_string "=";
   Format.print_space ();
   (match t0 with
    | LtSy tt -> parser_iter tt
    | LtId tt -> id_emit tt);
   Format.close_box ();
   Format.print_space ();
   (* body *)
   Format.open_hbox ();
   Format.print_string "in";
   Format.print_space ();
   (match t1 with
    | LSy tt -> parser_iter tt
    | LKn tt -> kNormal_iter tt
    | LCl tt -> closure_iter tt);
   Format.close_box ();
   Format.print_string ")";
   Format.close_box ())

(** kNormal_emit関係 *)
(* kNormal_emit : out_channel -> KNormal.t -> unit *)
and kNormal_emit oc s =
  (Format.set_formatter_out_channel oc;
   Format.set_margin margin;
   Format.set_max_indent max_indent;
   Format.open_vbox 0;
   kNormal_iter s;
   Format.print_space ();
   Format.close_box ();
   Format.print_flush ())
(* kNormal_iter : KNormal.t -> unit *)
and kNormal_iter s =
  begin
    Format.open_box 2;
    begin
      match s with
      | KNormal.Unit    -> parser_iter Syntax.Unit
      | KNormal.Int i   -> parser_iter (Syntax.Int i)
      | KNormal.Float f -> parser_iter (Syntax.Float f)
      | KNormal.Neg id  -> parser_iter (Syntax.Var id)
      | KNormal.Add (id0, id1) ->
	 parser_iter (Syntax.Add (Syntax.Var id0, Syntax.Var id1))
      | KNormal.Sub (id0, id1) ->
	 parser_iter (Syntax.Sub (Syntax.Var id0, Syntax.Var id1))
      | KNormal.FNeg id -> parser_iter (Syntax.Var id)
      | KNormal.FAdd (id0, id1) ->
	 parser_iter (Syntax.FAdd (Syntax.Var id0, Syntax.Var id1))
      | KNormal.FSub (id0, id1) ->
	 parser_iter (Syntax.FSub (Syntax.Var id0, Syntax.Var id1))
      | KNormal.FMul (id0, id1) ->
	 parser_iter (Syntax.FMul (Syntax.Var id0, Syntax.Var id1))
      | KNormal.FDiv (id0, id1) ->
	 parser_iter (Syntax.FDiv (Syntax.Var id0, Syntax.Var id1))
      | KNormal.IfEq (id0, id1, t0, t1) ->
	 ifop_emit "IfEq" id0 id1 (IoKn t0) (IoKn t1)
      | KNormal.IfLE (id0, id1, t0, t1) ->
	 ifop_emit "IfLe" id0 id1 (IoKn t0) (IoKn t1)
      | KNormal.Let ((id, ty), t0, t1) ->
	 let_emit id ty (LKn t0) (LKn t1)
      | KNormal.Var id -> parser_iter (Syntax.Var id)
      | KNormal.LetRec ({name = (id, ty); args = lst; body = tb}, t) ->
	 (Format.open_vbox 1;
	  Format.print_string "(LetRec";
	  Format.print_space ();
	  fundef_emit id ty lst (FdKn tb);
	  Format.print_space ();
	  kNormal_iter t;
	  Format.print_string ")";
	  Format.close_box ())
      | KNormal.App (id0, id1_lst) ->
	 parser_iter (Syntax.App
			(Syntax.Var id0,
			 List.rev_map (fun id -> Syntax.Var id) id1_lst))
      | KNormal.Tuple id_lst ->
	 parser_iter (Syntax.Tuple
			(List.rev_map (fun id -> Syntax.Var id) id_lst))
      | KNormal.LetTuple (tuple, id, t) ->
	 lettuple_emit tuple (LtId id) (LKn t)
      | KNormal.Get (id0, id1) ->
	 parser_iter (Syntax.Get (Syntax.Var id0, Syntax.Var id1))
      | KNormal.Put (id0, id1, id2) ->
	 parser_iter (Syntax.Put (Syntax.Var id0, Syntax.Var id1, Syntax.Var id2))
      | KNormal.ExtArray id ->
	 (Format.open_box 1;
	  Format.print_string "(ExtArray";
	  Format.print_space ();
	  id_emit id;
	  Format.print_string ")")
      | KNormal.ExtFunApp (id0, id1_lst) ->
	 (Format.open_box 1;
	  Format.print_string "(ExtFunApp";
	  Format.print_space ();
	  id_emit id0;
	  Format.print_space ();
	  Format.open_box 1;
	  Format.print_string "(";
	  parser_list_emit (List.rev_map
			      (fun id -> (Syntax.Var id)) id1_lst);
	  Format.print_string ")";
	  Format.close_box ();
	  Format.close_box ())
    end;
    Format.close_box ()
  end
(* ifop_emit : string -> Id.t -> Id.t -> ifop_t -> ifop_t -> unit *)
and ifop_emit name id0 id1 t0 t1 =
  (Format.open_vbox 1;
   (* 評価式 *)
   Format.open_hbox ();
   Format.print_string ("(" ^ name);
   Format.print_space ();
   parser_iter (Syntax.Var id0);
   Format.print_space ();
   parser_iter (Syntax.Var id1);
   Format.close_box ();
   Format.print_space ();
   (* true節、false節 *)
   (match t0 with
    | IoKn tt -> kNormal_iter tt
    | IoCl tt -> closure_iter tt);
   Format.print_space ();
   (match t1 with
    | IoKn tt -> kNormal_iter tt
    | IoCl tt -> closure_iter tt);
   Format.print_string ")")


(** prog_emit関係 *)
(* prog_emit : out_channel -> Closure.prog -> unit *)
and prog_emit oc (Prog (fundef_lst, s)) =
  (Format.set_formatter_out_channel oc;
   Format.set_margin margin;
   Format.set_max_indent max_indent;
   Format.open_vbox 0;
   fundef_list_emit fundef_lst;
   Format.print_space ();
   closure_iter s;
   Format.print_space ();
   Format.close_box ();
   Format.print_flush ())
(* fundef_list_emit : fundef list -> unit *)
and fundef_list_emit = function
    [] -> ()
  | [fd]    -> cl_fundef_emit fd
  | fd :: l -> (Format.open_vbox 0;
		cl_fundef_emit fd;
		Format.print_space ();
		fundef_list_emit l;
		Format.close_box ())
(* cl_fundef_emit : Closure.fundef -> unit *)
and cl_fundef_emit {name = (label, ty); args = args; formal_fv = formal_fv; body = t} =
  (Format.open_vbox 0;
   Format.print_string "{";
   (* name *)
   Format.open_hbox ();
   Format.print_string "name = ";
   label_emit label;
   Format.print_space ();
   Format.print_string ":";
   Format.print_space ();
   type_emit ty;
   Format.print_string ";";
   Format.close_box ();
   Format.print_space ();
   (* args *)
   Format.open_hbox ();
   Format.print_string "args = ";
   Format.open_box 1;
   Format.print_string "[";
   id_ty_list_iter args;
   Format.print_string "]";
   Format.close_box ();
   Format.print_string ";";
   Format.close_box ();
   Format.print_space ();
   (* formal_fv *)
   Format.open_hbox ();
   Format.print_string "formal_fv = ";
   Format.open_box 1;
   Format.print_string "[";
   id_ty_list_iter formal_fv;
   Format.print_string "]";
   Format.close_box ();
   Format.print_string ";";
   Format.close_box ();
   Format.print_space ();
   (* body *)
   Format.open_box 2;
   Format.print_string "body = ";
   Format.open_box 0;
   closure_iter t;
   Format.close_box ();
   Format.close_box ();
   Format.print_string "}";
   Format.close_box ())
(* closure_iter : Closure.t -> unit *)
and closure_iter s =
  begin
    Format.open_box 2;
    begin
      match s with
      | Closure.Unit    -> kNormal_iter KNormal.Unit
      | Closure.Int i   -> kNormal_iter (KNormal.Int i)
      | Closure.Float f -> kNormal_iter (KNormal.Float f)
      | Closure.Neg id  -> kNormal_iter (KNormal.Neg id)
      | Closure.Add (id0, id1)  -> kNormal_iter (KNormal.Add (id0, id1))
      | Closure.Sub (id0, id1)  -> kNormal_iter (KNormal.Sub (id0, id1))
      | Closure.FNeg id         -> kNormal_iter (KNormal.FNeg id)
      | Closure.FAdd (id0, id1) -> kNormal_iter (KNormal.FAdd (id0, id1))
      | Closure.FSub (id0, id1) -> kNormal_iter (KNormal.FSub (id0, id1))
      | Closure.FMul (id0, id1) -> kNormal_iter (KNormal.FMul (id0, id1))
      | Closure.FDiv (id0, id1) -> kNormal_iter (KNormal.FDiv (id0, id1))
      | Closure.IfEq (id0, id1, t0, t1) ->
	 ifop_emit "IfEq" id0 id1 (IoCl t0) (IoCl t1)
      | Closure.IfLE (id0, id1, t0, t1) ->
	 ifop_emit "IfLE" id0 id1 (IoCl t0) (IoCl t1)
      | Closure.Let ((id, ty), t0, t1) ->
	 let_emit id ty (LCl t0) (LCl t1)
      | Closure.Var id -> kNormal_iter (KNormal.Var id)
      | Closure.MakeCls ((id, ty), cl, t) ->
	  (Format.open_vbox 1;
	   Format.print_string "(MakeCls";
	   Format.print_space ();
	   Format.open_hbox ();
	   id_emit id;
	   Format.print_space ();
	   type_emit ty;
	   Format.close_box ();
	   Format.print_space ();
	   cl_emit cl;
	   Format.print_space ();
	   closure_iter t;
	   Format.print_string ")";
	   Format.close_box ())
      | Closure.AppCls (id0, id1_lst) ->
	  (Format.print_string "(AppCls";
	   Format.print_space ();
	   (* 識別子 *)
	   Format.open_box 2;
	   Format.print_string "(Var";
	   Format.print_space ();
	   id_emit id0;
	   Format.print_string ")";
	   Format.close_box ();
	   Format.print_space ();
	   (* 引数 *)
	   parser_list_emit (List.rev_map (fun id -> Syntax.Var id) id1_lst);
	   Format.print_string ")")
      | Closure.AppDir (label, id_lst) ->
	  (Format.print_string "(AppCls";
	   Format.print_space ();
	   (* 識別子 *)
	   Format.open_box 2;
	   Format.print_string "(Var";
	   Format.print_space ();
	   label_emit label;
	   Format.print_string ")";
	   Format.close_box ();
	   Format.print_space ();
	   (* 引数 *)
	   parser_list_emit (List.rev_map (fun id -> Syntax.Var id) id_lst);
	   Format.print_string ")")
      | Closure.Tuple tuple -> kNormal_iter (KNormal.Tuple tuple)
      | Closure.LetTuple (tuple, id, t) ->
	 lettuple_emit tuple (LtId id) (LCl t)
      | Closure.Get (id0, id1)      -> kNormal_iter (KNormal.Get (id0, id1))
      | Closure.Put (id0, id1, id2) -> kNormal_iter (KNormal.Put (id0, id1, id2))
      | Closure.ExtArray label ->
	 (Format.print_string "(ExtArray";
	  Format.print_space ();
	  label_emit label;
	  Format.print_string ")")
    end;
    Format.close_box ()
  end
(* cl_emit : Closure.closure -> unit *)
(* NB. not closure_emit *)
and cl_emit {entry = label; actual_fv = id_lst} =
  (Format.open_box 1;
   Format.print_string "(MakeCls";
   Format.print_space ();
   Format.print_string "{entry = ";
   label_emit label;
   Format.print_string ";";
   Format.print_space ();
   Format.print_string "actual_fv = ";
   Format.open_box 1;
   Format.print_string "[";
   id_list_iter id_lst;
   Format.print_string "]";
   Format.close_box ();
   Format.print_string "}";
   Format.close_box ())
(* id_list_iter : Id.t list -> unit *)
and id_list_iter = function
    [] -> ()
  | [id]    -> Format.print_string id
  | id :: l -> (Format.print_string "id";
		Format.print_space ();
		id_list_iter l)

(** main.ml用の情報 *)
type level = (* どの段階でデバッグ出力するかを管理する型 *)
  | Parser
  | Typing
  | KNormal
  | Alpha
  | Iter
  | Closure
  | Virtual
  | Simm
  | RegAlloc
  | Emit

(* level_of_string : string -> Debug.level *)
(* 規定外なら(例外を出すのではなく)Emit扱いにする *)
let level_of_string = function
    "Parser"   -> Parser
  | "Typing"   -> Typing
  | "KNormal"  -> KNormal
  | "Alpha"    -> Alpha
  | "Iter"     -> Iter
  | "Closure"  -> Closure
  | "Virtual"  -> Virtual
  | "Simm"     -> Simm
  | "RegAlloc" -> RegAlloc
  | _          -> Emit