`default_nettype none

`include "isa.svh"
`include "soc.svh"

module icache
  import isa_pkg::*;
  import param_pkg::*;
  import soc_pkg::*;
(
  input  logic                       clk,
  input  logic                       nrst,

  input  logic [XLEN - 1:0]          mmu_addr,
  input  logic [CACHE_LINELEN - 1:0] mmu_wdata,
  input  logic                       mmu_wen,
  input  logic                       mmu_flush,
  output logic [XLEN - 1:0]          mmu_rdata,
  output logic [XLEN - 1:0]          mmu_nxt_rdata,
  output logic                       mmu_hit,
  output logic                       mmu_nxt_valid
);
  parameter TAGLEN = XLEN - CACHE_OFFSETLEN + 1;

  logic [CACHE_LINELEN - 1:0]     line_data, line_data_r;
  logic [TAGLEN  - 1:0]           line_tag, line_tag_r;

  logic [TAGLEN - 1:0]            tag;
  logic [CACHE_LINELEN_LOG - 1:0] offsetbit;

  assign tag = {1'b0, mmu_addr[CACHE_OFFSETLEN+:TAGLEN - 1]};

  /*
   * Reading
   */
  assign offsetbit = mmu_addr[0+:CACHE_OFFSETLEN] << BLEN_LOG;

  always_comb begin
    mmu_rdata     = 'bx;
    mmu_nxt_rdata = 'bx;

    for (int i = 0; i < CACHE_LINELEN; i += XLEN)
      if (offsetbit == i)
        mmu_rdata = line_data_r[i+:XLEN];

    for (int i = 0; i < CACHE_LINELEN - XLEN; i += XLEN)
      if (offsetbit == i)
        mmu_nxt_rdata = line_data_r[i + XLEN+:XLEN];
  end

  assign mmu_hit       = line_tag_r == tag;
  assign mmu_nxt_valid = mmu_hit && offsetbit != CACHE_LINELEN - XLEN;

  /*
   * Writing
   */
  always_comb begin
    line_data = line_data_r;
    line_tag  = line_tag_r;

    unique0 if (mmu_wen) begin
      line_data = mmu_wdata;
      line_tag  = tag;
    end else if (mmu_flush)
      line_tag = {TAGLEN{1'b1}};
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      line_tag_r <= {TAGLEN{1'b1}};
    else begin
      line_data_r <= line_data;
      line_tag_r  <= line_tag;
    end
endmodule
