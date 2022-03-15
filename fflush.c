//#include <errno.h>
#include <stdio.h>
//#include "local.h"
/*void flushz() {
  fflush(0);
}*/

/*
void flushs() {
  fflush(__stdoutp);
}
*/

int main() {
  fflush(__stdoutp);
  return 0;
}

/*
int main() {
  printf("hi, %llu : ", __stdoutp);
  fflush(__stdoutp);
  printf("hi, %llu", stdout);
  fflush(stdout);
  return 0;
}
*/
