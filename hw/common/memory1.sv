`default_nettype none

`include "isa_pkg.svh"

module memory
  import isa_pkg::*;
#(
  parameter  SZ      = 4096,

  localparam ADDRLEN = $clog2(SZ)
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
    ST_READ,
    ST_WRITE
  } state_t;

  logic [XLEN - 1:0]     mem [SZW - 1:0];

  state_t                state, state_r;
  logic [XLEN - 1:0]     cdata, cdata_r;
  logic [XLEN - 1:0]     ndata, ndata_r;
  logic [ADDRWLEN - 1:0] addrw, addrw_r;
  logic [XLEN_LOG - 1:0] addrbit, addrbit_r;
  logic [XLEN_LOG:0]     sizebit, sizebit_r;
  logic [XLEN - 1:0]     mask, mask_r;

  logic [XLEN - 1:0]     value;

  /*
   * Address and size calculation
   */
  assign addrw   = addr >> XLENB_LOG;
  assign addrbit = addr[XLENB_LOG - 1:0] << BLEN_LOG;
  assign sizebit = 1 << (size + BLEN_LOG);
  assign mask    = (1 << sizebit) - 1;

  always_ff @(posedge clk) begin
    addrw_r   <= addrw;
    addrbit_r <= addrbit;
    sizebit_r <= sizebit;
    mask_r    <= mask;
  end

  /*
   * Data
   */
  assign cdata = state_r == ST_WRITE && addrw == addrw_r ? value : mem[addrw];
  assign ndata = wdata;

  always_ff @(posedge clk) begin
    cdata_r <= cdata;
    ndata_r <= ndata;
  end

  /*
   * Reading
   */
  logic [XLEN - 1:0] shdata;

  assign shdata = (cdata >> addrbit) & mask;

  always_comb begin
    if (!nsign && (shdata >> (sizebit - 1)))
      rdata = shdata | ~mask;
    else
      rdata = shdata;
  end

  /*
   * Writing
   */
  assign value = (cdata_r & ~(mask_r << addrbit_r)) | ((ndata_r & mask_r) << addrbit_r);

  always_ff @(posedge clk) begin
    if (state_r == ST_WRITE) begin
     // $display("[MMEM] wiriting %x to %x", value, addrw_r);
      mem[addrw_r] <= value;
    end
  end

  /*
   * State transitions
   */
  assign state = wen ? ST_WRITE : ST_READ;

  always_ff @(posedge clk, negedge nrst) begin
    if (!nrst)
      state_r <= ST_READ;
    else
      state_r <= state;
  end

  /*
   * Other signals
   */
  assign stall = 0;
endmodule
