`default_nettype none

`include "isa_pkg.svh"
`include "soc_pkg.svh"

module mmu
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                   clk,
  input  logic                   nrst,

  input  logic [XLEN - 1:0]      ac_vaddr,
  input  logic [XLEN - 1:0]      ac_wdata,
  input  logic [XLENB_LOG - 1:0] ac_size,
  input  logic                   ac_nsign,
  input  access_t                ac_access,
  input  priv_t                  ac_priv,
  input  logic [XLEN - 1:0]      ac_mstatus,
  input  logic [XLEN - 1:0]      ac_satp,
  input  logic                   ac_tlb_flush,
  output logic [XLEN - 1:0]      ac_rdata,
  output exc_t                   ac_exc_code,
  output logic                   ac_exc_pending,
  output logic                   ac_stall,

  input  logic [XLEN - 1:0]      asw_rdata,
  input  logic                   asw_stall,
  output logic [XLEN - 1:0]      asw_addr,
  output logic [XLEN - 1:0]      asw_wdata,
  output logic [XLENB_LOG - 1:0] asw_size,
  output logic                   asw_nsign,
  output logic                   asw_ren,
  output logic                   asw_wen
);
  typedef enum logic [2:0] {
    ST_TLB,
    ST_L1,
    ST_L0,
    ST_UPDATE,
    ST_ACCESS
  } state_t;

  state_t              state, state_r;

  priv_t               priv;
  logic                omit_translation;
  logic [XLEN - 1:0]   l1_pte, l1_pte_r;
  logic [PTELEN - 1:0] pte, pte_r;
  logic [2:0]          xwr, exwr;
  logic                sp, sp_r;
  logic [XLEN - 1:0]   paddr, paddr_r;

  logic [PTELEN - 1:0] tlb_rpte;
  logic                tlb_rsp;
  logic                tlb_valid;
  logic                tlb_wen;

  assign priv             = 
    ac_priv == PRIV_M && ac_mstatus[MSTATUS_MPRVSH] && ac_access != ACC_FETCH ?
    priv_t'(ac_mstatus[MSTATUS_MPPSH+:PRIVLEN]) : ac_priv;

  assign omit_translation = !ac_satp[SATP_MODESH] || priv == PRIV_M;

  /*
   * TLB stage
   */
  logic [PNLEN - 1:0]   tlb_vpn;
  logic [ASIDLEN - 1:0] tlb_asid;

  assign tlb_vpn  = ac_vaddr[VADDR_VPN0SH+:PNLEN];
  assign tlb_asid = ac_satp[SATP_ASIDSH+:ASIDLEN];

  tlb_sa #(
    .SETCNT  (TLB_SETCNT),
    .LINECNT (TLB_LINECNT)
  ) TLB(
    .clk       (clk),
    .nrst      (nrst),
    .mmu_vpn   (tlb_vpn),
    .mmu_asid  (tlb_asid),
    .mmu_wpte  (pte_r),
    .mmu_wsp   (sp_r),
    .mmu_wen   (tlb_wen),
    .mmu_flush (ac_tlb_flush),
    .mmu_rpte  (tlb_rpte),
    .mmu_rsp   (tlb_rsp),
    .mmu_valid (tlb_valid)
  );

  /*
   * PTE computation
   */
  assign xwr = {pte[PTE_XSH], pte[PTE_WSH], pte[PTE_RSH]};

  always_comb begin
    exwr = xwr;

    if (ac_mstatus[MSTATUS_MXRSH])
      exwr[0] |= xwr[2];
  end

  always_comb begin
    pte = pte_r;
    sp  = sp_r;

    if (!asw_stall)
      case (state_r)
        ST_TLB: begin
          pte = tlb_rpte;
          sp  = tlb_rsp;
        end

        ST_L1: begin
          l1_pte = asw_rdata;
          pte    = asw_rdata;
          sp     = xwr != 0;
        end

        ST_L0: begin
          pte = asw_rdata;
          sp  = 0;
        end
      endcase
  end

  always_ff @(posedge clk) begin
    l1_pte_r <= l1_pte;
    pte_r    <= pte;
    sp_r     <= sp;
  end

  /*
   * PA computation
   */
  logic [SPNLEN - 1:0] spn;
  logic [PNLEN - 1:0]  pn;

  assign spn = pte[PTE_PPN1SH+:SPNLEN];
  assign pn  = pte[PTE_PPN0SH+:PNLEN];

  always_comb begin
    paddr = paddr_r;

    if (!asw_stall) begin
      if (state_r == ST_TLB && omit_translation)
        paddr = ac_vaddr;
      else if (sp)
        paddr = {spn, ac_vaddr[0+:SUPERPAGESZ_LOG]};
      else
        paddr = {pn, ac_vaddr[0+:PAGESZ_LOG]};
    end
  end

  always_ff @(posedge clk)
    paddr_r <= paddr;

  /*
   * Update stage
   */
  assign tlb_wen = state_r == ST_UPDATE && !asw_stall;

  /*
   * Exception detection
   */
  logic valid;
  logic xwr_resv;
  logic sp_unaligned;
  logic ill;

  assign valid        = pte[PTE_VSH];
  assign xwr_resv     = xwr == PTE_XWR_RESV0 || xwr == PTE_XWR_RESV1;
  assign sp_unaligned = pte[PTE_PPN0SH+:PT_ADDRLEN] != 0;
  assign ill          = (exwr & ac_access) != ac_access ||
    (priv == PRIV_S && pte[PTE_USH] && !ac_mstatus[MSTATUS_SUMSH]) ||
    (priv == PRIV_U && !pte[PTE_USH]);

  always_comb begin
    ac_exc_code    = exc_t'('bx);
    ac_exc_pending = 0;

    if (!asw_stall)
      case (state_r)
        ST_TLB:
          ac_exc_pending = ac_access != ACC_NONE && !omit_translation && tlb_valid && ill;

        ST_L1:
          ac_exc_pending = !valid || xwr_resv || (sp && (sp_unaligned || ill));

        ST_L0:
          ac_exc_pending = !valid || xwr_resv || !xwr || ill;
      endcase

    if (ac_exc_pending)
      case (ac_access)
        ACC_LOAD:  ac_exc_code = CAUSE_LOAD_PAGE_FAULT;
        ACC_STORE: ac_exc_code = CAUSE_STORE_AMO_PAGE_FAULT;
        ACC_FETCH: ac_exc_code = CAUSE_FETCH_PAGE_FAULT;
      endcase
  end

  /*
   * State transitions
   */
  always_comb begin
    state = state_r;

    if (!asw_stall) begin
      if (state_r == ST_ACCESS)
        state = ST_TLB;
      else if (ac_exc_pending)
        state = ST_TLB;
      else if (state_r == ST_TLB) begin
        if (ac_access != ACC_NONE) begin
          if (omit_translation || tlb_valid)
            state = ST_ACCESS;
          else
            state = ST_L1;
        end
      end else if (state_r == ST_L1 && sp)
        state = ST_UPDATE;
      else
        state = state_t'(state + 1);
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      state_r <= ST_TLB;
    else
      state_r <= state;

  /*
   * Application core signals
   */
  assign ac_rdata = asw_rdata;
  assign ac_stall = state != ST_TLB;

  /*
   * Application switch signals
   */
  logic [XLEN - 1:0]   l1_pte_addr;
  logic [XLEN - 1:0]   l0_pte_addr;
  logic [PTELEN - 1:0] updated_pte;
  logic                needs_update;

  assign l1_pte_addr  = {ac_satp[SATP_PPNSH+:PNLEN], ac_vaddr[VADDR_VPN1SH+:PT_ADDRLEN],
    {PTELENB_LOG{1'b0}}};

  assign l0_pte_addr  = {l1_pte_r[PTE_PPN0SH+:PNLEN], ac_vaddr[VADDR_VPN0SH+:PT_ADDRLEN],
    {PTELENB_LOG{1'b0}}};

  assign updated_pte  = pte_r | (1 << PTE_ASH) | ((ac_access == ACC_STORE) << PTE_DSH);
  assign needs_update = !pte_r[PTE_ASH] || (ac_access == ACC_STORE && !pte_r[PTE_DSH]);

  always_comb begin
    asw_addr  = 'bx;
    asw_wdata = 'bx;
    asw_size  = 'bx;
    asw_ren   = 0;
    asw_wen   = 0;

    case (state_r)
      ST_L1: begin
        asw_addr = l1_pte_addr;
        asw_size = PTELENB_LOG;
        asw_ren  = 1;
      end

      ST_L0: begin
        asw_addr = l0_pte_addr;
        asw_size = PTELENB_LOG;
        asw_ren  = 1;
      end

      ST_UPDATE: begin
        if (sp_r)
          asw_addr  = l1_pte_addr;
        else
          asw_addr  = l0_pte_addr;
        asw_wdata = updated_pte;
        asw_size  = PTELENB_LOG;
        asw_wen   = needs_update;
      end

      ST_ACCESS: begin
        asw_addr  = paddr_r;
        asw_wdata = ac_wdata;
        asw_size  = ac_size;
        asw_ren   = ac_access != ACC_STORE;
        asw_wen   = ac_access == ACC_STORE;
      end
    endcase
  end

  assign asw_nsign = ac_nsign;
endmodule
