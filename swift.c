#import <crt_externs.h>

int main(int argc, char * * argv) {
  int * nsargcp = _NSGetArgc();
  *nsargcp = argc;
  char * * * nsargvp = _NSGetArgv();
  *nsargvp = argv;
  return 0;
}
