`ifndef __BOARD_SVH__
`define __BOARD_SVH__

`define NEXYS_A7

package board_pkg;
  /*
   * Main memory
   */
  parameter MMEM_DATALEN = 128;

  /*
   * DRAM
   */
  parameter DDR2_DQLEN   = 16;
  parameter DDR2_DQSLEN  = 2;
  parameter DDR2_ADDRLEN = 13;
  parameter DDR2_BALEN   = 3;
  parameter DDR2_DMLEN   = 2;

  /*
   * VGA
   */
  parameter VGA_COLORLEN = 4;
endpackage

`endif /* !__BOARD_SVH__ */
