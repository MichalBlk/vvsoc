#include "virtio.h"
#include "soc.h"

static __attribute__((__noreturn__)) void halt(void) {
  for (;;)
    continue;
}

static inline int vmgr_rd(int reg) {
  return *(volatile int *)(VMGR_START + reg);
}

static inline void vmgr_wr(int reg, int val) {
  *(volatile int *)(VMGR_START + reg) = val;
}

static inline int next_idx(int idx) {
  return (idx + 1) & (VCD_QUEUE_NUM_MAX - 1);
}

static void add_used(volatile virtqueue_t *vq, int didx, int len) {
  used_vring_t *uvr = vq->used;
  int uidx = uvr->idx;
  uvr->ring[uidx].idx = didx;
  uvr->ring[uidx].len = len;
  uvr->idx = next_idx(uidx);
}

static void handle_rx(void) {
  volatile virtqueue_t *vq = (virtqueue_t *)VCD_START;
  avail_vring_t *avr = vq->avail;
  int aidx = vq->last_aidx, didx = avr->ring[aidx];
  if (aidx == avr->idx || didx)
    halt();
  desc_t *d = vq->desc + didx;
  char *c = d->addr;
  int x = vmgr_rd(VMGR_REG_UART_RX);
  if (x == -1)
    halt();
  *c = x;
  add_used(vq, didx, 1);
  vq->last_aidx = next_idx(aidx);
}

static int handle_tx(void) {
  volatile virtqueue_t *vq = (virtqueue_t *)VCD_START + 1;
  avail_vring_t *avr = vq->avail;
  int aidx = vq->last_aidx, didx = avr->ring[aidx];
  if (aidx == avr->idx || didx)
    halt();
  desc_t *d = vq->desc + didx;
  char *c = d->addr;
  int len = d->len;
  if (!len)
    halt();
  for (int i = 0; i < len; i++)
    vmgr_wr(VMGR_REG_UART_TX, c[i]);
  add_used(vq, didx, len);
  vq->last_aidx = next_idx(aidx);
}

void __attribute__((__noreturn__)) process(int qn) {
  if (!qn)
    handle_rx();
  else if (qn == 1)
    handle_tx();
  else
    halt();
  vmgr_wr(VMGR_REG_FINISH, 0);
  __builtin_unreachable();
}
