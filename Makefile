# Sumii's Makefile for Min-Caml (for GNU Make)
# 
# ack.mlなどのテストプログラムをtest/に用意してmake do_testを実行すると、
# min-camlとocamlでコンパイル・実行した結果を自動で比較します。

RESULT = min-caml
NCSUFFIX = .opt
CC = gcc
CFLAGS = -g -O2 -Wall

default: debug-code top $(RESULT) do_test
$(RESULT): debug-code top
## [自分（住井）用の注]
## ・OCamlMakefileや古いGNU Makeのバグ(?)で上のような定義が必要(??)
## ・OCamlMakefileではdebug-codeとnative-codeのそれぞれで
##   .mliがコンパイルされてしまうので、両方ともdefault:の右辺に入れると
##   再make時に（.mliが変更されているので）.mlも再コンパイルされる
clean:: nobackup

# ↓もし実装を改造したら、それに合わせて変える
# デバッグ用追加 by nekketsuuu
SOURCES = float.c type.ml id.ml m.ml s.ml \
syntax.ml parser.mly lexer.mll typing.mli typing.ml kNormal.mli kNormal.ml \
alpha.mli alpha.ml beta.mli beta.ml assoc.mli assoc.ml \
inline.mli inline.ml constFold.mli constFold.ml elim.mli elim.ml \
closure.mli closure.ml asm.mli asm.ml virtual.mli virtual.ml \
simm.mli simm.ml regAlloc.mli regAlloc.ml emit.mli emit.ml \
debug.mli debug.ml debugAsm.mli debugAsm.ml \
main.mli main.ml

# ↓テストプログラムが増えたら、これも増やす
TESTS = print sum-tail gcd sum fib ack even-odd \
adder funcomp cls-rec cls-bug cls-bug2 \
shuffle spill spill2 spill3 join-stack join-stack2 join-stack3 \
join-reg join-reg2 non-tail-if non-tail-if2 \
inprod inprod-rec inprod-loop matmul matmul-flat \
muldiv float array read fb

do_test: $(TESTS:%=test/%.cmp)

.PRECIOUS: test/%.s test/% test/%.res test/%.ans test/%.cmp test/%.out
TRASH = $(TESTS:%=test/%.s) $(TESTS:%=test/%) $(TESTS:%=test/%.res) $(TESTS:%=test/%.ans) $(TESTS:%=test/%.cmp) $(TESTS:%=test/%.out) $(TESTS:%=test/%.cat.ml) $(TESTS:%=test/%.cat.out) $(TESTS:%=test/%.cat.s) test/*.hex test/*.bin 

test/%.s: $(RESULT) test/%.ml
	./$(RESULT) test/$*
test/%: test/%.s libmincaml.S stub.c
	$(CC) $(CFLAGS) -m32 $^ -lm -o $@
test/%.res: test/%
	$< > $@
test/%.ans: test/%.ml
	ocaml $< > $@
test/%.cmp: test/%.res test/%.ans
	diff $^ > $@

# デバッグ用 by nekketsuuu
# usage: make debug LEVEL=Parser
INLINE = 20
LEVEL = Asm

.PHONY: debug
debug: del_debug $(TESTS:%=test/%.out)

test/%.out: $(RESULT) test/%.ml libminrt.ml.head
	@cat libminrt.ml.head test/$*.ml > test/$*.cat.ml
	./$(RESULT) -inline $(INLINE) -debug $(LEVEL) test/$*.cat

.PHONY: del_debug
del_debug:
	rm -f test/*.out

.PHONY: debuglist
debuglist:
	@echo "LEVEL=Parser, Typing, KNormal, Alpha, Iter, Closure, Virtual, Simm, RegAlloc, Emit"

.PHONY: arcturu
arcturu:
	sed -i.backup -e "s/\(Format\.eprintf.*free.*\)$$/(\* \1 \*)/g" typing.ml

# raytracer用 by nekketsuuu
HEADERS = raytracer/globals.ml.head libminrt.ml.head

raytracer: $(RESULT) raytracer/min-rt.ml $(HEADERS) del_raytracer
	@cat $(HEADERS) raytracer/min-rt.ml > raytracer/min-rt.cat.ml
	./$(RESULT) -inline $(INLINE) -debug $(LEVEL) raytracer/min-rt.cat

.PHONY: del_raytracer
del_raytracer:
	rm -f raytracer/min-rt.cat.ml

# html
min-caml.html: main.mli main.ml id.ml m.ml s.ml \
		syntax.ml type.ml parser.mly lexer.mll typing.mli typing.ml kNormal.mli kNormal.ml \
		alpha.mli alpha.ml beta.mli beta.ml assoc.mli assoc.ml \
		inline.mli inline.ml constFold.mli constFold.ml elim.mli elim.ml \
		closure.mli closure.ml asm.mli asm.ml virtual.mli virtual.ml \
		simm.mli simm.ml regAlloc.mli regAlloc.ml emit.mli emit.ml
	./to_sparc
	caml2html -o min-caml.html $^
	sed 's/.*<\/title>/MinCaml Source Code<\/title>/g' < min-caml.html > min-caml.tmp.html
	mv min-caml.tmp.html min-caml.html
	sed 's/charset=iso-8859-1/charset=euc-jp/g' < min-caml.html > min-caml.tmp.html
	mv min-caml.tmp.html min-caml.html
	ocaml str.cma anchor.ml < min-caml.html > min-caml.tmp.html
	mv min-caml.tmp.html min-caml.html

release: min-caml.html
	rm -fr tmp ; mkdir tmp ; cd tmp ; cvs -d:ext:sumii@min-caml.cvs.sf.net://cvsroot/min-caml export -Dtomorrow min-caml ; tar cvzf ../min-caml.tar.gz min-caml ; cd .. ; rm -fr tmp
	cp Makefile stub.c SPARC/libmincaml.S min-caml.html min-caml.tar.gz ../htdocs/

include OCamlMakefile
