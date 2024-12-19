`default_nettype none

`include "isa_pkg.svh"
`include "soc_pkg.svh"

module tlb
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic               clk,
  input  logic               nrst,

  input  logic [PNLEN - 1:0] mmu_vpn,
  input  logic [PNLEN - 1:0] mmu_wdata,
  input  logic               mmu_wen,
  input  logic               mmu_flush,
  output logic [PNLEN - 1:0] mmu_rdata,
  output logic               mmu_valid
);
  logic [PNLEN - 1:0]        line_ppn [TLB_ECNT - 1:0], line_ppn_r [TLB_ECNT - 1:0];
  logic [TLB_TAGLEN - 1:0]   line_tag [TLB_ECNT - 1:0], line_tag_r [TLB_ECNT - 1:0];
  logic [TLB_ECNT - 1:0]     line_valid, line_valid_r;

  logic [TLB_TAGLEN - 1:0]   tag;
  logic [TLB_ECNT_LOG - 1:0] idx;

  assign {tag, idx} = mmu_vpn;

  /*
   * Reading
   */
  assign mmu_rdata = line_ppn_r[idx];
  assign mmu_valid = line_valid_r[idx] && line_tag_r[idx] == tag;

  /*
   * Writing
   */
  always_comb begin
    for (int i = 0; i < TLB_ECNT; i++) begin
      line_ppn[i] = line_ppn_r[i];
      line_tag[i] = line_tag_r[i];
    end

    line_valid = line_valid_r;

    if (mmu_wen) begin
      line_ppn[idx]   = mmu_wdata;
      line_tag[idx]   = tag;
      line_valid[idx] = 1;
    end else if (mmu_flush)
      line_valid = 0;
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      line_valid_r <= 0;
    else begin
      for (int i = 0; i < TLB_ECNT; i++) begin
        line_ppn_r[i] <= line_ppn[i];
        line_tag_r[i] <= line_tag[i];
      end

      line_valid_r <= line_valid;
    end
endmodule
