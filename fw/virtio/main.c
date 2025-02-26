#include <virtio.h>
#include <virtio_gpu.h>
#include <soc.h>

/*
 * Common procedures
 */
static __attribute__((__noreturn__)) void halt(void) {
  for (;;)
    continue;
}

static inline int mod(int x, int mx) {
  return x & (mx - 1);
}

static inline int vmgr_rd(int reg) {
  return *(volatile int *)(VMGR_START + reg);
}

static inline void vmgr_wr(int reg, int val) {
  *(volatile int *)(VMGR_START + reg) = val;
}

static void add_used(volatile virtqueue_t *vq, int didx, int len, int (*mod)(int)) {
  used_vring_t *uvr = vq->used;
  int uidx = uvr->idx;
  uvr->ring[mod(uidx)].idx = didx;
  uvr->ring[mod(uidx)].len = len;
  uvr->idx++;
}

/*
 * VirtIO console device
 */
static inline int vcd_mod(int x) {
  return mod(x, VCD_QUEUE_NUM_MAX);
}

static void vcd_add_used(volatile virtqueue_t *vq, int didx, int len) {
  add_used(vq, didx, len, vcd_mod);
}

static int vcd_handle_rx(void) {
  volatile virtqueue_t *vq = (virtqueue_t *)VCD_START;
  avail_vring_t *avr = vq->avail;
  int aidx = vq->last_aidx;
  if (aidx == avr->idx)
    return VMGR_FINISH_FAILURE;
  int didx = avr->ring[vcd_mod(aidx)], len = 0;
  desc_t *d = vq->desc + didx;
  char *c = d->addr;
  for (;; len++, c++) {
    int x = vmgr_rd(VMGR_REG_UART_RX);
    if (x == -1)
      break;
    *c = x;
  }
  if (!len)
    halt();
  vcd_add_used(vq, didx, len);
  vq->last_aidx++;
  return VMGR_FINISH_SUCCESS;
}

static int vcd_handle_tx(void) {
  volatile virtqueue_t *vq = (virtqueue_t *)VCD_START + 1;
  avail_vring_t *avr = vq->avail;
  int aidx = vq->last_aidx;
  if (aidx == avr->idx)
    return VMGR_FINISH_FAILURE;
  int didx = avr->ring[vcd_mod(aidx)];
  desc_t *d = vq->desc + didx;
  char *c = d->addr;
  int len = d->len;
  if (!len)
    halt();
  for (int i = 0; i < len; i++)
    vmgr_wr(VMGR_REG_UART_TX, c[i]);
  vcd_add_used(vq, didx, len);
  vq->last_aidx++;
  return VMGR_FINISH_SUCCESS;
}

/*
 * VirtIO GPU device
 */
#define VGD_MAX_MEM_ENT_NUM 4

typedef struct {
  uint32_t addr;
  uint32_t len;
} mem_ent_t;

static mem_ent_t ment[VGD_MAX_MEM_ENT_NUM];
static int ment_cnt;

static inline int vgd_mod(int x) {
  return mod(x, VGD_QUEUE_NUM_MAX);
}

static void vgd_add_used(volatile virtqueue_t *vq, int didx, int len) {
  add_used(vq, didx, len, vgd_mod);
}

static int vgd_handle_ctrl(void) {
  volatile virtqueue_t *vq = (virtqueue_t *)VGD_START;
  avail_vring_t *avr = vq->avail;
  int aidx = vq->last_aidx;
  if (aidx == avr->idx)
    return VMGR_FINISH_FAILURE;
  int didx = avr->ring[vgd_mod(aidx)];
  desc_t *c_d = vq->desc + didx, *r_d = vq->desc + c_d->next;
  virtio_gpu_ctrl_hdr_t *c_hdr = c_d->addr;
  if (c_hdr->type == VIRTIO_GPU_CMD_GET_DISPLAY_INFO) {
    virtio_gpu_resp_display_info_t *r = r_d->addr;
    r->hdr.type = VIRTIO_GPU_RESP_OK_DISPLAY_INFO;
    r->pmodes[0].r = (virtio_gpu_rect_t){0, 0, VGA_WIDTH, VGA_HEIGHT};
    r->pmodes[0].enabled = 1;
    r->pmodes[0].flags = 0;
    for (int i = 1; i < VIRTIO_GPU_MAX_SCANOUTS; i++)
      r->pmodes[i].enabled = 0;
    vgd_add_used(vq, didx, sizeof(*r));
  } else if (c_hdr->type == VIRTIO_GPU_CMD_RESOURCE_ATTACH_BACKING) {
    desc_t *d_d = r_d;
    r_d = vq->desc + d_d->next;
    virtio_gpu_resource_attach_backing_t *c = c_d->addr;
    virtio_gpu_mem_entry_t *d = d_d->addr;
    ment_cnt = c->nr_entries;
    for (int i = 0; i < ment_cnt; i++) {
      ment[i].addr = d[i].addr;
      ment[i].len = d[i].length;
    }
  } else if (c_hdr->type == VIRTIO_GPU_CMD_TRANSFER_TO_HOST_2D) {
    for (int i = 0; i < ment_cnt; i++) {
      uint32_t *s = (uint32_t *)ment[i].addr;
      for (int j = 0, len = ment[i].len; j < len; s++, j += 4)
        vmgr_wr(VMGR_REG_VGA_UPDATE, *s);
    }
  }
  virtio_gpu_ctrl_hdr_t *r_hdr = r_d->addr;
  r_hdr->flags = VIRTIO_GPU_FLAG_FENCE;
  r_hdr->fence_id = c_hdr->fence_id;
  if (c_hdr->type != VIRTIO_GPU_CMD_GET_DISPLAY_INFO) {
    r_hdr->type = VIRTIO_GPU_RESP_OK_NODATA;
    vgd_add_used(vq, didx, sizeof(*r_hdr));
  }
  vq->last_aidx++;
  return VMGR_FINISH_SUCCESS;
}

static int vgd_handle_curs(void) {
  volatile virtqueue_t *vq = (virtqueue_t *)VGD_START + 1;
  avail_vring_t *avr = vq->avail;
  int aidx = vq->last_aidx;
  if (aidx == avr->idx)
    return VMGR_FINISH_FAILURE;
  int didx = avr->ring[vgd_mod(aidx)];
  desc_t *c_d = vq->desc + didx, *r_d = vq->desc + c_d->next;
  virtio_gpu_ctrl_hdr_t *c_hdr = c_d->addr;
  /* TODO: implement the commands. */
  virtio_gpu_ctrl_hdr_t *r_hdr = r_d->addr;
  r_hdr->flags = VIRTIO_GPU_FLAG_FENCE;
  r_hdr->fence_id = c_hdr->fence_id;
  r_hdr->type = VIRTIO_GPU_RESP_OK_NODATA;
  vgd_add_used(vq, didx, sizeof(*r_hdr));
  vq->last_aidx++;
  return VMGR_FINISH_SUCCESS;
}

void __attribute__((__noreturn__)) process(int arg) {
  int rv, qn = arg & VMGR_ARG_QN_MASK;
  vmgr_dev_t dev = arg >> VMGR_ARG_DEV_SH;
  if (dev == VMGR_DEV_VCD) {
    if (qn == VIRTIO_CONSOLE_RX_QUEUE_NUM)
      rv = vcd_handle_rx();
    else
      rv = vcd_handle_tx();
  } else if (dev == VMGR_DEV_VGD) {
    if (qn == VIRTIO_GPU_CTRL_QUEUE_NUM)
      rv = vgd_handle_ctrl();
    else
      rv = vgd_handle_curs();
  } else {
    halt();
  }
  vmgr_wr(VMGR_REG_FINISH, rv);
  __builtin_unreachable();
}
