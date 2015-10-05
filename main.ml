let limit = ref 1000
let debug_level = ref Debug.Emit

let rec iter n e = (* 最適化処理をくりかえす (caml2html: main_iter) *)
  Format.eprintf "iteration %d@." n;
  if n = 0 then e else
  let e' = Elim.f (ConstFold.f (Inline.f (Assoc.f (Beta.f e)))) in
  if e = e' then e else
  iter (n - 1) e'

let lexbuf outchan l = (* バッファをコンパイルor途中まで変換してチャンネルへ出力する *)
  Id.counter := 0;
  Typing.extenv := M.empty;
  try
   (match !debug_level with
    | Debug.Parser ->
       Debug.parser_emit outchan (Parser.exp Lexer.token l)
    | Debug.Typing ->
       Debug.parser_emit outchan (Typing.f (Parser.exp Lexer.token l))
    | Debug.KNormal ->
       Debug.kNormal_emit outchan (KNormal.f (Typing.f (Parser.exp Lexer.token l)))
    | Debug.Alpha ->
       Debug.kNormal_emit outchan (Alpha.f
				     (KNormal.f
					(Typing.f (Parser.exp Lexer.token l))))
    | Debug.Iter ->
       Debug.kNormal_emit outchan
			  (iter !limit
				(Alpha.f
				   (KNormal.f
				      (Typing.f (Parser.exp Lexer.token l)))))
    | Debug.Closure ->
       Debug.closure_prog_emit
	 outchan
	 (Closure.f
	    (iter !limit
		  (Alpha.f
		     (KNormal.f
			(Typing.f (Parser.exp Lexer.token l))))))
    | Debug.Virtual ->
       DebugAsm.asm_prog_emit
	 outchan
	 (Virtual.f
	    (Closure.f
	       (iter !limit
		     (Alpha.f
			(KNormal.f
			   (Typing.f (Parser.exp Lexer.token l)))))))
    | Debug.Simm ->
       DebugAsm.asm_prog_emit
	 outchan
	 (Simm.f
	    (Virtual.f
	       (Closure.f
		  (iter !limit
			(Alpha.f
			   (KNormal.f
			      (Typing.f (Parser.exp Lexer.token l))))))))
    | Debug.RegAlloc ->
       DebugAsm.asm_prog_emit
	 outchan
	 (RegAlloc.f
	    (Simm.f
	       (Virtual.f
		  (Closure.f
		     (iter !limit
			   (Alpha.f
			      (KNormal.f
				 (Typing.f (Parser.exp Lexer.token l)))))))))
    | Debug.Emit ->
       Emit.f outchan
	      (RegAlloc.f
		 (Simm.f
		    (Virtual.f
		       (Closure.f
			  (iter !limit
				(Alpha.f
				   (KNormal.f
				      (Typing.f
					 (Parser.exp Lexer.token l)))))))))
   );
  with
    Typing.Error(e, ty1, ty2, p) ->
      (Format.eprintf "Error: This expression@%d has type %s but an expression was expected type %s\n\t"
		      p.Lexing.pos_lnum
		      (Type.string_of_type ty2)
		      (Type.string_of_type ty1);
       Debug.parser_emit stderr e;
       failwith "Type mismatch")

let string s = lexbuf stdout (Lexing.from_string s) (* 文字列をコンパイルして標準出力に表示する (caml2html: main_string) *)

let file f = (* ファイルをコンパイルしてファイルに出力する (caml2html: main_file) *)
  let inchan = open_in (f ^ ".ml") in
  let outchan = (match !debug_level with
		 | Debug.Emit -> open_out (f ^ ".s")
		 | _          -> open_out (f ^ ".out")) in
  try
    lexbuf outchan (Lexing.from_channel inchan);
    close_in inchan;
    close_out outchan;
  with e -> (close_in inchan; close_out outchan; raise e)

let () = (* ここからコンパイラの実行が開始される (caml2html: main_entry) *)
  let files = ref [] in
  Arg.parse
    [("-inline", Arg.Int(fun i -> Inline.threshold := i), "maximum size of functions inlined");
     ("-iter", Arg.Int(fun i -> limit := i), "maximum number of optimizations iterated");
     ("-debug", Arg.String(fun s -> debug_level := Debug.level_of_string s), "output level for debugging")]
    (fun s -> files := !files @ [s])
    ("Mitou Min-Caml Compiler (C) Eijiro Sumii\n" ^
     Printf.sprintf "usage: %s [-inline m] [-iter n] ...filenames without \".ml\"..." Sys.argv.(0));
  List.iter
    (fun f -> ignore (file f))
    !files
