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
    DEV_DBGC  = DEVLEN'(6),
    DEV_CLINT = DEVLEN'(7),
    DEV_MMEM  = DEVLEN'(8)
  } dev_t;

  /*
   * Main memory
   */
  parameter MMEMSZ           = 'h4000000;
  parameter MMEM_ADDRLEN     = $clog2(MMEMSZ);

  parameter MMEM_KERNEL_OFF  = 'h0000000;
  parameter MMEM_FW_OFF      = 'h2000000;
  parameter MMEM_DTB_OFF     = 'h2100000;
  parameter MMEM_INITRD_OFF  = 'h3000000;

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

  parameter VMGR_REG_UART_RX        = 0;
  parameter VMGR_REG_UART_TX        = 4;
  parameter VMGR_REG_FINISH         = 8;

  parameter VMGR_FINISH_SUCCESS     = 0;
  parameter VMGR_FINISH_FAILURE     = 1;

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
   * Clock
   */
  parameter CLK_FREQ = 50000000;
endpackage

`endif /* !__SOC_PKG_SVH__ */
