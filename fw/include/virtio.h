#ifndef __VIRTIO_H__
#define __VIRTIO_H__

#include <stdint.h>
#include <soc.h>

#define QUEUE_NUM_MAX 8

typedef struct {
  void *addr;
  uint32_t __pad;
  uint32_t len;
  uint16_t flags;
  uint16_t next;
} desc_t;

typedef struct {
  uint16_t flags;
  uint16_t idx;
  uint16_t ring[QUEUE_NUM_MAX];
  uint16_t __pad;
} avail_ring_t;

typedef struct {
  uint16_t flags;
  uint16_t idx;
  struct {
    uint32_t idx;
    uint32_t len;
  } ring [QUEUE_NUM_MAX];
  uint16_t __pad;
} used_ring_t;

typedef struct {
  uint32_t ready;
  uint32_t last_aidx;
  desc_t *desc;
  avail_ring_t *avail;
  used_ring_t *used;
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
#define VIRTIO_DEVICDE_ID_GPU 16

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

/*
 * VirtIO GPU
 */
#define VIRTIO_GPU_CTRL_QUEUE_NUM 0
#define VIRTIO_GPU_CURS_QUEUE_NUM 1

/*
 * VirtIO input
 */
#define VIRTIO_INPUT_EVENT_QUEUE_NUM 0
#define VIRTIO_INPUT_STATUS_QUEUE_NUM 1

#endif /* !__VIRTIO_H__ */
