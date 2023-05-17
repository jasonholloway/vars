#include <stddef.h>
#include <stdio.h>
#include <pty.h>
#include <unistd.h>
#include <errno.h>

void runParent();
void runChild();

int main(int argc, char *argv[]) {

  char *childArgv[256];
  int i = 1;
  for(; i < 255; i++) { childArgv[i - 1] = argv[i]; }
  childArgv[i] = NULL;

  int pid, ptmx;
  switch(pid = forkpty(&ptmx, NULL, NULL, NULL)) {
    case -1:
      _exit(1);
      return 1;

    case 0:
      runChild(childArgv);
      break;

    default:
      runParent(pid, ptmx);
      break;
  }
}

// should take fifos to pump to/from
void runParent(int childPid, int fd) {
  // should use read/write below instead of streams

  FILE *f0 = fdopen(fd, "r");
  if(!f0) { fprintf(stderr, "Failed to open fd %d, due to: %d", fd, errno); }

  FILE *f1 = fdopen(fd, "w");
  if(!f1) { fprintf(stderr, "Failed to open fd %d, due to: %d", fd, errno); }

  //set up select here with fifos

  fprintf(f1, "oink!!!!\n");
  fsync(fd);

  char buff[1024];
  while(fread(buff, 1, 256, f0) > 0) {
    buff[16] = 0;
    printf("%s", buff);
  }
}

void runChild(char *argv[]) {
  if(argv[0] != NULL) {
    if(execv(argv[0], argv) < 0) {
      fprintf(stderr, "howl %d\n", errno);
    }
  }
}

// could all runs be be done here?
// and all outputs go via here too?
// instead of having io as a separate perl module
// distant from executions

