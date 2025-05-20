`default_nettype none

`include "isa.svh"

module dbg_console
  import isa_pkg::*;
(
  input  logic              clk,

  input  logic [BLEN - 1:0] asw_wdata,
  input  logic              asw_wen,
  output logic              asw_stall,

  input  logic              vmgr_stall,
  output logic [BLEN - 1:0] vmgr_byte,
  output logic              vmgr_wen
);
  /*
   * Application switch signals
   */
  assign asw_stall = vmgr_stall;

  /*
   * VirtIO manager signals
   */
  assign vmgr_byte = asw_wdata;
  assign vmgr_wen  = asw_wen;
endmodule
