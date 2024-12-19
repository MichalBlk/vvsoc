`ifndef __SOC_PKG_SVH__
`define __SOC_PKG_SVH__

package soc_pkg;
  import isa_pkg::XLEN;
  import isa_pkg::XLENB_LOG;
  import isa_pkg::PAGESZ;
  import isa_pkg::PNLEN;

  /*
   * Device types
   */
  parameter ADDR_DEVSH = 28;
  parameter DEVLEN     = 4;

  typedef enum logic [DEVLEN - 1:0] {
    DEV_VMEM  = DEVLEN'(1),
    DEV_VMGR  = DEVLEN'(2),
    DEV_VCD   = DEVLEN'(3),
    DEV_CLINT = DEVLEN'(7),
    DEV_MMEM  = DEVLEN'(8)
  } dev_t;

  /*
   * Application core
   */
  parameter AC_RESET_PC = /*XLEN'(DEV_MMEM) << ADDR_DEVSH;*/ 'h80100000;

  /*
   * TLB
   */
  parameter TLB_ECNT     = 32;
  parameter TLB_ECNT_LOG = $clog2(TLB_ECNT);
  parameter TLB_TAGLEN   = PNLEN - TLB_ECNT_LOG;

  /*
   * VirtIO core
   */
  parameter VC_RESET_PC = XLEN'(DEV_VMEM) << ADDR_DEVSH;

  /*
   * VirtIO memory
   */
  parameter        VMEMSZ        = PAGESZ;
  parameter        VMEM_ADDRLEN  = $clog2(VMEMSZ);
  parameter string VMEM_FILENAME = "vmem.bin";

  /*
   * VirtIO manager
   */
  parameter VMGR_ADDRLEN        = 4;
  parameter VMGR_UART_RX_FIFOSZ = 64;

  parameter VMGR_REG_UART_RX    = 0;
  parameter VMGR_REG_UART_TX    = 4;
  parameter VMGR_REG_FINISH     = 8;

  parameter VMGR_DELAY_CYCLES   = 2048;
  parameter VMGR_DELAY_CNTLEN   = $clog2(VMGR_DELAY_CYCLES);

  /*
   * VirtIO console device
   */
  parameter VCD_ADDRLEN      = 8;
  parameter VCD_ADDRLENW     = VCD_ADDRLEN - XLENB_LOG;
  parameter VCD_QUEUECNT     = 2;
  parameter VCD_QUEUECNT_LOG = $clog2(VCD_QUEUECNT);

  /*
   * CLINT
   */
  parameter CLINT_ADDRLEN       = 16;

  parameter CLINT_REG_MTIMECMP  = 'h4000;
  parameter CLINT_REG_MTIMECMPH = 'h4004;
  parameter CLINT_REG_MTIME     = 'hbff8;
  parameter CLINT_REG_MTIMEH    = 'hbffc;

  /*
   * Main memory
   */
  parameter        MMEMSZ        = 'h6000000;
  parameter        MMEM_ADDRLEN  = $clog2(MMEMSZ);
  parameter string MMEM_FILENAME = "mmem.bin";

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
