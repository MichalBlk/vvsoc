`default_nettype none

`include "isa.svh"
`include "soc.svh"

module main_memory
  import isa_pkg::*;
  import soc_pkg::*;
  import board_pkg::*;
(
  input  logic                      clk,
  input  logic                      dram_clk,
  input  logic                      nrst,

  input  logic [MMEM_ADDRLEN - 1:0] cache_addr,
  input  logic [MMEM_DATALEN - 1:0] cache_wdata,
  input  logic                      cache_ren,
  input  logic                      cache_wen,
  output logic [MMEM_DATALEN - 1:0] cache_rdata,
  output logic                      cache_stall,

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
  logic [MMEM_DATALEN - 1:0] rdata, rdata_r;
  logic [MMEM_DATALEN - 1:0] wdata, wdata_r;
  logic                      ren, ren_r;
  logic                      wen, wen_r;

  logic [MMEM_DATALEN - 1:0] dram_rdata;
  logic                      dram_done;
  logic                      dram_on;

  dram DRAM(
    .clk        (clk),
    .dram_clk   (dram_clk),
    .nrst       (nrst),
    .mmem_addr  (addr_r),
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
    addr  = addr_r;
    wdata = wdata_r;

    if (state_r == ST_IDLE) begin
      addr  = cache_addr;
      wdata = cache_wdata;
    end
  end

  always_ff @(posedge clk) begin
    addr_r  <= addr;
    wdata_r <= wdata;
  end

  /*
   * Reading
   */
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
    wen = wen_r;

    unique0 case (state_r)
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
    else
      wen_r <= wen;

  /*
   * State transitions
   */
  always_comb begin
    state = state_r;

    unique0 case (state_r)
      ST_IDLE:
        if (cache_ren)
          state = ST_READ;
        else if (cache_wen)
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
   * Cache signals
   */
  assign cache_rdata = rdata_r;
  assign cache_stall = state_r != ST_FINISH;
endmodule
