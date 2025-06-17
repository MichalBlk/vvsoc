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
  output logic [XLEN - 1:0]      raw_data,
  output logic [XLEN - 1:0]      rdata,
  output logic                   stall
);
  localparam SZW      = SZ / XLENB;
  localparam ADDRWLEN = $clog2(SZW);

  typedef enum logic {
    ST_IDLE,
    ST_BUSY
  } state_t;

  logic [XLEN - 1:0]      mem [SZW - 1:0];

  state_t                 state, state_r;

  logic [ADDRLEN - 1:0]   baddr, baddr_r;
  logic [XLEN - 1:0]      bwdata, bwdata_r;
  logic [XLENB_LOG - 1:0] bsize, bsize_r;
  logic                   bsign, bsign_r;
  logic                   bwen, bwen_r;

  logic [ADDRWLEN - 1:0]  addrw, addrw_r;
  logic [XLEN - 1:0]      data_r;
  logic [XLEN - 1:0]      value;
  logic [XLEN_LOG - 1:0]  addrbit;
  logic [XLEN_LOG:0]      sizebit;
  logic [XLEN - 1:0]      mask;

  initial
    $readmemh(MIF, mem);

  /*
   * Input buffering
   */
  always_comb begin
    baddr  = baddr_r;
    bwdata = bwdata_r;
    bsize  = bsize_r;
    bsign  = bsign_r;
    bwen   = bwen_r;

    if (state_r == ST_IDLE) begin
      baddr  = addr;
      bwdata = wdata;
      bsize  = size;
      bsign  = !nsign;
      bwen   = wen;
    end
  end

  always_ff @(posedge clk) begin
    baddr_r  <= baddr;
    bwdata_r <= bwdata;
    bsize_r  <= bsize;
    bsign_r  <= bsign;
    bwen_r   <= bwen;
  end

  /*
   * Address and size calculation
   */
  always_comb begin
    addrw = addrw_r;

    if (state_r == ST_IDLE)
      addrw = addr >> XLENB_LOG;
  end

  always_ff @(posedge clk)
    addrw_r <= addrw;

  assign addrbit = baddr_r[XLENB_LOG - 1:0] << BLEN_LOG;
  assign sizebit = 1 << (bsize_r + BLEN_LOG);
  assign mask    = (1 << sizebit) - 1;

  /*
   * Memory
   */
  always_ff @(posedge clk)
    data_r <= mem[addrw];

  always_ff @(posedge clk)
    if (state_r == ST_BUSY && bwen_r)
      mem[addrw_r] <= value;

  /*
   * Reading
   */
  logic [XLEN - 1:0] shdata;

  assign raw_data = data_r;

  assign shdata   = (data_r >> addrbit) & mask;

  always_comb
    if (bsign_r && (shdata >> (sizebit - 1)))
      rdata = shdata | ~mask;
    else
      rdata = shdata;

  /*
   * Writing
   */
  assign value = (data_r & ~(mask << addrbit)) | ((bwdata_r & mask) << addrbit);

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
  assign stall = state_r != ST_BUSY;
endmodule
