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
  logic [XLEN - 1:0]     data, data_r;

  logic [ADDRWLEN - 1:0] addrw;
  logic [XLEN_LOG - 1:0] addrbit;
  logic [XLEN_LOG:0]     sizebit;
  logic [XLEN - 1:0]     mask;

  assign addrw   = addr >> XLENB_LOG;
  assign addrbit = addr[XLENB_LOG - 1:0] << BLEN_LOG;
  assign sizebit = 1 << (size + BLEN_LOG);
  assign mask    = (1 << sizebit) - 1;

  /*
   * Data
   */
  always_comb begin
    data = data_r;

    if (state_r == ST_READ)
      data = {<<BLEN{mem[addrw]}};
  end

  always_ff @(posedge clk)
    data_r <= data;

  always_ff @(posedge clk, negedge nrst) begin
    if (!nrst)
      state_r <= ST_READ;
    else
      state_r <= state;
  end

  /*
   * Reading
   */
  logic [XLEN - 1:0] shdata;

  assign shdata = (data >> addrbit) & mask;

  always_comb begin
    if (!nsign && (shdata >> (sizebit - 1)))
      rdata = shdata | ~mask;
    else
      rdata = shdata;
  end

  /*
   * Writing
   */
  always_ff @(posedge clk) begin
    if (state_r == ST_WRITE)
      mem[addrw] <= {<<BLEN{(data_r & ~(mask << addrbit)) | ((wdata & mask) << addrbit)}};
  end

  /*
   * State transitions
   */
  always_comb begin
    state = state_r;

    case (state_r)
      ST_READ:
        if (wen)
          state = ST_WRITE;

      ST_WRITE:
        state = ST_READ;
    endcase
  end

  /*
   * Other signals
   */
  assign stall = state == ST_WRITE;
endmodule
