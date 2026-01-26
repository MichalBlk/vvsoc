`include "isa.svh"
`include "soc.svh"

module flash
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                    clk,
  input  logic                    fl_clk,
  input  logic                    nrst,

  input  logic [FL_ADDRLEN - 1:0] asw_addr,
  input  logic                    asw_nsign,
  input  logic                    asw_ren,
  output logic [XLEN - 1:0]       asw_rdata,
  output logic                    asw_stall,

  input  logic                    miso,
  output logic                    mosi,
  output logic                    sclk,
  output logic                    ncs
);
`default_nettype none

  typedef enum logic [1:0] {
    ST_IDLE,
    ST_READ,
    ST_READ_WAIT,
    ST_FINISH
  } state_t;

  state_t                  state, state_r;

  logic [FL_ADDRLEN - 1:0] addr, addr_r;
  logic                    sign, sign_r;

  logic [BLEN - 1:0]       rdata, rdata_r;
  logic                    ren, ren_r;

  logic [BLEN - 1:0]       spifl_rdata;
  logic                    spifl_done;
  logic                    spifl_on;

  spi_flash SPI_FLASH(
    .clk      (clk),
    .fl_clk   (fl_clk),
    .nrst     (nrst),
    .fl_addr  (addr_r),
    .fl_ren   (ren_r),
    .fl_rdata (spifl_rdata),
    .fl_done  (spifl_done),
    .fl_on    (spifl_on),
    .miso     (miso),
    .mosi     (mosi),
    .sclk     (sclk),
    .ncs      (ncs)
  );

  /*
   * Input buffering
   */
  always_comb begin
    addr = addr_r;
    sign = sign_r;

    if (state_r == ST_IDLE) begin
      addr = asw_addr;
      sign = !asw_nsign;
    end
  end

  always_ff @(posedge clk) begin
    addr_r <= addr;
    sign_r <= sign;
  end

  /*
   * Reading
   */
  always_comb
    if (sign_r && rdata_r[BLEN - 1])
      asw_rdata = {{XLEN - BLEN{1'b1}}, rdata_r};
    else
      asw_rdata = rdata_r;

  always_comb begin
    rdata = rdata_r;
    ren   = ren_r;

    unique0 case (state_r)
      ST_READ:
        if (spifl_on)
          ren = 1;

      ST_READ_WAIT: begin
        if (spifl_done)
          rdata = spifl_rdata;

        ren = 0;
      end
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      ren_r <= 0;
    else begin
      rdata_r <= rdata;
      ren_r   <= ren;
    end

  /*
   * State transitions
   */
  always_comb begin
    state = state_r;

    unique0 case (state_r)
      ST_IDLE:
        if (asw_ren)
          state = ST_READ;

      ST_READ:
        if (spifl_on)
          state = ST_READ_WAIT;

      ST_READ_WAIT:
        if (spifl_done)
          state = ST_FINISH;

      ST_FINISH:
        state = ST_IDLE;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      state_r <= ST_IDLE;
    else
      state_r <= state;

  /*
   * Other application switch signals
   */
  assign asw_stall = state_r != ST_FINISH;
endmodule
