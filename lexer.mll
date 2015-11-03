{
(* lexer�����Ѥ����ѿ����ؿ������ʤɤ���� *)
open Parser
open Type
}

(* ����ɽ����ά�� *)
let space = [' ' '\t' '\r']
let digit = ['0'-'9']
let lower = ['a'-'z']
let upper = ['A'-'Z']

rule token = parse
| '\n'
    { Lexing.new_line lexbuf;
      token lexbuf }
| space+
    { token lexbuf }
| "(*"
    { comment lexbuf; (* �ͥ��Ȥ��������ȤΤ���Υȥ�å� *)
      token lexbuf }
| '('
    { LPAREN(lexbuf.Lexing.lex_curr_p) }
| ')'
    { RPAREN(lexbuf.Lexing.lex_curr_p) }
| "true"
    { BOOL(true, lexbuf.Lexing.lex_curr_p) }
| "false"
    { BOOL(false, lexbuf.Lexing.lex_curr_p) }
| "not"
    { NOT(lexbuf.Lexing.lex_curr_p) }
| digit+ (* �����������Ϥ���롼�� (caml2html: lexer_int) *)
    { INT(int_of_string (Lexing.lexeme lexbuf), lexbuf.Lexing.lex_curr_p) }
| digit+ ('.' digit*)? (['e' 'E'] ['+' '-']? digit+)?
    { FLOAT(float_of_string (Lexing.lexeme lexbuf), lexbuf.Lexing.lex_curr_p) }
| '-' (* -.����󤷤ˤ��ʤ��Ƥ��ɤ�? ��Ĺ����? *)
    { MINUS(lexbuf.Lexing.lex_curr_p) }
| '+' (* +.����󤷤ˤ��ʤ��Ƥ��ɤ�? ��Ĺ����? *)
    { PLUS(lexbuf.Lexing.lex_curr_p) }
| '*'
    { AST(lexbuf.Lexing.lex_curr_p) }
| '/'
    { SLASH(lexbuf.Lexing.lex_curr_p) }
| "-."
    { MINUS_DOT(lexbuf.Lexing.lex_curr_p) }
| "+."
    { PLUS_DOT(lexbuf.Lexing.lex_curr_p) }
| "*."
    { AST_DOT(lexbuf.Lexing.lex_curr_p) }
| "/."
    { SLASH_DOT(lexbuf.Lexing.lex_curr_p) }
| '='
    { EQUAL(lexbuf.Lexing.lex_curr_p) }
| "<>"
    { LESS_GREATER(lexbuf.Lexing.lex_curr_p) }
| "<="
    { LESS_EQUAL(lexbuf.Lexing.lex_curr_p) }
| ">="
    { GREATER_EQUAL(lexbuf.Lexing.lex_curr_p) }
| '<'
    { LESS(lexbuf.Lexing.lex_curr_p) }
| '>'
    { GREATER(lexbuf.Lexing.lex_curr_p) }
| "if"
    { IF(lexbuf.Lexing.lex_curr_p) }
| "then"
    { THEN(lexbuf.Lexing.lex_curr_p) }
| "else"
    { ELSE(lexbuf.Lexing.lex_curr_p) }
| "let"
    { LET(lexbuf.Lexing.lex_curr_p) }
| "in"
    { IN(lexbuf.Lexing.lex_curr_p) }
| "rec"
    { REC(lexbuf.Lexing.lex_curr_p) }
| ','
    { COMMA(lexbuf.Lexing.lex_curr_p) }
| '_'
    { IDENT(Id.gentmp Type.Unit, lexbuf.Lexing.lex_curr_p) }
| "Array.create" (* [XX] ad hoc *)
| "create_array"
    { ARRAY_CREATE(lexbuf.Lexing.lex_curr_p) }
| '.'
    { DOT(lexbuf.Lexing.lex_curr_p) }
| "<-"
    { LESS_MINUS(lexbuf.Lexing.lex_curr_p) }
| ';'
    { SEMICOLON(lexbuf.Lexing.lex_curr_p) }
| eof
    { EOF(lexbuf.Lexing.lex_curr_p) }
| lower (digit|lower|upper|'_')* (* ¾�Ρ�ͽ���פ���Ǥʤ��Ȥ����ʤ� *)
    { IDENT(Lexing.lexeme lexbuf, lexbuf.Lexing.lex_curr_p) }
| _
    { failwith
	(Printf.sprintf "unknown token %s near line %d characters %d-%d"
	   (Lexing.lexeme lexbuf)
	   lexbuf.Lexing.lex_curr_p.Lexing.pos_lnum
	   ((Lexing.lexeme_start lexbuf) - lexbuf.Lexing.lex_curr_p.Lexing.pos_bol)
	   ((Lexing.lexeme_end lexbuf) - lexbuf.Lexing.lex_curr_p.Lexing.pos_bol)) }
and comment = parse
| '\n'
    { Lexing.new_line lexbuf;
      comment lexbuf }
| "*)"
    { () }
| "(*"
    { comment lexbuf;
      comment lexbuf }
| eof
    { Format.eprintf "warning: unterminated comment at %d@." lexbuf.Lexing.lex_curr_p.Lexing.pos_lnum }
| _
    { comment lexbuf }
