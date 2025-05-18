`default_nettype none

`include "isa.svh"

module memory
  import isa_pkg::*;
#(
  parameter        SZ      = 4096,
  parameter string MIF     = "file.mif",

  localparam       ADDRLEN = $clog2(SZ)
)(
  input  logic                   clk,
  input  logic                   nrst,

  input  logic [ADDRLEN - 1:0]   addr,
  input  logic [XLEN - 1:0]      wdata,
  input  logic [XLENB_LOG - 1:0] size,
  input  logic                   nsign,
  input  logic                   ren,
  input  logic                   wen,
  output logic [XLEN - 1:0]      rdata,
  output logic                   stall
);
  localparam SZW      = SZ / XLENB;
  localparam ADDRWLEN = $clog2(SZW);

  typedef enum logic {
    ST_IDLE,
    ST_BUSY
  } state_t;

  logic [XLEN - 1:0]     mem [SZW - 1:0];

  state_t                state, state_r;
  logic [XLEN - 1:0]     data_r;

  logic [ADDRWLEN - 1:0] addrw;
  logic [XLEN_LOG - 1:0] addrbit;
  logic [XLEN_LOG:0]     sizebit;
  logic [XLEN - 1:0]     mask;
  logic [XLEN - 1:0]     value;

  initial
    $readmemh(MIF, mem);

  /*
   * Address and size calculation
   */
  assign addrw   = addr >> XLENB_LOG;
  assign addrbit = addr[XLENB_LOG - 1:0] << BLEN_LOG;
  assign sizebit = 1 << (size + BLEN_LOG);
  assign mask    = (1 << sizebit) - 1;

  /*
   * Memory
   */
  always_ff @(posedge clk)
    data_r <= mem[addrw];

  always_ff @(posedge clk)
    if (state_r == ST_BUSY && wen)
      mem[addrw] <= value;

  /*
   * Reading
   */
  logic [XLEN - 1:0] shdata;

  assign shdata = (data_r >> addrbit) & mask;

  always_comb
    if (!nsign && (shdata >> (sizebit - 1)))
      rdata = shdata | ~mask;
    else
      rdata = shdata;

  /*
   * Writing
   */
  assign value = (data_r & ~(mask << addrbit)) | ((wdata & mask) << addrbit);

  /*
   * State transitions
   */
  assign state = state_r == ST_IDLE && (ren || wen) ? ST_BUSY : ST_IDLE;

  always_ff @(posedge clk, negedge nrst) begin
    if (!nrst)
      state_r <= ST_IDLE;
    else
      state_r <= state;
  end

  /*
   * Other signals
   */
  assign stall = state != ST_IDLE;
endmodule
