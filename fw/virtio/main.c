#include <virtio.h>
#include <virtio_gpu.h>
#include <virtio_input.h>
#include <evdev.h>
#include <soc.h>

/*
 * Common procedures
 */
static inline void vmgr_wr(int reg, int val);

static void puts(const char *s, int n) {
  for (int i = 0; i < n; i++)
    vmgr_wr(VMGR_REG_UART_TX, (int)s[i]);
  vmgr_wr(VMGR_REG_UART_TX, (int)'\r');
  vmgr_wr(VMGR_REG_UART_TX, (int)'\n');
}

#define PUTS(s) puts(s, sizeof(s))

static __attribute__((__noreturn__)) void halt(void) {
  PUTS("VirtIO core halting!");
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

static void add_used(virtqueue_t *vq, int didx, int len, int (*mod)(int)) {
  used_ring_t *ur = vq->used;
  int uidx = ur->idx;
  ur->ring[mod(uidx)].idx = didx;
  ur->ring[mod(uidx)].len = len;
  ur->idx++;
}

/*
 * VirtIO console device
 */
static inline int vcd_mod(int x) {
  return mod(x, VCD_QUEUE_NUM_MAX);
}

static void vcd_add_used(virtqueue_t *vq, int didx, int len) {
  add_used(vq, didx, len, vcd_mod);
}

static int vcd_handle_single_rx(virtqueue_t *vq, int didx) {
  desc_t *d = vq->desc + didx;
  int len = 0;
  char *c = d->addr;
  /* TODO: consider descriptor's length. */
  for (;; len++, c++) {
    int x = vmgr_rd(VMGR_REG_UART_RX);
    if (x == -1)
      break;
    *c = x;
  }
  if (!len)
    return 0;

  vcd_add_used(vq, didx, len);
  return 1;
}

static int vcd_handle_rx(void) {
  virtqueue_t *vq = (virtqueue_t *)VCD_START;
  avail_ring_t *ar = vq->avail;
  int aidx = vq->last_aidx, end = ar->idx;
  if (aidx == end)
    return VMGR_FINISH_FAILURE;

  for (; aidx != end; aidx++) {
    if (!vcd_handle_single_rx(vq, ar->ring[vcd_mod(aidx)]))
      break;
  }

  vq->last_aidx = aidx;
  return VMGR_FINISH_SUCCESS;
}

static void vcd_handle_single_tx(virtqueue_t *vq, int didx) {
  desc_t *d = vq->desc + didx;
  char *c = d->addr;
  int len = d->len;
  if (!len)
    halt();
  for (int i = 0; i < len; i++)
    vmgr_wr(VMGR_REG_UART_TX, c[i]);

  vcd_add_used(vq, didx, len);
}

static int vcd_handle_tx(void) {
  virtqueue_t *vq = (virtqueue_t *)VCD_START + 1;
  avail_ring_t *ar = vq->avail;
  int aidx = vq->last_aidx, end = ar->idx;
  if (aidx == ar->idx)
    return VMGR_FINISH_FAILURE;

  for (; aidx != end; aidx++)
    vcd_handle_single_tx(vq, ar->ring[vcd_mod(aidx)]);

  vq->last_aidx = end;
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

static void vgd_add_used(virtqueue_t *vq, int didx, int len) {
  add_used(vq, didx, len, vgd_mod);
}

static void vgd_handle_single_ctrl(virtqueue_t *vq, int didx) {
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
  if (c_hdr->flags & VIRTIO_GPU_FLAG_FENCE)
    r_hdr->flags = VIRTIO_GPU_FLAG_FENCE;
  else
    r_hdr->flags = 0;
  r_hdr->fence_id = c_hdr->fence_id;
  if (c_hdr->type != VIRTIO_GPU_CMD_GET_DISPLAY_INFO) {
    r_hdr->type = VIRTIO_GPU_RESP_OK_NODATA;
    vgd_add_used(vq, didx, sizeof(virtio_gpu_ctrl_hdr_t));
  } else {
    vgd_add_used(vq, didx, sizeof(virtio_gpu_resp_display_info_t));
  }
}

static int vgd_handle_ctrl(void) {
  virtqueue_t *vq = (virtqueue_t *)VGD_START;
  avail_ring_t *ar = vq->avail;
  int aidx = vq->last_aidx, end = ar->idx;
  if (aidx == end)
    return VMGR_FINISH_FAILURE;

  for (; aidx != end; aidx++)
    vgd_handle_single_ctrl(vq, ar->ring[vgd_mod(aidx)]);

  vq->last_aidx = end;
  return VMGR_FINISH_SUCCESS;
}

static void vgd_handle_single_curs(virtqueue_t *vq, int didx) {
  desc_t *c_d = vq->desc + didx, *r_d = vq->desc + c_d->next;
  virtio_gpu_ctrl_hdr_t *c_hdr = c_d->addr;

  /* TODO: implement the commands. */

  virtio_gpu_ctrl_hdr_t *r_hdr = r_d->addr;
  r_hdr->flags = VIRTIO_GPU_FLAG_FENCE;
  r_hdr->fence_id = c_hdr->fence_id;
  r_hdr->type = VIRTIO_GPU_RESP_OK_NODATA;
  vgd_add_used(vq, didx, sizeof(virtio_gpu_ctrl_hdr_t));
}

static int vgd_handle_curs(void) {
  virtqueue_t *vq = (virtqueue_t *)VGD_START + 1;
  avail_ring_t *ar = vq->avail;
  int aidx = vq->last_aidx, end = ar->idx;
  if (aidx == end)
    return VMGR_FINISH_FAILURE;

  for (; aidx != end; aidx++)
    vgd_handle_single_curs(vq, ar->ring[vgd_mod(aidx)]);

  vq->last_aidx = end;
  return VMGR_FINISH_SUCCESS;
}

/*
 * VirtIO keyboard device
 */
static inline int vkd_mod(int x) {
  return mod(x, VKD_QUEUE_NUM_MAX);
}

static void vkd_add_used(virtqueue_t *vq, int didx, int len) {
  add_used(vq, didx, len, vkd_mod);
}

static int vkd_handle_single_event(virtqueue_t *vq, int didx) {
  desc_t *d = vq->desc + didx;
  int data = vmgr_rd(VMGR_REG_KBD);
  if (data == -1)
    return 0;

  virtio_input_event_t *ev = d->addr;
  ev->type = EV_KEY;
  ev->code = data >> 1;
  ev->value = data & 1;

  vkd_add_used(vq, didx, sizeof(virtio_input_event_t));
  return 1;
}

static void vkd_add_syn(virtqueue_t *vq, int didx) {
  desc_t *d = vq->desc + didx;
  virtio_input_event_t *ev = d->addr;
  ev->type = EV_SYN;
  ev->code = SYN_REPORT;
  ev->value = 0;
  vkd_add_used(vq, didx, sizeof(virtio_input_event_t));
}

static int vkd_handle_event(void) {
  virtqueue_t *vq = (virtqueue_t *)VKD_START;
  avail_ring_t *ar = vq->avail;
  int aidx = vq->last_aidx, end = ar->idx;
  if (aidx == end)
    return VMGR_FINISH_FAILURE;

  for (; aidx != end; aidx += 2) {
    if (!vkd_handle_single_event(vq, ar->ring[vkd_mod(aidx)]))
      break;
    vkd_add_syn(vq, ar->ring[vkd_mod(aidx + 1)]);
  }

  vq->last_aidx = aidx;
  return VMGR_FINISH_SUCCESS;
}

static int vkd_handle_status(void) {
  /* TODO: remove the halting. */
  halt();
}

void __attribute__((__noreturn__)) process(void) {
  for (;;) {
    int arg = vmgr_rd(VMGR_REG_REQ);
    int rv, qn = arg & VMGR_ARG_QN_MASK;
    int dev = arg >> VMGR_ARG_DEV_SH;

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
    } else if (dev == VMGR_DEV_VKD) {
      if (qn == VIRTIO_INPUT_EVENT_QUEUE_NUM)
        rv = vkd_handle_event();
      else
        rv = vkd_handle_status();
    } else {
      halt();
    }

    vmgr_wr(VMGR_REG_FINISH, rv);
  }
}
