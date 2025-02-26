`ifndef __SOC_PKG_SVH__
`define __SOC_PKG_SVH__

`include "virtio_pkg.svh"

package soc_pkg;
  import isa_pkg::XLEN;
  import isa_pkg::XLENB_LOG;
  import isa_pkg::PAGESZ;
  import isa_pkg::PNLEN;
  import virtio_pkg::VIRTIO_F_VERSION_1SH;

  /*
   * Device types
   */
  parameter ADDR_DEVSH = 28;
  parameter DEVLEN     = 4;

  typedef enum logic [DEVLEN - 1:0] {
    DEV_VMEM  = DEVLEN'(1),
    DEV_VMGR  = DEVLEN'(2),
    DEV_VCD   = DEVLEN'(3),
    DEV_VGD   = DEVLEN'(4),
    DEV_DBGC  = DEVLEN'(6),
    DEV_CLINT = DEVLEN'(7),
    DEV_MMEM  = DEVLEN'(8)
  } dev_t;

  /*
   * Main memory
   */
  parameter MMEMSZ           = 'h3200000;
  parameter MMEM_ADDRLEN     = $clog2(MMEMSZ);

  parameter MMEM_KERNEL_OFF  = 'h0000000;
  parameter MMEM_FW_OFF      = 'h1000000;
  parameter MMEM_DTB_OFF     = 'h1100000;
  parameter MMEM_INITRD_OFF  = 'h2000000;

  parameter MMEM_KERNEL_OFFW = MMEM_KERNEL_OFF >> XLENB_LOG;
  parameter MMEM_FW_OFFW     = MMEM_FW_OFF >> XLENB_LOG;
  parameter MMEM_DTB_OFFW    = MMEM_DTB_OFF >> XLENB_LOG;
  parameter MMEM_INITRD_OFFW = MMEM_INITRD_OFF >> XLENB_LOG;

  /*
   * Application core
   */
  parameter AC_RESET_PC = (XLEN'(DEV_MMEM) << ADDR_DEVSH) | MMEM_FW_OFF;

  /*
   * TLB
   */
  parameter TLB_SETCNT  = 4;
  parameter TLB_LINECNT = 4;

  /*
   * VirtIO core
   */
  parameter VC_RESET_PC = XLEN'(DEV_VMEM) << ADDR_DEVSH;

  /*
   * VirtIO memory
   */
  parameter VMEMSZ       = 4 * PAGESZ;
  parameter VMEM_ADDRLEN = $clog2(VMEMSZ);

  /*
   * VirtIO manager
   */
  parameter VMGR_ADDRLEN            = 4;
  parameter VMGR_UART_RX_FIFOSZ     = 64;
  parameter VMGR_VGA_FRAME_FIFOSZ   = 4;

  parameter VMGR_REG_UART_RX        = 'h0;
  parameter VMGR_REG_UART_TX        = 'h4;
  parameter VMGR_REG_VGA_UPDATE     = 'h8;
  parameter VMGR_REG_FINISH         = 'hc;

  parameter VMGR_FINISH_SUCCESS     = 0;
  parameter VMGR_FINISH_FAILURE     = 1;

  parameter VMGR_DEVCNT             = 2;
  parameter VMGR_DEVLEN             = $clog2(VMGR_DEVCNT);

  typedef enum logic [VMGR_DEVLEN - 1:0] {
    VMGR_DEV_VCD = VMGR_DEVLEN'(0),
    VMGR_DEV_VGD = VMGR_DEVLEN'(1)
  } vmgr_dev_t;

  parameter VMGR_MAXQUEUECNT        = 2;
  parameter VMGR_MAXQUEUECNT_LOG    = $clog2(VMGR_MAXQUEUECNT);
  parameter VMGR_QUEUE_NOTIF_CNTLEN = 4;

  parameter VMGR_DELAY_CYCLES       = 2048;
  parameter VMGR_DELAY_CNTLEN       = $clog2(VMGR_DELAY_CYCLES);

  /*
   * VirtIO console device
   */
  parameter         VCD_ADDRLEN         = 12;
  parameter         VCD_ADDRLENW        = VCD_ADDRLEN - XLENB_LOG;
  parameter         VCD_QUEUECNT        = 2;
  parameter         VCD_QUEUECNT_LOG    = $clog2(VCD_QUEUECNT);
  parameter         VCD_QUEUENUMMAX     = 2;
  parameter         VCD_QUEUENUMMAX_LOG = $clog2(VCD_QUEUENUMMAX);
  parameter longint VCD_FEATURES        = 1 << VIRTIO_F_VERSION_1SH;

  /*
   * VirtIO GPU device
   */
  parameter         VGD_ADDRLEN         = 12;
  parameter         VGD_ADDRLENW        = VGD_ADDRLEN - XLENB_LOG;
  parameter         VGD_QUEUECNT        = 2;
  parameter         VGD_QUEUECNT_LOG    = $clog2(VCD_QUEUECNT);
  parameter         VGD_QUEUENUMMAX     = 8;
  parameter         VGD_QUEUENUMMAX_LOG = $clog2(VCD_QUEUENUMMAX);
  parameter longint VGD_FEATURES        = 1 << VIRTIO_F_VERSION_1SH;

  /*
   * CLINT
   */
  parameter CLINT_ADDRLEN       = 16;

  parameter CLINT_REG_MTIMECMP  = 'h4000;
  parameter CLINT_REG_MTIMECMPH = 'h4004;
  parameter CLINT_REG_MTIME     = 'hbff8;
  parameter CLINT_REG_MTIMEH    = 'hbffc;

  /*
   * UART
   */
  parameter UART_BAUD_RATE = 115200;

  /*
   * VGA
   */
  parameter VGA_WIDTH       = 640;
  parameter VGA_H_ACTIVECNT = VGA_WIDTH;
  parameter VGA_H_FRONTPCNT = 16;
  parameter VGA_H_SYNCWIDTH = 96;
  parameter VGA_H_TOTALBCNT = 160;
  parameter VGA_H_SYNCSTART = VGA_H_ACTIVECNT + VGA_H_FRONTPCNT - 1;
  parameter VGA_H_SYNCEND   = VGA_H_SYNCSTART + VGA_H_SYNCWIDTH;
  parameter VGA_H_MAX       = VGA_H_ACTIVECNT + VGA_H_TOTALBCNT - 1;

  parameter VGA_HEIGHT      = 480;
  parameter VGA_V_ACTIVECNT = VGA_HEIGHT;
  parameter VGA_V_FRONTPCNT = 10;
  parameter VGA_V_SYNCWIDTH = 2;
  parameter VGA_V_TOTALBCNT = 45;
  parameter VGA_V_SYNCSTART = VGA_V_ACTIVECNT + VGA_V_FRONTPCNT - 1;
  parameter VGA_V_SYNCEND   = VGA_V_SYNCSTART + VGA_V_SYNCWIDTH;
  parameter VGA_V_MAX       = VGA_V_ACTIVECNT + VGA_V_TOTALBCNT - 1;

  parameter VGA_POSLEN      = $clog2(VGA_H_MAX + 1);
  parameter VGA_COLORLEN    = 8;

  /*
   * Clock
   */
  parameter CLK_FREQ = 50000000;
endpackage

`endif /* !__SOC_PKG_SVH__ */
