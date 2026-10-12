#define _GNU_SOURCE
#include "moonbit.h"
#ifdef _WIN32
MOONBIT_FFI_EXPORT int
moonbit_moondesk_retained_read(moonbit_bytes_t root, moonbit_bytes_t relative,
                              moonbit_bytes_t output, int capacity) {
  (void)root; (void)relative; (void)output; (void)capacity;
  return -2;
}
#else
#include <fcntl.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include <errno.h>

#ifdef __APPLE__
#define st_mtim st_mtimespec
#define st_ctim st_ctimespec
#endif

/* Resolve the absolute trusted suite from an anchored root directory. Each
 * component is opened without following links, including suite ancestors. */
static int retained_root(const char *root) {
  if (!root || root[0] != '/') return -1;
  int dir = open("/", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
  if (dir < 0) return -1;
  if (!root[1]) return dir;
  char *name = strdup(root + 1);
  if (!name) { close(dir); return -1; }
  char *part = name;
  for (;;) {
    char *slash = strchr(part, '/');
    if (slash) *slash = '\0';
    if (!*part || !strcmp(part, ".") || !strcmp(part, "..")) {
      close(dir); dir = -1; break;
    }
    int next = openat(dir, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
    close(dir); dir = next;
    if (dir < 0 || !slash) break;
    part = slash + 1;
  }
  free(name);
  return dir;
}

/* A read-only bounded descriptor walk. O_NONBLOCK ensures a substituted FIFO
 * cannot hang the host. The file, length, inode and timestamps must remain
 * stable through the read and the directory entry must still identify it. */
MOONBIT_FFI_EXPORT int
moonbit_moondesk_retained_read(moonbit_bytes_t root, moonbit_bytes_t relative,
                              moonbit_bytes_t output, int capacity) {
  int dir = retained_root((const char *)root);
  if (dir < 0) return -1;
  char *name = strdup((const char *)relative);
  if (!name) { close(dir); return -1; }
  char *part = name;
  int file = -1;
  for (;;) {
    char *slash = strchr(part, '/');
    if (slash) *slash = '\0';
    if (!*part || !strcmp(part, ".") || !strcmp(part, "..")) break;
    if (slash) {
      int next = openat(dir, part, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC);
      if (next < 0) break;
      close(dir); dir = next; part = slash + 1;
    } else {
      file = openat(dir, part, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
      break;
    }
  }
  int size = 0, result = -1;
  struct stat before, after, entry;
  if (file < 0) goto done;
  if (fstat(file, &before) || !S_ISREG(before.st_mode) ||
      before.st_size < 0 || before.st_size >= capacity) goto done;
  while (size < capacity) {
    ssize_t count = read(file, output + size, capacity - size);
    if (count < 0 && errno == EINTR) continue;
    if (count < 0) goto done;
    if (!count) break;
    size += (int)count;
  }
  if (size >= capacity || fstat(file, &after) ||
      fstatat(dir, part, &entry, AT_SYMLINK_NOFOLLOW) || !S_ISREG(entry.st_mode) ||
      entry.st_dev != before.st_dev || entry.st_ino != before.st_ino ||
      before.st_dev != after.st_dev || before.st_ino != after.st_ino ||
      before.st_size != after.st_size || size != after.st_size ||
      before.st_mtim.tv_sec != after.st_mtim.tv_sec ||
      before.st_mtim.tv_nsec != after.st_mtim.tv_nsec ||
      before.st_ctim.tv_sec != after.st_ctim.tv_sec ||
      before.st_ctim.tv_nsec != after.st_ctim.tv_nsec) goto done;
  result = size;
done:
  if (file >= 0) close(file);
  free(name);
  close(dir);
  return result;
}
#endif
