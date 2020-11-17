#include <sys/mman.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>

int main(int argc, char ** argv) {
  FILE * fi = fopen(argv[1], "rb");
  struct stat fs;
  unsigned char *mcc;

  fstat(fileno(fi), &fs);
  mcc = valloc(fs.st_size);
  fread(mcc, 1, fs.st_size, fi);
  fclose(fi);

  mprotect(mcc, fs.st_size, PROT_EXEC);

  int (*m)() = (int (*)())mcc;

  m();
  
  return 0;
}
