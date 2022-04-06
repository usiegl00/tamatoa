#include <sys/mman.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

void breaker() {
}

int main(int argc, char ** argv) {
  FILE * fi = fopen(argv[1], "rb");
  struct stat fs;
  unsigned char *mcc;
  unsigned char *mcm;

  fstat(fileno(fi), &fs);
  mcc = valloc(fs.st_size);
  fread(mcc, 1, fs.st_size, fi);
  fclose(fi);

  mcm = mmap(0, fs.st_size, PROT_WRITE, MAP_SHARED|MAP_ANONYMOUS, -1, 0);

  memcpy(mcm, mcc, fs.st_size);

  free(mcc);

  mprotect(mcm, fs.st_size, PROT_EXEC);

  unsigned long int (*m)() = (unsigned long int (*)())mcm;

  breaker();
  m();
  
  return 0;
}
