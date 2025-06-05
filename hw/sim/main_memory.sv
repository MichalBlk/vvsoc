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
  typedef enum logic {
    ST_IDLE,
    ST_BUSY
  } state_t;

  state_t state, state_r;

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
  always_ff @(posedge clk) begin
    if (state_r == ST_BUSY && cache_wen)
      mem[addrw] <= cache_wdata;
  end

  always_comb begin
    state = state_r;

    case (state_r)
      ST_IDLE:
        if (cache_ren || cache_wen)
          state = ST_BUSY;

      ST_BUSY:
        state = ST_IDLE;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      state_r <= ST_IDLE;
    else
      state_r <= state;

  /*
   * Other signals
   */
  //assign cache_stall = 0;
  assign cache_stall = state_r == ST_IDLE;
endmodule
