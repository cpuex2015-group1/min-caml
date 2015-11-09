(* translation into assembly with infinite number of virtual registers *)

open Asm

let data = ref [] (* ��ư��������������ơ��֥� (caml2html: virtual_data) *)

let classify xts ini addf addi =
  List.fold_left
    (fun acc (x, t) ->
      match t with
      | Type.Unit -> acc
      | Type.Float -> addf acc x
      | _ -> addi acc x t)
    ini
    xts

let separate xts =
  classify
    xts
    ([], [])
    (fun (int, float) x -> (int, float @ [x]))
    (fun (int, float) x _ -> (int @ [x], float))

let expand xts ini addf addi =
  classify
    xts
    ini
    (fun (offset, acc) x ->
      (offset + 4, addf x offset acc))
    (fun (offset, acc) x t ->
      (offset + 4, addi x t offset acc))

let rec g env = function (* ���β��ۥޥ��󥳡������� (caml2html: virtual_g) *)
  | Closure.Unit(p) -> Ans(Nop(p))
  | Closure.Int(i, p) -> Ans(Set(i, p))
  | Closure.Float(d, p) ->
      let l =
	try
	  (* ���Ǥ�����ơ��֥�ˤ��ä�������� *)
	  let (l, _) = List.find (fun (_, d') -> d = d') !data in
	  l
	with Not_found ->
	  let l = Id.L(Id.genid "l") in
	  data := (l, d) :: !data;
	  l in
      let x = Id.genid "l" in
      Let((x, Type.Int), SetL(l, p), Ans(LdF(x, C(0), 4, p)))
  | Closure.Neg(x, p) -> Ans(Neg(x, p))
  | Closure.Add(x, y, p) -> Ans(Add(x, V(y), p))
  | Closure.Sub(x, y, p) -> Ans(Sub(x, V(y), p))
  | Closure.Mul(x, y, p) -> Ans(Mul(x, V(y), p))
  | Closure.Div(x, y, p) -> Ans(Div(x, V(y), p))
  | Closure.FNeg(x, p) -> Ans(FNeg(x, p))
  | Closure.FAdd(x, y, p) -> Ans(FAdd(x, y, p))
  | Closure.FSub(x, y, p) -> Ans(FSub(x, y, p))
  | Closure.FMul(x, y, p) -> Ans(FMul(x, y, p))
  | Closure.FDiv(x, y, p) -> Ans(FDiv(x, y, p))
  | Closure.IfEq(x, y, e1, e2, p) ->
      (match M.find x env with
      | Type.Bool | Type.Int -> Ans(IfEq(x, V(y), g env e1, g env e2, p))
      | Type.Float -> Ans(IfFEq(x, y, g env e1, g env e2, p))
      | _ -> failwith "equality supported only for bool, int, and float")
  | Closure.IfLE(x, y, e1, e2, p) ->
      (match M.find x env with
      | Type.Bool | Type.Int -> Ans(IfLE(x, V(y), g env e1, g env e2, p))
      | Type.Float -> Ans(IfFLE(x, y, g env e1, g env e2, p))
      | _ -> failwith "inequality supported only for bool, int, and float")
  | Closure.Let((x, t1), e1, e2, _) ->
      let e1' = g env e1 in
      let e2' = g (M.add x t1 env) e2 in
      concat e1' (x, t1) e2'
  | Closure.Var(x, p) ->
      (match M.find x env with
      | Type.Unit -> Ans(Nop(p))
      | Type.Float -> Ans(FMov(x, p))
      | _ -> Ans(Mov(x, p)))
  | Closure.MakeCls((x, t), { Closure.entry = l; Closure.actual_fv = ys }, e2, p) -> (* ������������� (caml2html: virtual_makecls) *)
      (* Closure�Υ��ɥ쥹�򥻥åȤ��Ƥ��顢��ͳ�ѿ����ͤ򥹥ȥ� *)
      let e2' = g (M.add x t env) e2 in
      let offset, store_fv =
	expand
	  (List.map (fun y -> (y, M.find y env)) ys)
	  (4, e2')
	  (fun y offset store_fv -> (assert(offset mod 4 = 0); seq(StF(y, x, C(offset / 4), 4, p), store_fv)))
	  (fun y _ offset store_fv -> (assert(offset mod 4 = 0); seq(St(y, x, C(offset / 4), 4, p), store_fv))) in
      assert(offset mod 4 = 0);
      Let((x, t), Mov(reg_hp, p),
	  Let((reg_hp, Type.Int), Add(reg_hp, C(offset / 4), p),
	      let z = Id.genid "l" in
	      Let((z, Type.Int), SetL(l, p),
		  seq(St(z, x, C(0), 4, p),
		      store_fv))))
  | Closure.AppCls(x, ys, p) ->
      let (int, float) = separate (List.map (fun y -> (y, M.find y env)) ys) in
      Ans(CallCls(x, int, float, p))
  | Closure.AppDir(Id.L(x), ys, p) ->
      let (int, float) = separate (List.map (fun y -> (y, M.find y env)) ys) in
      Ans(CallDir(Id.L(x), int, float, p))
  | Closure.Tuple(xs, p) -> (* �Ȥ����� (caml2html: virtual_tuple) *)
      let y = Id.genid "t" in
      let (offset, store) =
	expand
	  (List.map (fun x -> (x, M.find x env)) xs)
	  (0, Ans(Mov(y, p)))
	  (fun x offset store -> (assert(offset mod 4 = 0); seq(StF(x, y, C(offset / 4), 4, p), store)))
	  (fun x _ offset store -> (assert(offset mod 4 = 0); seq(St(x, y, C(offset / 4), 4, p), store))) in
      assert(offset mod 4 = 0);
      Let((y, Type.Tuple(List.map (fun x -> M.find x env) xs)), Mov(reg_hp, p),
	  Let((reg_hp, Type.Int), Add(reg_hp, C(offset / 4), p),
	      store))
  | Closure.LetTuple(xts, y, e2, p) ->
      let s = Closure.fv e2 in
      let (offset, load) =
	expand
	  xts
	  (0, g (M.add_list xts env) e2)
	  (fun x offset load ->
	    if not (S.mem x s) then load else (* [XX] a little ad hoc optimization *)
	    (assert(offset mod 4 = 0); fletd(x, LdF(y, C(offset / 4), 4, p), load)))
	  (fun x t offset load ->
	    if not (S.mem x s) then load else (* [XX] a little ad hoc optimization *)
	    (assert(offset mod 4 = 0); Let((x, t), Ld(y, C(offset / 4), 4, p), load))) in
      load
  | Closure.Get(x, y, p) -> (* ������ɤ߽Ф� (caml2html: virtual_get) *)
      (match M.find x env with
      | Type.Array(Type.Unit) -> Ans(Nop(p))
      | Type.Array(Type.Float) -> Ans(LdF(x, V(y), 4, p))
      | Type.Array(_) -> Ans(Ld(x, V(y), 4, p))
      | _ -> assert false)
  | Closure.Put(x, y, z, p) ->
      (match M.find x env with
      | Type.Array(Type.Unit) -> Ans(Nop(p))
      | Type.Array(Type.Float) -> Ans(StF(z, x, V(y), 4, p))
      | Type.Array(_) -> Ans(St(z, x, V(y), 4, p))
      | _ -> assert false)
  | Closure.ExtArray(Id.L(x), p) -> Ans(SetL(Id.L("min_caml_" ^ x), p))

(* �ؿ��β��ۥޥ��󥳡������� (caml2html: virtual_h) *)
let h { Closure.name = (Id.L(x), t); Closure.args = yts; Closure.formal_fv = zts; Closure.body = e } =
  let (int, float) = separate yts in
  let (offset, load) =
    expand
      zts
      (4, g (M.add x t (M.add_list yts (M.add_list zts M.empty))) e)
      (fun z offset load -> (assert(offset mod 4 = 0); fletd(z, LdF(reg_cl, C(offset / 4), 4, Lexing.dummy_pos), load)))
      (fun z t offset load -> (assert(offset mod 4 = 0); Let((z, t), Ld(reg_cl, C(offset / 4), 4, Lexing.dummy_pos), load))) in
  match t with
  | Type.Fun(_, t2) ->
      { name = Id.L(x); args = int; fargs = float; body = load; ret = t2 }
  | _ -> assert false

(* �ץ�������Τβ��ۥޥ��󥳡������� (caml2html: virtual_f) *)
let f (Closure.Prog(fundefs, e)) =
  data := [];
  let fundefs = List.map h fundefs in
  let e = g M.empty e in
  Prog(!data, fundefs, e)
