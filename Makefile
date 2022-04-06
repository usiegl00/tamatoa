all: clean shellcheck tamatoa.bin test

clean:
	rm -f tamatoa.o tamatoa.bin

cleanup:
	rm -f macho tamatoa.o tamatoa.bin

shellcheck: shellcheck.c
	$(CC) -O0 -o $@ $<
	#strip $@

#.SILENT: macho
macho:
	printf "#include <stdio.h>\nint main(int argc, const char *const argv[]) {printf(\"Hello, %%s: %%s\\\\n\", \"tamatoa\", argv[0]);}" | $(CC) -O3 -x c -o $@ -

fflush: fflush.c
	$(CC) -Os -o $@ $<
	strip $@

tamatoa.bin: macho fflush
ifeq ($(shell gem info ruby-macho -i), false)
	@printf "\033[0;31m[-]\033[0m Error: gem not installed: ruby-macho\n"
	@false
else
	ruby -- tamatoa.rb macho fflush macho $(filter-out all,$(MAKECMDGOALS)) | $(CC) -nostartfiles -e _main -O3 -x assembler -o tamatoa.o -
	objdump -w -d tamatoa.o | cut -d ":" -f 2- | sed "s/^[[:space:]]*//" | grep -v ":" | cut -f -1 | grep -v "^$$" | tail -n +2 | xxd -r -p > $@
endif

test: shellcheck tamatoa.bin
	@printf "\033[0;32m[+]\033[0m Checking the shellcode...\n"
	./$< tamatoa.bin

nofflush_tamatoa.bin: macho swift_c
ifeq ($(shell gem info ruby-macho -i), false)
  @printf "\033[0;31m[-]\033[0m Error: gem not installed: ruby-macho\n"
	@false
else
	ruby -- tamatoa.rb macho macho swift $(filter-out nofflush,$(MAKECMDGOALS)) | $(CC) -nostartfiles -e _main -O3 -x assembler -o tamatoa.o -
	objdump -w -d tamatoa.o | cut -d ":" -f 2- | sed "s/^[[:space:]]*//" | grep -v ":" | cut -f -1 | grep -v "^$$" | tail -n +2 | xxd -r -p > tamatoa.bin
endif

nofflush: nofflush_tamatoa.bin test

swift_c: swift.c
	$(CC) -Os -o swift swift.c

swift_tamatoa.bin: macho fflush swift_c
ifeq ($(shell gem info ruby-macho -i), false)
	@printf "\033[0;31m[-]\033[0m Error: gem not installed: ruby-macho\n"
	@false
else
	ruby -- tamatoa.rb macho fflush swift $(filter-out swift,$(MAKECMDGOALS)) | $(CC) -nostartfiles -e _main -O3 -x assembler -o tamatoa.o -
	objdump -w -d tamatoa.o | cut -d ":" -f 2- | sed "s/^[[:space:]]*//" | grep -v ":" | cut -f -1 | grep -v "^$$" | tail -n +2 | xxd -r -p > tamatoa.bin
endif

swift: swift_tamatoa.bin test

nofflush_noswift_tamatoa.bin: macho
ifeq ($(shell gem info ruby-macho -i), false)
	@printf "\033[0;31m[-]\033[0m Error: gem not installed: ruby-macho\n"
	@false
else
	ruby -- tamatoa.rb macho macho macho $(filter-out nofflush_noswift,$(MAKECMDGOALS)) | $(CC) -nostartfiles -e _main -O3 -x assembler -o tamatoa.o -
	objdump -w -d tamatoa.o | cut -d ":" -f 2- | sed "s/^[[:space:]]*//" | grep -v ":" | cut -f -1 | grep -v "^$$" | tail -n +2 | xxd -r -p > tamatoa.bin
endif

nofflush_noswift: nofflush_noswift_tamatoa.bin test

%:
	@:
