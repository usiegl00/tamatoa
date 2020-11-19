all: clean shellcheck tamatoa.bin

clean:
	rm -f macho.s tamatoa.o tamatoa.bin

cleanup:
	rm -f macho macho.s tamatoa.o tamatoa.bin

shellcheck: shellcheck.c
	clang -O3 -o $@ $<
	strip $@

#.SILENT: macho
macho:
	printf '#include <stdio.h>\nint main() {printf("Hello, %%s.\\n", "tamatoa");}' | clang -O3 -x c -o $@ -
#printf "\033[0;31m[-]\033[0m Error: file not found: $@\n"
#false

tamatoa: tamatoa.s
	clang -O3 -o $@ $<
	strip $@

tamatoa.bin: tamatoa macho shellcheck
	./$<.rb $< macho > macho.s
	as macho.s -o $<.o
	otool -xX $<.o | cut -f 2 | xxd -r -p > $@
	@printf "\033[0;32m[+]\033[0m Checking the shellcode...\n"
	./shellcheck $@
