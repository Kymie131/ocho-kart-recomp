/*
 * ue3lzx - tiny shared library that decompresses the LZX blocks used by
 * Xbox 360 UE3 packages (ECompressionFlags 0x4 = COMPRESS_LZX, i.e.
 * XMemCompress "native" streams). Loaded by ue3_catalog.py through ctypes.
 *
 * The LZX decoder itself is libmspack's lzxd.c (LGPL-2.1), taken from the
 * vendored submodule external/rexglue-sdk/thirdparty/libmspack at build time.
 * Nothing from libmspack is copied into this repository.
 *
 * Build: tools/catalog/build.ps1 (Windows) or tools/catalog/build.sh.
 *
 * Stream layout (one UE3 compressed block = one XMem stream): a sequence of
 * frames, each prefixed by either
 *   0xFF, frame_size (u16 BE), block_size (u16 BE)   -> 5-byte header, or
 *   block_size (u16 BE)                              -> 2-byte header.
 * The payloads are concatenated and fed to lzxd with a 128 KiB window
 * (window_bits = 17) and no reset interval, which is what UE3 used.
 */

#include <stdlib.h>
#include <string.h>

#include "mspack.h"
#include "lzx.h"

#if defined(_WIN32)
#define UE3LZX_EXPORT __declspec(dllexport)
#else
#define UE3LZX_EXPORT __attribute__((visibility("default")))
#endif

struct mem_file {
  struct mspack_file base; /* never dereferenced by lzxd, only passed back */
  unsigned char* data;
  size_t length;
  size_t position;
};

static struct mspack_file* mem_open(struct mspack_system* self, const char* name, int mode) {
  (void)self; (void)name; (void)mode;
  return NULL;
}
static void mem_close(struct mspack_file* file) { (void)file; }
static int mem_read(struct mspack_file* file, void* buffer, int bytes) {
  struct mem_file* m = (struct mem_file*)file;
  size_t left = m->length - m->position;
  size_t n = (size_t)bytes < left ? (size_t)bytes : left;
  memcpy(buffer, m->data + m->position, n);
  m->position += n;
  return (int)n;
}
static int mem_write(struct mspack_file* file, void* buffer, int bytes) {
  struct mem_file* m = (struct mem_file*)file;
  size_t left = m->length - m->position;
  size_t n = (size_t)bytes < left ? (size_t)bytes : left;
  memcpy(m->data + m->position, buffer, n);
  m->position += n;
  return bytes;
}
static int mem_seek(struct mspack_file* file, off_t offset, int mode) {
  (void)file; (void)offset; (void)mode;
  return 0;
}
static off_t mem_tell(struct mspack_file* file) { return (off_t)((struct mem_file*)file)->position; }
static void mem_message(struct mspack_file* file, const char* format, ...) {
  (void)file; (void)format;
}
static void* mem_alloc(struct mspack_system* self, size_t bytes) {
  (void)self;
  return malloc(bytes);
}
static void mem_free(void* buffer) { free(buffer); }
static void mem_copy(void* src, void* dest, size_t bytes) { memcpy(dest, src, bytes); }

static struct mspack_system mem_system = {mem_open,  mem_close, mem_read,    mem_write,
                                          mem_seek,  mem_tell,  mem_message, mem_alloc,
                                          mem_free,  mem_copy,  NULL};

/*
 * Returns 0 on success, a libmspack MSPACK_ERR_* code on decode failure,
 * -1 on bad arguments / framing, -2 on allocation failure.
 */
UE3LZX_EXPORT int ue3_lzx_decompress(const unsigned char* in, int in_len, unsigned char* out,
                                     int out_len) {
  if (!in || !out || in_len <= 0 || out_len <= 0) return -1;

  unsigned char* payload = (unsigned char*)malloc((size_t)in_len);
  if (!payload) return -2;
  int payload_len = 0;
  int pos = 0;
  while (pos + 2 <= in_len) {
    int block_size;
    if (in[pos] == 0xFF) {
      if (pos + 5 > in_len) break;
      block_size = (in[pos + 3] << 8) | in[pos + 4];
      pos += 5;
    } else {
      block_size = (in[pos] << 8) | in[pos + 1];
      pos += 2;
    }
    if (block_size == 0 || pos + block_size > in_len) break;
    memcpy(payload + payload_len, in + pos, (size_t)block_size);
    payload_len += block_size;
    pos += block_size;
  }
  if (payload_len == 0) {
    free(payload);
    return -1;
  }

  struct mem_file src = {{0}, payload, (size_t)payload_len, 0};
  struct mem_file dst = {{0}, out, (size_t)out_len, 0};
  struct lzxd_stream* lzx = lzxd_init(&mem_system, (struct mspack_file*)&src,
                                      (struct mspack_file*)&dst, 17, 0, 256 * 1024,
                                      (off_t)out_len, 0);
  if (!lzx) {
    free(payload);
    return -2;
  }
  int result = lzxd_decompress(lzx, (off_t)out_len);
  lzxd_free(lzx);
  free(payload);
  return result;
}
