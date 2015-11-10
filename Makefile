# Sumii's Makefile for Min-Caml (for GNU Make)
# 
# ack.ml�ʤɤΥƥ��ȥץ�����test/���Ѱդ���make do_test��¹Ԥ���ȡ�
# min-caml��ocaml�ǥ���ѥ��롦�¹Ԥ�����̤�ư����Ӥ��ޤ���

RESULT = min-caml
NCSUFFIX = .opt
CC = gcc
CFLAGS = -g -O2 -Wall

default: debug-code top $(RESULT) do_test
$(RESULT): debug-code top
## [��ʬ�ʽ�����Ѥ���]
## ��OCamlMakefile��Ť�GNU Make�ΥХ�(?)�Ǿ�Τ褦�������ɬ��(??)
## ��OCamlMakefile�Ǥ�debug-code��native-code�Τ��줾���
##   .mli������ѥ��뤵��Ƥ��ޤ��Τǡ�ξ���Ȥ�default:�α��դ�������
##   ��make���ˡ�.mli���ѹ�����Ƥ���Τǡ�.ml��ƥ���ѥ��뤵���
clean:: nobackup

# ���⤷�������¤�����顢����˹�碌���Ѥ���
# �ǥХå����ɲ� by nekketsuuu
SOURCES = float.c type.ml id.ml m.ml s.ml \
syntax.ml parser.mly lexer.mll typing.mli typing.ml kNormal.mli kNormal.ml \
alpha.mli alpha.ml beta.mli beta.ml assoc.mli assoc.ml \
inline.mli inline.ml constFold.mli constFold.ml elim.mli elim.ml \
closure.mli closure.ml asm.mli asm.ml virtual.mli virtual.ml \
simm.mli simm.ml regAlloc.mli regAlloc.ml emit.mli emit.ml \
debug.mli debug.ml debugAsm.mli debugAsm.ml \
main.mli main.ml

# ���ƥ��ȥץ���ब�������顢��������䤹
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

# �ǥХå��� by nekketsuuu
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

# raytracer�� by nekketsuuu
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
