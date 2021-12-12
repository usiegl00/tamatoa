all: clean shellcheck tamatoa.bin

clean:
	rm -f tamatoa.o tamatoa.bin

cleanup:
	rm -f macho tamatoa.o tamatoa.bin

shellcheck: shellcheck.c
	clang -O3 -o $@ $<
	strip $@

#.SILENT: macho
macho:
	printf "#include <stdio.h>\nint main(int argc, const char *const argv[]) {printf(\"Hello, %%s: %%s\\\\n\", \"tamatoa\", argv[0]);}" | clang -O3 -x c -o $@ -

tamatoa.bin: macho shellcheck
ifeq ($(shell gem info ruby-macho -i), false)
	@printf "\033[0;31m[-]\033[0m Error: gem not installed: ruby-macho\n"
	@false
else
	ruby -- tamatoa.rb macho $(filter-out all,$(MAKECMDGOALS)) | clang -O3 -x assembler -o tamatoa.o -
	otool -xX tamatoa.o | cut -d " " -f 2- | xxd -r -p > $@
	@printf "\033[0;32m[+]\033[0m Checking the shellcode...\n"
	./shellcheck $@
endif

%:
	@:
