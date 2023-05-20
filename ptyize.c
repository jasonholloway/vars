#define _XOPEN_SOURCE 700
#include <fcntl.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pty.h>
#include <unistd.h>
#include <errno.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <sys/select.h>

void fail(const char *, ...);
void runParent();
void pumpMaster();
void runChild();
void setupChild();

#define MAP_IN 1
#define MAP_OUT 2
#define MAP_ERR 4

int main(int argc, char *argv[]) {
  int i = 1, mapFlags = 0;
  char *f0 = "/dev/tty";
  char *f1 = "/dev/tty";

  for(; i < argc && argv[i][0] == '-'; i++) {
    if(argv[i][1] == 'i') {
      mapFlags |= MAP_IN;
    }
    if(argv[i][1] == 'o') {
      mapFlags |= MAP_OUT;
    }
    if(argv[i][1] == 'e') {
      mapFlags |= MAP_ERR;
    }
    if(argv[i][1] == '0') {
      f0 = argv[i] + 2;
    }
    if(argv[i][1] == '1') {
      f1 = argv[i] + 2;
    }
  }

  int j = 0;
  char *childArgv[256];
  for(; i < argc; i++, j++) {
    childArgv[j] = argv[i];
  }
  childArgv[j] = NULL;

  int mfd = open("/dev/ptmx", O_RDWR | O_NOCTTY); //poss non-blocking flag as well?
  if(mfd < 0) { fail("opening mfd %d", mfd); }

  if(grantpt(mfd) < 0) { fail("granting pts"); }
  if(unlockpt(mfd) < 0) { fail("unlocking pts"); }

  char *ptsn = ptsname(mfd);
  if(ptsn == NULL) fail("getting pts name from mfd %d", mfd);

  int sfd = open(ptsn, O_RDWR | O_NOCTTY);
  if(sfd < 0) fail("opening %s", ptsn);

  int pid;
  switch(pid = fork()) {
    case -1:
      _exit(1);
      return 1;

    case 0:
      runChild(mfd, sfd, mapFlags, childArgv);
      break;

    default:
      runParent(pid, f0, f1, mfd);
      break;
  }
}

void runParent(int childPid, char *f0, char *f1, int mfd) {
  int fd0 = open(f0, O_RDONLY | O_NOCTTY);
  if(fd0 < 0) fail("opening %s as fd0", f0);

  int fd1 = open(f1, O_WRONLY | O_NOCTTY);
  if(fd1 < 1) fail("opening %s as fd1", f1);
  
  pumpMaster(fd0, fd1, mfd);
}

void pumpMaster(int fd0, int fd1, int mfd) {
  // todo if we listen for writability as well,
  // we can effect a nice buffer here
  // but for now, let's go simple

  char buff[4096];
  
  fd_set rfds;

  FD_ZERO(&rfds);
  FD_SET(fd0, &rfds);
  FD_SET(mfd, &rfds);

  while(select(4096, &rfds, NULL, NULL, NULL) > 0) {

    if(FD_ISSET(fd0, &rfds)) {
      int c = read(fd0, buff, 4096);
      if(c < 0) fail("reading from fd0");
      
      int r = write(mfd, buff, c);
      if(r < 0) fail("writing to mfd");
    }

    if(FD_ISSET(mfd, &rfds)) {
      int c = read(mfd, buff, 4096);
      if(c < 0) fail("reading from mfd");
      
      int r = write(fd1, buff, c);
      if(r < 0) fail("writing to fd1");
    }
    
    FD_ZERO(&rfds);
    FD_SET(fd0, &rfds);
    FD_SET(mfd, &rfds);
  }
}



void runChild(int mfd, int sfd, int mapFlags, char *argv[]) {
  close(mfd);

  setupChild(sfd, mapFlags);

  if(argv[0] != NULL) {
    if(execv(argv[0], argv) < 0) fail("running cmd");
  }
}


void setupChild(int sfd, int mapFlags) {
  int sid = setsid();
  if(sid < 0) fail("putting child in new session");
  
  if(ioctl(sfd, TIOCSCTTY, 0) < 0) fail("setting controlling terminal to %d", sfd);

  if(mapFlags & MAP_IN) {
    if(dup2(sfd, 0) == -1) fail("updating STDIN");
  }
  if(mapFlags & MAP_OUT) {
    if(dup2(sfd, 1) == -1) fail("updating STDOUT");
  }
  if(mapFlags & MAP_ERR) {
    if(dup2(sfd, 2) == -1) fail("updating STDERR");
  }
}

void fail(const char *fmt, ...) {
  char buff[4096];
  va_list ap;

  va_start(ap, fmt);
  int n = vsnprintf(buff, 4096, fmt, ap);
  va_end(ap);
  
  fprintf(stderr, "Failed at %s: %s\n", buff, strerror(errno));
  exit(1);
}
