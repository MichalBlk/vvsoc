`include "isa.svh"

module tlb_dm
  import isa_pkg::*;
#(
  parameter  SETCNT     = 16,

  localparam SETCNT_LOG = $clog2(SETCNT),
  localparam TAGLEN     = XLEN - SETCNT_LOG
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
`default_nettype none

  logic [PTELEN - 1:0]     line_pte [SETCNT - 1:0], line_pte_r [SETCNT - 1:0];
  logic [ASIDLEN - 1:0]    line_asid [SETCNT - 1:0], line_asid_r [SETCNT - 1:0];
  logic [TAGLEN - 1:0]     line_tag [SETCNT - 1:0], line_tag_r [SETCNT - 1:0];
  logic [SETCNT - 1:0]     line_sp, line_sp_r;
  logic [SETCNT - 1:0]     line_valid, line_valid_r;

  logic [TAGLEN - 1:0]     tag;
  logic [SETCNT_LOG - 1:0] idx;

  assign {tag, idx} = mmu_vpn;

  /*
   * Reading
   */
  assign mmu_rpte  = line_pte_r[idx];
  assign mmu_rsp   = line_sp_r[idx];
  assign mmu_valid = line_valid_r[idx] && line_tag_r[idx] == tag &&
    (line_asid_r[idx] == mmu_asid || line_pte_r[idx][PTE_GSH]);

  /*
   * Writing
   */
  always_comb begin
    for (int i = 0; i < SETCNT; i++) begin
      line_pte[i]  = line_pte_r[i];
      line_asid[i] = line_asid_r[i];
      line_tag[i]  = line_tag_r[i];
    end

    line_sp    = line_sp_r;
    line_valid = line_valid_r;

    if (mmu_wen) begin
      line_pte[idx]   = mmu_wpte;
      line_asid[idx]  = mmu_asid;
      line_tag[idx]   = tag;
      line_sp[idx]    = mmu_wsp;
      line_valid[idx] = 1;
    end else if (mmu_flush)
      line_valid = 0;
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      line_valid_r <= 0;
    else begin
      for (int i = 0; i < SETCNT; i++) begin
        line_pte_r[i]  <= line_pte[i];
        line_asid_r[i] <= line_asid[i];
        line_tag_r[i]  <= line_tag[i];
      end

      line_sp_r    <= line_sp;
      line_valid_r <= line_valid;
    end
endmodule
