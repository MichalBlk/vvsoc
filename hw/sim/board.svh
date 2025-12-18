`ifndef __BOARD_SVH__
`define __BOARD_SVH__

`define SIM 

package board_pkg;
  /*
   * Main memory
   */
  parameter MMEMSZ       = 'h3200000;
  parameter MMEM_DATALEN = 64;

  /*
   * Flash memory
   */
  parameter FLSZ = 'h4000000;

  /*
   * VGA
   */
  parameter VGA_COLORLEN = 8;

  /*
   * Clock
   */
  parameter CLK_FREQ = 100000000;
endpackage

`endif /* !__BOARD_SVH__ */
