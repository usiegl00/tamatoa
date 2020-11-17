CFLAGS=-fno-stack-protector -fomit-frame-pointer -fno-exceptions -fPIC -Os -O0
GCC_BIN_OSX=`xcrun --sdk macosx -f gcc`
GCC_BASE_OSX=$(GCC_BIN_OSX) $(CFLAGS)
GCC_OSX=$(GCC_BASE_OSX) -arch x86_64

all: clean shellcheck tamatoa.bin

clean:
	rm -f tamatoa.s tamatoa.o tamatoa.bin

cleanup:
	rm -f shellcheck macho tamatoa.s tamatoa.o tamatoa.bin

shellcheck: shellcheck.c
	clang -O3 -o $@ $<
	strip $@

#.SILENT: macho
macho:
	printf '#include <stdio.h>\nint main() {printf("Hello, %%s.\\n", "tamatoa");}' | clang -O3 -x c -o $@ -
#printf "\033[0;31m[-]\033[0m Error: file not found: $@\n"
#false

tamatoa: tamatoa.c
	$(GCC_OSX) -o $@ $@.c
	strip $@

tamatoa.bin: tamatoa macho shellcheck
	./$<.rb $< macho > $<.s
	as $<.s -o $<.o
	otool -xX $<.o | cut -f 2 | xxd -r -p > $@
	@printf "\033[0;32m[+]\033[0m Checking the shellcode...\n"
	./shellcheck $@
