#include <soc.h>

static void putc(char c) {
  volatile char *dbgc = (char *)DBGC_START;
  *dbgc = c;
}

static void puts(const char *s, int n) {
  for (int i = 0; i < n; i++)
    putc(s[i]);
  putc('\r');
  putc('\n');
}

#define PUTS(s) puts(s, sizeof(s))

static void copy(int src, int dst, int n) {
  volatile char *fl = (char *)src;
  volatile char *mmem = (char *)dst;
  for (int i = 0; i < n; i++)
    mmem[i] = fl[i];
}

void main(void) {
  PUTS("Loading OpenSBI...");
  copy(FL_OPENSBI_START, MMEM_OPENSBI_START, OPENSBI_SIZE);
  PUTS("Loading dtb...");
  copy(FL_DTB_START, MMEM_DTB_START, DTB_SIZE);
  PUTS("Loading kernel...");
  copy(FL_KERNEL_START, MMEM_KERNEL_START, KERNEL_SIZE);
  PUTS("Loading initrd...");
  copy(FL_INITRD_START, MMEM_INITRD_START, INITRD_SIZE);
  PUTS("Images loaded successfully");

  void (*mmem_start)(int hartid, int dtb) = (void *)MMEM_OPENSBI_START;
  mmem_start(0, MMEM_DTB_START);

  for (;;)
    continue;
}
