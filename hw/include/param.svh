`ifndef __PARAM_SVH__
`define __PARAM_SVH__

`include "isa.svh"
`include "board.svh"

package param_pkg;
  import isa_pkg::PAGESZ;

  /*
   * TLB
   */
  parameter TLB_SETCNT  = 4;
  parameter TLB_LINECNT = 4;

  /*
   * VirtIO memory
   */
  parameter VMEMSZ = 2 * PAGESZ;

  /*
   * VirtIO manager
   */
`ifdef SIM
  parameter VMGR_UART_RX_FIFOSZ = 64;
`else
  parameter VMGR_UART_RX_FIFOSZ = 256;
`endif

  parameter VMGR_KBD_FIFOSZ     = 64;

  /*
   * Boot memory
   */
  parameter BMEMSZ = PAGESZ;

  /*
   * Cache
   */
  parameter CACHE_SETCNT  = 16;
  parameter CACHE_LINELEN = 512;

  /*
   * UART
   */
  parameter UART_BAUD_RATE = 115200;

  /*
   * Statistics
   */
  parameter STATS_CNTLEN = 32;
endpackage

`endif /* !__PARAM_SVH__ */
