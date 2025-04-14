`ifndef __VIRTIO_PKG_H__
`define __VIRTIO_PKG_H__

package virtio_pkg;
  /*
   * VirtIO registers
   */
  parameter VIRTIO_REG_MAGIC_VALUE         = 'h00;
  parameter VIRTIO_REG_VERSION             = 'h04;
  parameter VIRTIO_REG_DEVICE_ID           = 'h08;
  parameter VIRTIO_REG_VENDOR_ID           = 'h0c;
  parameter VIRTIO_REG_DEVICE_FEATURES     = 'h10;
  parameter VIRTIO_REG_DEVICE_FEATURES_SEL = 'h14;
  parameter VIRTIO_REG_QUEUE_SELECT        = 'h30;
  parameter VIRTIO_REG_QUEUE_NUM_MAX       = 'h34;
  parameter VIRTIO_REG_QUEUE_READY         = 'h44;
  parameter VIRTIO_REG_QUEUE_NOTIFY        = 'h50;
  parameter VIRTIO_REG_INTERRUPT_STATUS    = 'h60;
  parameter VIRTIO_REG_INTERRUPT_ACK       = 'h64;
  parameter VIRTIO_REG_STATUS              = 'h70;
  parameter VIRTIO_REG_QUEUE_DESC_LOW      = 'h80;
  parameter VIRTIO_REG_QUEUE_DRIVER_LOW    = 'h90;
  parameter VIRTIO_REG_QUEUE_DEVICE_LOW    = 'ha0;
  parameter VIRTIO_REG_SHM_LEN_LOW         = 'hb0;
  parameter VIRTIO_REG_SHM_LEN_HIGH        = 'hb4;

  /*
   * VirtIO magic value
   */
  parameter VIRTIO_MAGIC_VALUE = 'h74726976;

  /*
   * VirtIO version
   */
  parameter VIRTIO_VERSION = 2;

  /*
   * VirtIO device IDs
   */
  parameter VIRTIO_DEVICE_ID_CONSOLE = 3;
  parameter VIRTIO_DEVICE_ID_GPU     = 16;

  /*
   * VirtIO vendor IDs
   */
  parameter VIRTIO_VENDOR_ID_QEMU = 'h554d4551;

  /*
   * VirtIO device features
   */
  parameter VIRTIO_F_VERSION_1SH = 32;

  /*
   * VirtIO status
   */
  parameter VIRTIO_STATUS_DRIVER_OKSH = 2;

  /*
   * VirtIO interrupts
   */
  parameter VIRTIO_INTERRUPT_USED_BUFSH = 0;

  /*
   * VirtQueue
   */ 
  parameter VIRTQUEUESZW             = 5;

  parameter VIRTQUEUE_READY_OFFW     = 0;
  parameter VIRTQUEUE_LAST_AIDX_OFFW = 1;
  parameter VIRTQUEUE_DESC_OFFW      = 2;
  parameter VIRTQUEUE_DRIVER_OFFW    = 3;
  parameter VIRTQUEUE_DEVICE_OFFW    = 4;

  /*
   * VirtIO console
   */
  parameter VIRTIO_CONSOLE_RX_QUEUE_NUM = 0;
  parameter VIRTIO_CONSOLE_TX_QUEUE_NUM = 1;

  /*
   * VirtIO GPU
   */
  parameter VIRTIO_GPU_REG_NUM_SCANOUTS = 'h108;

  parameter VIRTIO_GPU_CTRL_QUEUE_NUM   = 0;
  parameter VIRTIO_GPU_CURS_QUEUE_NUM   = 1;
endpackage

`endif /* !__VIRTIO_PKG_H__ */
