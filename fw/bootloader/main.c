#include <soc.h>

static void copy(int src, int dst, int n) {
  volatile char *fl = (char *)src;
  volatile char *mmem = (char *)dst;
  for (int i = 0; i < n; i++)
    mmem[i] = fl[i];
}

void main(void) {
  copy(FL_OPENSBI_START, MMEM_OPENSBI_START, OPENSBI_SIZE);
  copy(FL_DTB_START, MMEM_DTB_START, DTB_SIZE);
  copy(FL_KERNEL_START, MMEM_KERNEL_START, KERNEL_SIZE);
  copy(FL_INITRD_START, MMEM_INITRD_START, INITRD_SIZE);

  void (*mmem_start)(int hartid, int dtb) = (void *)MMEM_OPENSBI_START;
  mmem_start(0, MMEM_DTB_START);

  for (;;)
    continue;
}
