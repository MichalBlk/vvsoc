#ifndef __VIRTIO_H__
#define __VIRTIO_H__

#include <soc.h>

typedef struct {
  void *addr;
  int __pad;
  int len;
  short flags;
  short next;
} desc_t;

typedef struct {
  short flags;
  short idx;
  short ring[VCD_QUEUE_NUM_MAX];
  short __pad;
} avail_vring_t;

typedef struct {
  short flags;
  short idx;
  struct {
    int idx;
    int len;
  } ring [VCD_QUEUE_NUM_MAX];
  short __pad;
} used_vring_t;

typedef struct {
  int ready;
  int last_aidx;
  desc_t *desc;
  avail_vring_t *avail;
  used_vring_t *used;
} virtqueue_t;

/*
 * VirtIO registers
 */
#define VIRTIO_REG_MAGIC_VALUE 0x00
#define VIRTIO_REG_VERSION 0x04
#define VIRTIO_REG_DEVICE_ID 0x08
#define VIRTIO_REG_VENDOR_ID 0x0c
#define VIRTIO_REG_QUEUE_SELECT 0x30
#define VIRTIO_REG_QUEUE_NUM_MAX 0x34
#define VIRTIO_REG_QUEUE_READY 0x44
#define VIRTIO_REG_QUEUE_NOTIFY 0x50
#define VIRTIO_REG_INTERRUPT_STATUS 0x60
#define VIRTIO_REG_INTERRUPT_ACK 0x64
#define VIRTIO_REG_STATUS 0x70
#define VIRTIO_REG_QUEUE_DESC_LOW 0x80
#define VIRTIO_REG_QUEUE_DRIVER_LOW 0x90
#define VIRTIO_REG_QUEUE_DEVICE_LOW 0xa0

/*
 * VirtIO magic value
 */
#define VIRTIO_MAGIC_VALUE 0x74726976

/*
 * VirtIO version
 */
#define VIRTIO_VERSION 2

/*
 * VirtIO device IDs
 */
#define VIRTIO_DEVICE_ID_CONSOLE 3 

/*
 * VirtIO vendor IDs
 */
#define VIRTIO_VENDOR_ID_QEMU 0x554d4551

/*
 * VirtIO status
 */
#define VIRTIO_STATUS_DRIVER_OK 0x4

/*
 * VirtIO interrupts
 */
#define VIRTIO_INTERRUPT_USED_BUF 0x1

/*
 * VirtIO console
 */
#define VIRTIO_CONSOLE_RX_QUEUE_NUM 0
#define VIRTIO_CONSOLE_TX_QUEUE_NUM 1

#endif /* !__VIRTIO_H__ */
