`default_nettype none

`include "soc.svh"

module cache_agent
  import param_pkg::*;
  import soc_pkg::*;
  import board_pkg::*;
(
  input  logic                       clk,
  input  logic                       nrst,

  input  logic [MMEM_ADDRLEN - 1:0]  cache_addr,
  input  logic [CACHE_LINELEN - 1:0] cache_wdata,
  input  logic                       cache_ren,
  input  logic                       cache_wen,
  output logic [CACHE_LINELEN - 1:0] cache_rdata,
  output logic                       cache_ready,
  output logic                       cache_done,

  input  logic [MMEM_DATALEN - 1:0]  mmem_rdata,
  input  logic                       mmem_stall,
  output logic [MMEM_ADDRLEN - 1:0]  mmem_addr,
  output logic [MMEM_DATALEN - 1:0]  mmem_wdata,
  output logic                       mmem_ren,
  output logic                       mmem_wen
);
  typedef enum logic {
    ST_IDLE,
    ST_BUSY
  } state_t;

  state_t                         state, state_r;

  logic [MMEM_ADDRLEN - 1:0]      addr, addr_r;
  logic [CACHE_LINELEN - 1:0]     rdata, rdata_r;
  logic [CACHE_LINELEN - 1:0]     wdata, wdata_r;
  logic                           wen, wen_r;
  logic [CACHE_MMEM_CNTLEN - 1:0] cnt, cnt_r;
  logic                           mem_finished;

  /*
   * Input buffering
   */
  always_comb begin
    wen = wen_r;

    if (state_r == ST_IDLE)
      wen = cache_wen;
  end

  always_ff @(posedge clk)
    wen_r <= wen;

  /*
   * Address handling
   */
  always_comb begin
    addr = addr_r;

    case (state_r)
      ST_IDLE:
        addr = cache_addr;

      ST_BUSY:
        if (!mmem_stall)
          addr = addr_r + MMEM_DATALENB;
    endcase
  end

  always_ff @(posedge clk)
    addr_r <= addr;

  /*
   * Reading
   */
  always_comb begin
    rdata = rdata_r;

    if (state_r == ST_BUSY && !mmem_stall)
      rdata = {mmem_rdata, rdata_r[CACHE_LINELEN - 1:MMEM_DATALEN]};
  end

  always_ff @(posedge clk)
    rdata_r <= rdata;

  /*
   * Writing
   */
  always_comb begin
    wdata = wdata_r;

    case (state_r)
      ST_IDLE:
        wdata = cache_wdata;

      ST_BUSY:
        if (!mmem_stall)
          wdata = wdata_r >> MMEM_DATALEN;
    endcase
  end

  always_ff @(posedge clk)
    wdata_r <= wdata;

  /*
   * Counter handling
   */
  always_comb begin
    cnt = cnt_r;

    case (state_r)
      ST_IDLE:
        cnt = CACHE_MMEM_CYCLES - 1;

      ST_BUSY:
        if (!mmem_stall)
          cnt = cnt_r - 1;
    endcase
  end

  always_ff @(posedge clk)
    cnt_r <= cnt;

  /*
   * State transitions
   */
  assign mem_finished = !cnt_r && !mmem_stall;

  always_comb begin
    state = state_r;

    case (state_r)
      ST_IDLE:
        if (cache_ren || cache_wen)
          state = ST_BUSY;

      ST_BUSY:
        if (mem_finished)
          state = ST_IDLE;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      state_r <= ST_IDLE;
    else
      state_r <= state;

  /*
   * Cache signals
   */
  assign cache_rdata = rdata;
  assign cache_ready = state_r == ST_IDLE;
  assign cache_done  = state == ST_IDLE;

  /*
   * Main memory signals
   */
  assign mmem_addr  = addr_r;
  assign mmem_wdata = wdata_r[MMEM_DATALEN - 1:0];
  assign mmem_ren   = state_r == ST_BUSY && !wen_r;
  assign mmem_wen   = state_r == ST_BUSY && wen_r;
endmodule
