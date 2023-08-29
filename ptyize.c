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
void pumpMaster();
void runChild();
void setupChild();

#define FLAG_IN 1
#define FLAG_OUT 2
#define FLAG_ERR 4
#define FLAG_RAW 8

// idea: a ptyize server would receive commands via a socket, and fork out instances

int main(int argc, char *argv[]) {
  int i = 1, flags = 0;
  char *f0 = "/dev/tty";
  char *f1 = "/dev/tty";

  for(; i < argc && argv[i][0] == '-'; i++) {
    if(argv[i][1] == 'i') {
      flags |= FLAG_IN;
    }
    if(argv[i][1] == 'o' || isatty(1)) { // or if stdout is tty
      flags |= FLAG_OUT;
    }
    if(argv[i][1] == 'e') { //need to also default on if tty?
      flags |= FLAG_ERR;
    }
    if(argv[i][1] == '0') {
      f0 = argv[i] + 2;
    }
    if(argv[i][1] == '1') {
      f1 = argv[i] + 2;
    }
    if(argv[i][1] == 'r') {
      flags |= FLAG_RAW;
    }
  }

  int j = 0;
  char *childArgv[256];
  for(; i < argc; i++, j++) {
    childArgv[j] = argv[i];
  }
  childArgv[j] = NULL;

  int mfd = open("/dev/ptmx", O_RDWR | O_NOCTTY | O_NONBLOCK);
  if(mfd < 0) { fail("opening mfd %d", mfd); }

  if(grantpt(mfd) < 0) { fail("granting pts"); }
  if(unlockpt(mfd) < 0) { fail("unlocking pts"); }

  char *ptsn = ptsname(mfd);
  if(ptsn == NULL) fail("getting pts name from mfd %d", mfd);

  int sfd = open(ptsn, O_RDWR | O_NOCTTY);
  if(sfd < 0) fail("opening %s", ptsn);


  int ttyfd = open("/dev/tty", O_RDONLY | O_NOCTTY);

  struct winsize sz;
  if(ioctl(ttyfd, TIOCGWINSZ, &sz) < 0) fail("getting tty size");
  if(ioctl(mfd, TIOCSWINSZ, &sz) < 0) fail("setting pts size");
  
  struct termio tio;
  struct termio tio_orig;
  if(ioctl(ttyfd, TCGETA, &tio) < 0) fail("getting tty attrs");
  tio_orig = tio;

  if(flags & FLAG_RAW) {
    tio.c_oflag &= ~OPOST;
    tio.c_iflag &= ~(INLCR | ICRNL | ISTRIP | IXON | BRKINT);
    tio.c_lflag &= ~(ICANON | ECHO); // | ISIG);
    tio.c_cc[VMIN] = 1;
    tio.c_cc[VTIME] = 0;
  }

  if(ioctl(ttyfd, TCSETA, &tio) < 0) fail("setting tty attrs");

  int pid;
  switch(pid = fork()) {
    case -1:
      _exit(1);
      return 1;

    case 0:
      close(ttyfd);
      runChild(mfd, sfd, flags, childArgv);
      break;

    default:
      close(sfd);

      int fd0 = open(f0, O_RDONLY | O_NOCTTY);
      if(fd0 < 0) fail("opening %s as fd0", f0);

      int fd1 = open(f1, O_WRONLY | O_NOCTTY);
      if(fd1 < 1) fail("opening %s as fd1", f1);

      pumpMaster(fd0, fd1, mfd);

      if(ioctl(ttyfd, TCSETA, &tio_orig) < 0) fail("resetting tty attrs");
      close(ttyfd);
      break;
  }
}

/*
 *
 Need to auto-detect output as tty - if it isn't, then we defo don't want to redirect to tty
 but if it is, then it's going to be the wrong tty...
 TODO:
   if out is tty, then replace it with _our_ tty
 
 */

void pumpMaster(int fd0, int fd1, int mfd) {
  // todo if we listen for writability as well,
  // we can effect a nice buffer here
  // but for now, let's go simple

  char buff[4096];
  
  fd_set rfds;

  FD_ZERO(&rfds);
  FD_SET(fd0, &rfds);
  FD_SET(mfd, &rfds);

  FILE *logf = fopen("/tmp/ptyize.log", "a");

  while(select(1024, &rfds, NULL, NULL, NULL) > 0) {

    if(FD_ISSET(fd0, &rfds)) {
      int c = read(fd0, buff, 4096);
      if(c < 0) fail("reading from fd0");

      fwrite(buff, 1, c, logf);
      fwrite("\n", 1, 1, logf);
      fflush(logf);
      
      int r = write(mfd, buff, c);
      if(r < 0) {
        if(errno == EIO) break;
        if(errno != EAGAIN) fail("writing to mfd");
      }

      fsync(mfd);
    }

    if(FD_ISSET(mfd, &rfds)) {
      int c = read(mfd, buff, 4096);
      if(c < 0) {
        if(errno == EIO) break;
        if(errno != EAGAIN) fail("reading from mfd");
      }
      
      int r = write(fd1, buff, c);
      if(r < 0) fail("writing to fd1");
    }

    FD_ZERO(&rfds);
    FD_SET(fd0, &rfds);
    FD_SET(mfd, &rfds);
  }
}



void runChild(int mfd, int sfd, int flags, char *argv[]) {
  close(mfd);

  setupChild(sfd, flags);

  if(argv[0] != NULL) {
    if(execvp(argv[0], argv) < 0) fail("running cmd");
  }
}


void setupChild(int sfd, int flags) {
  int sid = setsid();
  if(sid < 0) fail("putting child in new session");
  
  if(ioctl(sfd, TIOCSCTTY, 0) < 0) fail("setting controlling terminal to %d", sfd);

  if(flags & FLAG_IN) {
    if(dup2(sfd, 0) == -1) fail("updating STDIN");
  }
  if(flags & FLAG_OUT) {
    if(dup2(sfd, 1) == -1) fail("updating STDOUT");
  }
  if(flags & FLAG_ERR) {
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
