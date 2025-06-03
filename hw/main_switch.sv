`default_nettype none

`include "isa.svh"
`include "soc.svh"

module main_switch
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                      clk,
  input  logic                      nrst,

  input  logic [XLEN - 1:0]         asw_addr,
  input  logic [XLEN - 1:0]         asw_wdata,
  input  logic [XLENB_LOG - 1:0]    asw_size,
  input  logic                      asw_nsign,
  input  logic                      asw_ren,
  input  logic                      asw_wen,
  output logic [XLEN - 1:0]         asw_rdata,
  output logic                      asw_stall,

  input  logic [XLEN - 1:0]         vsw_addr,
  input  logic [XLEN - 1:0]         vsw_wdata,
  input  logic [XLENB_LOG - 1:0]    vsw_size,
  input  logic                      vsw_nsign,
  input  logic                      vsw_ren,
  input  logic                      vsw_wen,
  output logic [XLEN - 1:0]         vsw_rdata,
  output logic                      vsw_stall,

  input  logic [XLEN - 1:0]         mmem_rdata,
  input  logic                      mmem_stall,
  output logic [MMEM_ADDRLEN - 1:0] mmem_addr,
  output logic [XLEN - 1:0]         mmem_wdata,
  output logic [XLENB_LOG - 1:0]    mmem_size,
  output logic                      mmem_nsign,
  output logic                      mmem_ren,
  output logic                      mmem_wen
);
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_APP,
    ST_VIRTIO
  } state_t;

  state_t state, state_r;

  /*
   * State transitions
   */
  logic asw_pending;
  logic vsw_pending;

  assign asw_pending = asw_ren || asw_wen;
  assign vsw_pending = vsw_ren || vsw_wen;

  always_comb begin
    state = state_r;

    if (state_r == ST_IDLE) begin
      if (asw_pending)
        state = ST_APP;
      else if (vsw_pending)
        state = ST_VIRTIO;
    end else if (!mmem_stall)
      state = ST_IDLE;
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      state_r <= ST_IDLE;
    else
      state_r <= state;

  /*
   * Application switch signals
   */
  assign asw_rdata = mmem_rdata;
  assign asw_stall = state_r != ST_APP || mmem_stall;

  /*
   * VirtIO switch signals
   */
  assign vsw_rdata = mmem_rdata;
  assign vsw_stall = state_r != ST_VIRTIO || mmem_stall;

  /*
   * Main memory signals
   */
  always_comb
    if (state == ST_APP) begin
      mmem_addr  = asw_addr;
      mmem_wdata = asw_wdata;
      mmem_size  = asw_size;
      mmem_nsign = asw_nsign;
      mmem_ren   = asw_ren;
      mmem_wen   = asw_wen;
    end else begin
      mmem_addr  = vsw_addr;
      mmem_wdata = vsw_wdata;
      mmem_size  = vsw_size;
      mmem_nsign = vsw_nsign;
      mmem_ren   = vsw_ren;
      mmem_wen   = vsw_wen;
    end
endmodule
