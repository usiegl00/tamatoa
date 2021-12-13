all: clean shellcheck tamatoa.bin test

clean:
	rm -f tamatoa.o tamatoa.bin

cleanup:
	rm -f macho tamatoa.o tamatoa.bin

shellcheck: shellcheck.c
	$(CC) -O3 -o $@ $<
	strip $@

#.SILENT: macho
macho:
	printf "#include <stdio.h>\nint main(int argc, const char *const argv[]) {printf(\"Hello, %%s: %%s\\\\n\", \"tamatoa\", argv[0]);}" | $(CC) -O3 -x c -o $@ -

tamatoa.bin: macho
ifeq ($(shell gem info ruby-macho -i), false)
	@printf "\033[0;31m[-]\033[0m Error: gem not installed: ruby-macho\n"
	@false
else
	ruby -- tamatoa.rb macho $(filter-out all,$(MAKECMDGOALS)) | $(CC) -nostartfiles -e _main -O3 -x assembler -o tamatoa.o -
	objdump -w -d tamatoa.o | cut -d ":" -f 2- | sed "s/^[[:space:]]*//" | grep -v ":" | cut -f -1 | grep -v "^$$" | tail -n +2 | xxd -r -p > $@
endif

test: shellcheck tamatoa.bin
	@printf "\033[0;32m[+]\033[0m Checking the shellcode...\n"
	./$< tamatoa.bin

%:
	@:
