`ifndef __BOARD_SVH__
`define __BOARD_SVH__

`define NEXYS_A7

package board_pkg;
  /*
   * Main memory
   */
  parameter MMEMSZ       = 'h8000000;
  parameter MMEM_DATALEN = 128;

  /*
   * Flash memory
   */
  parameter FLSZ = 'h1000000;

  /*
   * VGA
   */
  parameter VGA_COLORLEN = 4;

  /*
   * Clock
   */
  parameter CLK_FREQ = 100000000;

  /*
   * DRAM
   */
  parameter DDR2_DQLEN   = 16;
  parameter DDR2_DQSLEN  = 2;
  parameter DDR2_ADDRLEN = 13;
  parameter DDR2_BALEN   = 3;
  parameter DDR2_DMLEN   = 2;
endpackage

`endif /* !__BOARD_SVH__ */
