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
  input  logic                      dram_clk,
  input  logic                      nrst,

  input  logic [MMEM_ADDRLEN - 1:0] msw_addr,
  input  logic [XLEN - 1:0]         msw_wdata,
  input  logic [XLENB_LOG - 1:0]    msw_size,
  input  logic                      msw_nsign,
  input  logic                      msw_ren,
  input  logic                      msw_wen,
  output logic [XLEN - 1:0]         msw_rdata,
  output logic                      msw_stall,

  inout  logic [DDR2_DQLEN - 1:0]   ddr2_dq,
  inout  logic [DDR2_DQSLEN - 1:0]  ddr2_dqs_n,
  inout  logic [DDR2_DQSLEN - 1:0]  ddr2_dqs_p,
  output logic [DDR2_ADDRLEN - 1:0] ddr2_addr,
  output logic [DDR2_BALEN - 1:0]   ddr2_ba,
  output logic                      ddr2_ras_n,
  output logic                      ddr2_cas_n,
  output logic                      ddr2_we_n,
  output logic                      ddr2_ck_p,
  output logic                      ddr2_ck_n,
  output logic                      ddr2_cke,
  output logic                      ddr2_cs_n,
  output logic [DDR2_DMLEN - 1:0]   ddr2_dm,
  output logic                      ddr2_odt
);
  typedef enum logic [2:0] {
    ST_IDLE,
    ST_READ,
    ST_READ_WAIT,
    ST_WRITE,
    ST_WRITE_WAIT,
    ST_FINISH
  } state_t;

  state_t                    state, state_r;
  logic [MMEM_ADDRLEN - 1:0] addr, addr_r;
  logic [XLEN - 1:0]         rdata, rdata_r;
  logic [XLEN - 1:0]         wdata, wdata_r;
  logic [XLENB_LOG - 1:0]    size, size_r;
  logic                      sign, sign_r;
  logic                      ren, ren_r;
  logic                      wen, wen_r;

  logic [XLEN - 1:0]         dram_rdata;
  logic                      dram_done;
  logic                      dram_on;

  dram DRAM(
    .clk        (clk),
    .dram_clk   (dram_clk),
    .nrst       (nrst),
    .mmem_addr  (addr_r),
    .mmem_size  (size_r),
    .mmem_wdata (wdata_r),
    .mmem_ren   (ren_r),
    .mmem_wen   (wen_r),
    .mmem_rdata (dram_rdata),
    .mmem_done  (dram_done),
    .mmem_on    (dram_on),
    .ddr2_addr  (ddr2_addr),
    .ddr2_ba    (ddr2_ba),
    .ddr2_cas_n (ddr2_cas_n),
    .ddr2_ck_n  (ddr2_ck_n),
    .ddr2_ck_p  (ddr2_ck_p),
    .ddr2_cke   (ddr2_cke),
    .ddr2_ras_n (ddr2_ras_n),
    .ddr2_we_n  (ddr2_we_n),
    .ddr2_dq    (ddr2_dq),
    .ddr2_dqs_n (ddr2_dqs_n),
    .ddr2_dqs_p (ddr2_dqs_p),
    .ddr2_cs_n  (ddr2_cs_n),
    .ddr2_dm    (ddr2_dm),
    .ddr2_odt   (ddr2_odt)
  );

  /*
   * Input buffering
   */
  always_comb begin
    addr = addr_r;
    size = size_r;
    sign = sign_r;

    if (state_r == ST_IDLE) begin
      addr = msw_addr;
      size = msw_size;
      sign = !msw_nsign;
    end
  end

  always_ff @(posedge clk) begin
    addr_r <= addr;
    size_r <= size;
    sign_r <= sign;
  end

  /*
   * Reading
   */
  logic [XLEN_LOG:0] sizebit;
  logic [XLEN - 1:0] mask;

  assign sizebit = 1 << (size_r + BLEN_LOG);
  assign mask    = (1 << sizebit) - 1;

  always_comb
    if (sign_r && (rdata_r >> (sizebit - 1)))
      msw_rdata = rdata_r | ~mask;
    else
      msw_rdata = rdata_r & mask;

  always_comb begin
    rdata = rdata_r;
    ren   = ren_r;

    unique0 case (state_r)
      ST_READ:
        if (dram_on)
          ren = 1;

      ST_READ_WAIT: begin
        if (dram_done)
          rdata = dram_rdata;

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
   * Writing
   */ 
  always_comb begin
    wdata = wdata_r;
    wen   = wen_r;

    unique0 case (state_r)
      ST_IDLE:
        wdata = msw_wdata;

      ST_WRITE:
        if (dram_on)
          wen = 1;

      ST_WRITE_WAIT:
        wen = 0;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      wen_r <= 0;
    else begin
      wdata_r <= wdata;
      wen_r   <= wen;
    end

  /*
   * State transitions
   */
  always_comb begin
    state = state_r;

    unique0 case (state_r)
      ST_IDLE:
        if (msw_ren)
          state = ST_READ;
        else if (msw_wen)
          state = ST_WRITE;

      ST_READ:
        if (dram_on)
          state = ST_READ_WAIT;

      ST_READ_WAIT:
        if (dram_done)
          state = ST_FINISH;

      ST_WRITE:
        if (dram_on)
          state = ST_WRITE_WAIT;

      ST_WRITE_WAIT:
        if (dram_done)
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
   * Other main switch signals
   */
  assign msw_stall = state_r != ST_FINISH;
endmodule
