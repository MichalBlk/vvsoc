`default_nettype none

`include "isa.svh"

module dbg_console
  import isa_pkg::*;
(
  input logic              clk,

  input logic [BLEN - 1:0] asw_wdata,
  input logic              asw_wen
);
  always_ff @(posedge clk)
    if (asw_wen)
      $write("%c", asw_wdata);
endmodule
