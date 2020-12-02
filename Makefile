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
	printf "#include <stdio.h>\nint main() {printf(\"Hello, %%s.\\\\n\", \"tamatoa\");}" | clang -O3 -x c -o $@ -

tamatoa: tamatoa.s macho
ifeq ($(shell gem info ruby-macho -i), false)
	@printf "\033[0;31m[-]\033[0m Error: gem not installed: ruby-macho\n"
	@false
else
	sed s/MACHOENTRY/$(shell ruby -rmacho -e 'print (MachO::MachOFile.new("macho").load_commands.select {|l|l.class == MachO::LoadCommands::EntryPointCommand}[0].entryoff.to_s(16))')/g $< > macho.s
	clang -O3 -o $@ macho.s
	strip $@
	strip -A $@
endif

tamatoa.bin: tamatoa shellcheck
	ruby $<.rb $< macho > macho.s
	as macho.s -o $<.o
	otool -xX $<.o | cut -f 2 | xxd -r -p > $@
	@printf "\033[0;32m[+]\033[0m Checking the shellcode...\n"
	./shellcheck $@
