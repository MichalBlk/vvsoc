`default_nettype none

`include "isa.svh"
`include "soc.svh"
`include "board.svh"

module main_memory
  import isa_pkg::*;
  import soc_pkg::*;
  import board_pkg::*;
(
  input  logic                      clk,
  input  logic                      nrst,

  input  logic [MMEM_ADDRLEN - 1:0] cache_addr,
  input  logic [MMEM_DATALEN - 1:0] cache_wdata,
  input  logic                      cache_ren,
  input  logic                      cache_wen,
  output logic [MMEM_DATALEN - 1:0] cache_rdata,
  output logic                      cache_stall
);
  logic [MMEM_DATALEN - 1:0]  mem [MMEMSZW - 1:0];

  logic [MMEM_ADDRWLEN - 1:0] addrw;

  assign addrw = cache_addr >> MMEM_DATALENB_LOG;

  /*
   * Reading
   */
  assign cache_rdata = mem[addrw];

  /*
   * Writing
   */
  always_ff @(posedge clk)
    if (cache_wen)
      mem[addrw] <= cache_wdata;

  /*
   * Other signals
   */
  assign cache_stall = 0;
endmodule
