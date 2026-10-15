#define _GNU_SOURCE
#include "moonbit.h"
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <signal.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/wait.h>
#include <unistd.h>
#ifdef __APPLE__
#include <util.h>
#else
#include <pty.h>
#endif

/* The reader is independent of HTTP clients, so a build keeps running when
 * its book is not selected. Only C-owned memory is touched on this thread. */
#define SCROLLBACK (2 * 1024 * 1024)
typedef struct {
  int fd, status, stopping, started;
  pid_t pid;
  pthread_t reader;
  pthread_mutex_t lock;
  unsigned char *output;
  int length;
  int64_t offset;
} DeskPty;

static void *read_loop(void *value) {
  DeskPty *p = value;
  unsigned char chunk[16384];
  for (;;) {
    pthread_mutex_lock(&p->lock);
    int stopping = p->stopping;
    pthread_mutex_unlock(&p->lock);
    if (stopping) break;
    struct pollfd pollfd = {p->fd, POLLIN, 0};
    int ready = poll(&pollfd, 1, 50);
    if (ready < 0 && errno == EINTR) continue;
    if (ready < 0) break;
    if (ready == 0) continue;
    ssize_t n = read(p->fd, chunk, sizeof(chunk));
    if (n < 0 && (errno == EAGAIN || errno == EINTR)) continue;
    if (n <= 0) break;
    pthread_mutex_lock(&p->lock);
    int discard = p->length + (int)n - SCROLLBACK;
    if (discard > 0) {
      memmove(p->output, p->output + discard, p->length - discard);
      p->length -= discard;
      p->offset += discard;
    }
    memcpy(p->output + p->length, chunk, n);
    p->length += (int)n;
    pthread_mutex_unlock(&p->lock);
  }
  for (;;) {
    int status = 0;
    pthread_mutex_lock(&p->lock);
    pid_t result = waitpid(p->pid, &status, WNOHANG);
    if (result == p->pid || (result < 0 && errno != EINTR)) {
      p->status = result == p->pid
        ? (WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status)) : 0;
      pthread_mutex_unlock(&p->lock);
      break;
    }
    pthread_mutex_unlock(&p->lock);
    poll(NULL, 0, 20);
  }
  return NULL;
}

MOONBIT_FFI_EXPORT void moondesk_pty_close(DeskPty *p) {
  if (!p->started) return;
  pthread_mutex_lock(&p->lock);
  p->stopping = 1;
  if (p->status == -1) {
    pid_t foreground = tcgetpgrp(p->fd);
    if (foreground > 0) kill(-foreground, SIGHUP);
    kill(-p->pid, SIGHUP);
    kill(p->pid, SIGKILL);
  }
  pthread_mutex_unlock(&p->lock);
  pthread_join(p->reader, NULL);
  close(p->fd);
  p->fd = -1;
  p->started = 0;
}

static void destroy_pty(void *value) {
  DeskPty *p = value;
  moondesk_pty_close(p);
  pthread_mutex_destroy(&p->lock);
  free(p->output);
}

MOONBIT_FFI_EXPORT DeskPty *moondesk_pty_open(moonbit_bytes_t directory, int columns, int rows) {
  DeskPty *p = moonbit_make_external_object(destroy_pty, sizeof(DeskPty));
  memset(p, 0, sizeof(*p));
  p->fd = -1;
  p->status = -2;
  pthread_mutex_init(&p->lock, NULL);
  p->output = malloc(SCROLLBACK);
  if (!p->output) return p;
  const char *configured = getenv("SHELL");
  char *shell = strdup(configured && configured[0] == '/' ? configured : "/bin/sh");
  struct winsize size = { .ws_row = rows > 0 ? rows : 30, .ws_col = columns > 0 ? columns : 100 };
  p->pid = forkpty(&p->fd, NULL, NULL, &size);
  if (p->pid == 0) {
    if (chdir((char *)directory) != 0) _exit(126);
    setenv("TERM", "xterm-256color", 1);
    setenv("COLORTERM", "truecolor", 1);
    execl(shell, shell, "-l", "-i", (char *)NULL);
    _exit(127);
  }
  free(shell);
  if (p->pid < 0) return p;
  fcntl(p->fd, F_SETFL, fcntl(p->fd, F_GETFL) | O_NONBLOCK);
  fcntl(p->fd, F_SETFD, FD_CLOEXEC);
  p->status = -1;
  if (pthread_create(&p->reader, NULL, read_loop, p) != 0) {
    kill(-p->pid, SIGHUP);
    kill(p->pid, SIGKILL);
    waitpid(p->pid, NULL, 0);
    close(p->fd);
    p->fd = -1;
    p->status = -2;
  } else p->started = 1;
  return p;
}

MOONBIT_FFI_EXPORT int moondesk_pty_status(DeskPty *p) {
  pthread_mutex_lock(&p->lock);
  int status = p->status;
  pthread_mutex_unlock(&p->lock);
  return status;
}

MOONBIT_FFI_EXPORT moonbit_bytes_t moondesk_pty_read(DeskPty *p, int64_t *cursor) {
  pthread_mutex_lock(&p->lock);
  int64_t start = cursor[0] < p->offset ? p->offset : cursor[0];
  if (start > p->offset + p->length) start = p->offset + p->length;
  int count = p->offset + p->length - start;
  if (count > 65536) count = 65536;
  moonbit_bytes_t result = moonbit_make_bytes(count, 0);
  if (count) memcpy(result, p->output + start - p->offset, count);
  cursor[0] = start;
  cursor[1] = start + count;
  pthread_mutex_unlock(&p->lock);
  return result;
}

MOONBIT_FFI_EXPORT int moondesk_pty_write(DeskPty *p, moonbit_bytes_t data) {
  if (!p->started) return -1;
  ssize_t count = write(p->fd, data, Moonbit_array_length(data));
  return count < 0 && (errno == EAGAIN || errno == EINTR) ? 0 : (int)count;
}

MOONBIT_FFI_EXPORT int moondesk_pty_resize(DeskPty *p, int columns, int rows) {
  if (!p->started || columns < 1 || rows < 1) return -1;
  struct winsize size = { .ws_row = rows, .ws_col = columns };
  return ioctl(p->fd, TIOCSWINSZ, &size);
}
