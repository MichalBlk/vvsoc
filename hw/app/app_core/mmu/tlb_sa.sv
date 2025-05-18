`default_nettype none

`include "isa.svh"

module tlb_sa
  import isa_pkg::*;
#(
  parameter  SETCNT      = 4,
  parameter  LINECNT     = 4,

  localparam SETCNT_LOG  = $clog2(SETCNT),
  localparam LINECNT_LOG = $clog2(LINECNT),
  localparam TAGLEN      = XLEN - SETCNT_LOG
)(
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
  logic [PTELEN - 1:0]      line_pte [SETCNT - 1:0][LINECNT - 1:0],
    line_pte_r [SETCNT - 1:0][LINECNT - 1:0];
  logic [ASIDLEN - 1:0]     line_asid [SETCNT - 1:0][LINECNT - 1:0],
    line_asid_r [SETCNT - 1:0][LINECNT - 1:0];
  logic [TAGLEN - 1:0]      line_tag [SETCNT - 1:0][LINECNT - 1:0],
    line_tag_r [SETCNT - 1:0][LINECNT - 1:0];
  logic [LINECNT - 1:0]     line_sp [SETCNT - 1: 0], line_sp_r [SETCNT - 1:0];
  logic [LINECNT - 1:0]     line_valid [SETCNT - 1:0], line_valid_r [SETCNT - 1:0];
  logic [LINECNT_LOG - 1:0] line_nxt [SETCNT - 1:0], line_nxt_r [SETCNT - 1:0];

  logic [TAGLEN - 1:0]      tag;
  logic [SETCNT_LOG - 1:0]  set_idx;

  assign {tag, set_idx} = mmu_vpn;

  /*
   * Reading
   */
  always_comb begin
    mmu_rpte  = 'bx;
    mmu_rsp   = 'bx;
    mmu_valid = 0;

    for (int i = 0; i < LINECNT; i++) begin
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
  logic [LINECNT_LOG - 1:0] free_idx;
  logic [LINECNT_LOG - 1:0] line_idx;
  logic                     free;

  always_comb begin
    free_idx = 'bx;
    free     = 0;

    for (int i = 0; i < LINECNT; i++) begin
      if (!line_valid_r[set_idx][i]) begin
        free_idx = i;
        free     = 1;
      end
    end
  end

  assign line_idx = free ? free_idx : line_nxt_r[set_idx];

  always_comb begin
    for (int i = 0; i < SETCNT; i++) begin
      for (int j = 0; j < LINECNT; j++) begin
        line_pte[i][j]  = line_pte_r[i][j];
        line_asid[i][j] = line_asid_r[i][j];
        line_tag[i][j]  = line_tag_r[i][j];
      end

      line_sp[i]    = line_sp_r[i];
      line_valid[i] = line_valid_r[i];
      line_nxt[i]   = line_nxt_r[i];
    end

    unique0 if (mmu_wen) begin
      if (!free)
        line_nxt[set_idx] = line_nxt[set_idx] + 1;

      line_pte[set_idx][line_idx]   = mmu_wpte;
      line_asid[set_idx][line_idx]  = mmu_asid;
      line_tag[set_idx][line_idx]   = tag;
      line_sp[set_idx][line_idx]    = mmu_wsp;
      line_valid[set_idx][line_idx] = 1;
    end else if (mmu_flush) begin
      for (int i = 0; i < SETCNT; i++)
        line_valid[i] = 0;
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      for (int i = 0; i < SETCNT; i++) begin
        line_valid_r[i] <= 0;
        line_nxt_r[i]   <= 0;
      end
    end else begin
      for (int i = 0; i < SETCNT; i++) begin
        for (int j = 0; j < LINECNT; j++) begin
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
