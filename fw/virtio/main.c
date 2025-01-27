#include "virtio.h"
#include "soc.h"

static __attribute__((__noreturn__)) void halt(void) {
  for (;;)
    continue;
}

static inline int mod(int x) {
  return x & (VCD_QUEUE_NUM_MAX - 1);
}

static inline int vmgr_rd(int reg) {
  return *(volatile int *)(VMGR_START + reg);
}

static inline void vmgr_wr(int reg, int val) {
  *(volatile int *)(VMGR_START + reg) = val;
}

static void add_used(volatile virtqueue_t *vq, int didx, int len) {
  used_vring_t *uvr = vq->used;
  int uidx = uvr->idx;
  uvr->ring[mod(uidx)].idx = didx;
  uvr->ring[mod(uidx)].len = len;
  uvr->idx++;
}

static int handle_rx(void) {
  volatile virtqueue_t *vq = (virtqueue_t *)VCD_START;
  avail_vring_t *avr = vq->avail;
  int aidx = vq->last_aidx;
  if (aidx == avr->idx)
    return VMGR_FINISH_FAILURE;
  int didx = avr->ring[mod(aidx)];
  desc_t *d = vq->desc + didx;
  char *c = d->addr;
  int x = vmgr_rd(VMGR_REG_UART_RX);
  if (x == -1)
    halt();
  *c = x;
  add_used(vq, didx, 1);
  vq->last_aidx++;
  return VMGR_FINISH_SUCCESS;
}

static int handle_tx(void) {
  volatile virtqueue_t *vq = (virtqueue_t *)VCD_START + 1;
  avail_vring_t *avr = vq->avail;
  int aidx = vq->last_aidx;
  if (aidx == avr->idx)
    return VMGR_FINISH_FAILURE;
  int didx = avr->ring[mod(aidx)];
  desc_t *d = vq->desc + didx;
  char *c = d->addr;
  int len = d->len;
  if (!len)
    halt();
  for (int i = 0; i < len; i++)
    vmgr_wr(VMGR_REG_UART_TX, c[i]);
  add_used(vq, didx, len);
  vq->last_aidx++;
  return VMGR_FINISH_SUCCESS;
}

void __attribute__((__noreturn__)) process(int qn) {
  int rv;
  if (!qn)
    rv = handle_rx();
  else if (qn == 1)
    rv = handle_tx();
  else
    halt();
  vmgr_wr(VMGR_REG_FINISH, rv);
  __builtin_unreachable();
}
