`default_nettype none

`include "isa_pkg.svh"
`include "soc_pkg.svh"

module tlb
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                 clk,
  input  logic                 nrst,

  input  logic [PNLEN - 1:0]   mmu_vpn,
  input  logic [ASIDLEN - 1:0] mmu_asid,
  input  logic [PTELEN - 1:0]  mmu_wpte,
  input  logic                 mmu_wsp,
  input  logic                 mmu_wen,
  input  logic                 mmu_flush,
  output logic [PTELEN - 1:0]  mmu_rpte,
  output logic                 mmu_rsp,
  output logic                 mmu_valid
);
  logic [PTELEN - 1:0]          line_pte [TLB_SETCNT - 1:0][TLB_LINECNT - 1:0],
    line_pte_r [TLB_SETCNT - 1:0][TLB_LINECNT - 1:0];
  logic [ASIDLEN - 1:0]         line_asid [TLB_SETCNT - 1:0][TLB_LINECNT - 1:0],
    line_asid_r [TLB_SETCNT - 1:0][TLB_LINECNT - 1:0];
  logic [TLB_TAGLEN - 1:0]      line_tag [TLB_SETCNT - 1:0][TLB_LINECNT - 1:0],
    line_tag_r [TLB_SETCNT - 1:0][TLB_LINECNT - 1:0];
  logic [TLB_LINECNT - 1:0]     line_sp [TLB_SETCNT - 1: 0], line_sp_r [TLB_SETCNT - 1:0];
  logic [TLB_LINECNT - 1:0]     line_valid [TLB_SETCNT - 1:0], line_valid_r [TLB_SETCNT - 1:0];
  logic [TLB_LINECNT_LOG - 1:0] line_nxt [TLB_SETCNT - 1:0], line_nxt_r [TLB_SETCNT - 1:0];

  logic [TLB_TAGLEN - 1:0]      tag;
  logic [TLB_SETCNT_LOG - 1:0]  set_idx;

  assign {tag, set_idx} = mmu_vpn;

  /*
   * Reading
   */
  always_comb begin
    mmu_rpte  = 'bx;
    mmu_rsp   = 'bx;
    mmu_valid = 0;

    for (int i = 0; i < TLB_LINECNT; i++) begin
      if (line_valid_r[set_idx][i] && line_tag_r[set_idx][i] == tag &&
        (line_asid_r[set_idx][i] == mmu_asid || line_pte_r[set_idx][i][PTE_GSH])) begin
        mmu_rpte  = line_pte_r[set_idx][i];
        mmu_rsp   = line_sp_r[set_idx][i];
        mmu_valid = 1;
      end
    end
  end

  /*
   * Writing
   */
  logic [TLB_LINECNT_LOG - 1:0] free_idx;
  logic [TLB_LINECNT_LOG - 1:0] line_idx;
  logic                         free;

  always_comb begin
    free_idx = 'bx;
    free     = 0;

    for (int i = 0; i < TLB_LINECNT; i++) begin
      if (!line_valid_r[set_idx][i]) begin
        free_idx = i;
        free     = 1;
      end
    end
  end

  assign line_idx = free ? free_idx : line_nxt_r[set_idx];

  always_comb begin
    for (int i = 0; i < TLB_SETCNT; i++) begin
      for (int j = 0; j < TLB_LINECNT; j++) begin
        line_pte[i][j]  = line_pte_r[i][j];
        line_asid[i][j] = line_asid_r[i][j];
        line_tag[i][j]  = line_tag_r[i][j];
      end

      line_sp[i]    = line_sp_r[i];
      line_valid[i] = line_valid_r[i];
      line_nxt[i]   = line_nxt_r[i];
    end

    if (mmu_wen) begin
      if (!free)
        line_nxt[set_idx] = line_nxt[set_idx] + 1;

      line_pte[set_idx][line_idx]   = mmu_wpte;
      line_asid[set_idx][line_idx]  = mmu_asid;
      line_tag[set_idx][line_idx]   = tag;
      line_sp[set_idx][line_idx]    = mmu_wsp;
      line_valid[set_idx][line_idx] = 1;
    end else if (mmu_flush) begin
      for (int i = 0; i < TLB_SETCNT; i++)
        line_valid[i] = 0;
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      for (int i = 0; i < TLB_SETCNT; i++) begin
        line_valid_r[i] <= 0;
        line_nxt_r[i]   <= 0;
      end
    end else begin
      for (int i = 0; i < TLB_SETCNT; i++) begin
        for (int j = 0; j < TLB_LINECNT; j++) begin
          line_pte_r[i][j]  <= line_pte[i][j];
          line_asid_r[i][j] <= line_asid[i][j];
          line_tag_r[i][j]  <= line_tag[i][j];
        end

        line_sp_r[i]    <= line_sp[i];
        line_valid_r[i] <= line_valid[i];
        line_nxt_r[i]   <= line_nxt[i];
      end
    end
endmodule
