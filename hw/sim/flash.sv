`default_nettype none

`include "isa.svh"
`include "soc.svh"

module flash
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                    clk,
  input  logic                    nrst,

  input  logic [FL_ADDRLEN - 1:0] asw_addr,
  input  logic                    asw_nsign,
  input  logic                    asw_ren,
  output logic [XLEN - 1:0]       asw_rdata,
  output logic                    asw_stall
);
  /*
   * Application switch signals
   */
  assign asw_rdata = 'bx;
  assign asw_stall = 0;
endmodule
