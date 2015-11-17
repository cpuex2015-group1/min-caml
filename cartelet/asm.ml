(* 2���ڥ��ɤǤϤʤ�3���ڥ��ɤ�x86������֥��ɤ� *)

type id_or_imm = V of Id.t | C of int
type t = (* ̿����� (caml2html: sparcasm_t) *)
  | Ans of exp
  | Let of (Id.t * Type.t) * exp * t
and exp = (* ��İ�Ĥ�̿����б����뼰 (caml2html: sparcasm_exp) *)
  | Nop of Lexing.position
  | Set of int * Lexing.position
  | SetL of Id.l * Lexing.position
  | Mov of Id.t * Lexing.position
  | Neg of Id.t * Lexing.position
  | Add of Id.t * id_or_imm * Lexing.position
  | Sub of Id.t * id_or_imm * Lexing.position
  | Mul of Id.t * id_or_imm * Lexing.position
  | Div of Id.t * id_or_imm * Lexing.position
  | Ld of Id.t * id_or_imm * int * Lexing.position
  | St of Id.t * Id.t * id_or_imm * int * Lexing.position
  | FMov of Id.t * Lexing.position
  | FNeg of Id.t * Lexing.position
  | FAdd of Id.t * Id.t * Lexing.position
  | FSub of Id.t * Id.t * Lexing.position
  | FMul of Id.t * Id.t * Lexing.position
  | FDiv of Id.t * Id.t * Lexing.position
  | LdF of Id.t * id_or_imm * int * Lexing.position
  | StF of Id.t * Id.t * id_or_imm * int * Lexing.position
  | Comment of string * Lexing.position
  (* virtual instructions *)
  | IfEq of Id.t * id_or_imm * t * t * Lexing.position
  | IfLE of Id.t * id_or_imm * t * t * Lexing.position
  | IfGE of Id.t * id_or_imm * t * t  * Lexing.position(* �����оΤǤϤʤ��Τ�ɬ�� *)
  | IfFEq of Id.t * Id.t * t * t * Lexing.position
  | IfFLE of Id.t * Id.t * t * t * Lexing.position
  (* closure address, integer arguments, and float arguments *)
  | CallCls of Id.t * Id.t list * Id.t list * Lexing.position
  | CallDir of Id.l * Id.t list * Id.t list * Lexing.position
  | Save of Id.t * Id.t  * Lexing.position(* �쥸�����ѿ����ͤ򥹥��å��ѿ�����¸ (caml2html: sparcasm_save) *)
  | Restore of Id.t  * Lexing.position(* �����å��ѿ������ͤ����� (caml2html: sparcasm_restore) *)
type fundef = { name : Id.l; args : Id.t list; fargs : Id.t list; body : t; ret : Type.t }
(* �ץ�������� = ��ư���������ơ��֥� + �ȥåץ�٥�ؿ� + �ᥤ��μ� (caml2html: sparcasm_prog) *)
type prog = Prog of (Id.l * float) list * fundef list * t

let fletd(x, e1, e2) = Let((x, Type.Float), e1, e2)
let seq(e1, e2) = Let((Id.gentmp Type.Unit, Type.Unit), e1, e2)

let regs_result    = Array.init 2 (fun i -> Printf.sprintf "%%r%d" (i+2))
let regs_arg       = Array.init 4 (fun i -> Printf.sprintf "%%r%d" (i+4))
let regs_saved_tmp = Array.init 8 (fun i -> Printf.sprintf "%%r%d" (i+16))
let regs_tmp       = Array.init 9 (fun i -> Printf.sprintf "%%r%d" (i+8)) (* r24��swap�Τ��ᡢr25��reg_tmp�Τ���˻Ĥ� *)
let regs = Array.append (Array.append regs_result regs_arg) regs_tmp
let fregs = Array.init 31 (fun i -> Printf.sprintf "%%f%d" i) (* f31��reg_ftmp�Τ���˻Ĥ� *)
let allregs = Array.to_list regs
let allfregs = Array.to_list fregs
let reg_cl = regs.(Array.length regs - 1) (* closure address (caml2html: sparcasm_regcl) *)

let reg_sw = "%r24" (* temporary for swap *)
let reg_fsw = fregs.(Array.length fregs - 1) (* temporary for swap *)

let reg_zero = "%r0" (* zero register *)
let reg_rv = "%r2"  (* return value 1 *)
let reg_frv = "%f0"
let reg_tmp = "%r25"
let reg_ftmp = "%f31"
let reg_hp = "%r28" (* heap pointer (caml2html: sparcasm_reghp) *) (* MIPSŪ�ˤ�grobal pointer *)
let reg_sp = "%r29" (* stack pointer *)
let reg_ra = "%r31" (* return address *)
let is_reg x = (x.[0] = '%')

(* super-tenuki *)
let rec remove_and_uniq xs = function
  | [] -> []
  | x :: ys when S.mem x xs -> remove_and_uniq xs ys
  | x :: ys -> x :: remove_and_uniq (S.add x xs) ys

(* free variables in the order of use (for spilling) (caml2html: sparcasm_fv) *)
let fv_id_or_imm = function V(x) -> [x] | _ -> []
let rec fv_exp = function
  | Nop _ | Set _ | SetL _ | Comment _ | Restore _ -> []
  | Mov(x, _) | Neg(x, _) | FMov(x, _) | FNeg(x, _) | Save(x, _, _) -> [x]
  | Add(x, y', _) | Sub(x, y', _) | Mul(x, y', _) | Div(x, y', _) | Ld(x, y', _, _) | LdF(x, y', _, _) -> x :: fv_id_or_imm y'
  | St(x, y, z', _, _) | StF(x, y, z', _, _) -> x :: y :: fv_id_or_imm z'
  | FAdd(x, y, _) | FSub(x, y, _) | FMul(x, y, _) | FDiv(x, y, _) -> [x; y]
  | IfEq(x, y', e1, e2, _) | IfLE(x, y', e1, e2, _) | IfGE(x, y', e1, e2, _) -> x :: fv_id_or_imm y' @ remove_and_uniq S.empty (fv e1 @ fv e2) (* uniq here just for efficiency *)
  | IfFEq(x, y, e1, e2, _) | IfFLE(x, y, e1, e2, _) -> x :: y :: remove_and_uniq S.empty (fv e1 @ fv e2) (* uniq here just for efficiency *)
  | CallCls(x, ys, zs, _) -> x :: ys @ zs
  | CallDir(_, ys, zs, _) -> ys @ zs
and fv = function
  | Ans(exp) -> fv_exp exp
  | Let((x, t), exp, e) ->
      fv_exp exp @ remove_and_uniq (S.singleton x) (fv e)
let fv e = remove_and_uniq S.empty (fv e)

let rec concat e1 xt e2 =
  match e1 with
  | Ans(exp) -> Let(xt, exp, e2)
  | Let(yt, exp, e1') -> Let(yt, exp, concat e1' xt e2)

let align i = (if i mod 4 = 0 then i else i + 4)

let pos_of_exp = function (* Asm.exp����Lexing.position��ȴ���Ф� *)
    Nop(p)
  | Set(_, p) | SetL(_, p) | Mov(_, p)
  | Neg(_, p) | Add(_, _, p) | Sub(_, _, p) | Mul(_, _, p) | Div(_, _, p)
  | Ld(_, _, _, p) | St(_, _, _, _, p)
  | FMov(_, p) | FNeg(_, p) | FAdd(_, _, p) | FSub(_, _, p) | FMul(_, _, p) | FDiv(_, _, p)
  | LdF(_, _, _, p) | StF(_, _, _, _, p)
  | Comment (_, p)
  | IfEq(_, _, _, _, p) | IfLE(_, _, _, _, p) | IfGE(_, _, _, _, p)
  | IfFEq(_, _, _, _, p) | IfFLE(_, _, _, _, p)
  | CallCls(_, _, _, p) | CallDir(_, _, _, p)
  | Save(_, _, p) | Restore(_, p) -> p
