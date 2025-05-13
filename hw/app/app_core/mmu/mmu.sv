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
    ST_ACCESS,
    ST_FINISH
  } state_t;

  state_t              state, state_r;

  priv_t               priv;
  logic                omit_translation;
  logic [2:0]          tlb_xwr, tlb_exwr;
  logic [XLEN - 1:0]   l1_pte, l1_pte_r;
  logic [2:0]          l1_xwr, l1_exwr;
  logic [PTELEN - 1:0] l1_updated_pte;
  logic                l1_needs_update;
  logic                l1_sp;
  logic                l1_exc_pending;
  logic [XLEN - 1:0]   l0_pte, l0_pte_r;
  logic [2:0]          l0_xwr, l0_exwr;
  logic [PTELEN - 1:0] l0_updated_pte;
  logic                l0_needs_update;
  logic                l0_exc_pending;
  logic [XLEN - 1:0]   paddr, paddr_r;
  logic                sp, sp_r;
  logic [XLEN - 1:0]   data, data_r;
  exc_t                exc_code, exc_code_r;
  logic                exc_pending, exc_pending_r;

  logic [XLEN - 1:0]   tlb_wpte;
  logic                tlb_wen;
  logic [PTELEN - 1:0] tlb_rpte;
  logic                tlb_rsp;
  logic                tlb_valid;

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
    .mmu_wpte  (tlb_wpte),
    .mmu_wsp   (sp_r),
    .mmu_wen   (tlb_wen),
    .mmu_flush (ac_tlb_flush),
    .mmu_rpte  (tlb_rpte),
    .mmu_rsp   (tlb_rsp),
    .mmu_valid (tlb_valid)
  );

  assign tlb_xwr = {tlb_rpte[PTE_XSH], tlb_rpte[PTE_WSH], tlb_rpte[PTE_RSH]};

  always_comb begin
    tlb_exwr = tlb_xwr;

    if (ac_mstatus[MSTATUS_MXRSH])
      tlb_exwr[0] |= tlb_xwr[2];
  end

  /*
   * L1 stage
   */
  assign l1_xwr = {l1_pte[PTE_XSH], l1_pte[PTE_WSH], l1_pte[PTE_RSH]};

  always_comb begin
    l1_exwr = l1_xwr;

    if (ac_mstatus[MSTATUS_MXRSH])
      l1_exwr[0] |= l1_xwr[2];
  end

  assign l1_sp = l1_xwr != 0;

  always_comb begin
    l1_pte = l1_pte_r;

    if (state_r == ST_L1)
      l1_pte = asw_rdata;
  end

  always_ff @(posedge clk)
    l1_pte_r <= l1_pte;

  /*
   * L0 stage
   */
  assign l0_xwr = {l0_pte[PTE_XSH], l0_pte[PTE_WSH], l0_pte[PTE_RSH]};

  always_comb begin
    l0_exwr = l0_xwr;

    if (ac_mstatus[MSTATUS_MXRSH])
      l0_exwr[0] |= l0_xwr[2];
  end

  always_comb begin
    l0_pte = l0_pte_r;

    if (state_r == ST_L0)
      l0_pte = asw_rdata;
  end

  always_ff @(posedge clk)
    l0_pte_r <= l0_pte;

  /*
   * Superpage detection
   */
  always_comb begin
    sp = sp_r;

    unique0 case (state_r)
      ST_TLB: sp = tlb_rsp;
      ST_L1:  sp = l1_sp;
      ST_L0:  sp = 0;
    endcase
  end

  always_ff @(posedge clk)
    sp_r <= sp;

  /*
   * Update stage
   */
  assign tlb_wpte        = sp_r ? l1_pte_r : l0_pte_r;
  assign tlb_wen         = state_r == ST_UPDATE;

  assign l1_updated_pte  = l1_pte_r | (1 << PTE_ASH) | ((ac_access == ACC_STORE) << PTE_DSH);
  assign l1_needs_update = !l1_pte_r[PTE_ASH] || (ac_access == ACC_STORE && !l1_pte_r[PTE_DSH]);

  assign l0_updated_pte  = l0_pte_r | (1 << PTE_ASH) | ((ac_access == ACC_STORE) << PTE_DSH);
  assign l0_needs_update = !l0_pte_r[PTE_ASH] || (ac_access == ACC_STORE && !l0_pte_r[PTE_DSH]);

  /*
   * PA computation
   */
  logic [SPNLEN - 1:0] tlb_spn;
  logic [SPNLEN - 1:0] l1_spn;
  logic [PNLEN - 1:0]  tlb_pn;
  logic [PNLEN - 1:0]  l0_pn;

  assign tlb_spn = tlb_rpte[PTE_PPN1SH+:SPNLEN];
  assign l1_spn  = l1_pte[PTE_PPN1SH+:SPNLEN];
  assign tlb_pn  = tlb_rpte[PTE_PPN0SH+:PNLEN];
  assign l0_pn   = l0_pte[PTE_PPN0SH+:PNLEN];

  always_comb begin
    paddr = paddr_r;

    unique0 case (state_r)
      ST_TLB:
        if (omit_translation)
          paddr = ac_vaddr;
        else if (tlb_rsp)
          paddr = {tlb_spn, ac_vaddr[0+:SUPERPAGESZ_LOG]};
        else
          paddr = {tlb_pn, ac_vaddr[0+:PAGESZ_LOG]};

      ST_L1:
        paddr = {l1_spn, ac_vaddr[0+:SUPERPAGESZ_LOG]};

      ST_L0:
        paddr = {l0_pn, ac_vaddr[0+:PAGESZ_LOG]};
    endcase
  end

  always_ff @(posedge clk)
    paddr_r <= paddr;

  /*
   * Access stage
   */
  always_comb begin
    data = data_r;

    if (state_r == ST_ACCESS)
      data = asw_rdata;
  end

  always_ff @(posedge clk)
    data_r <= data;

  /*
   * Exception detection
   */
  logic tlb_ill;
  logic l1_valid;
  logic l1_xwr_resv;
  logic l1_sp_unaligned;
  logic l1_ill;
  logic l0_valid;
  logic l0_xwr_resv;
  logic l0_sp_unaligned;
  logic l0_ill;

  assign tlb_ill         = (tlb_exwr & ac_access) != ac_access ||
    (priv == PRIV_S && tlb_rpte[PTE_USH] && !ac_mstatus[MSTATUS_SUMSH]) ||
    (priv == PRIV_U && !tlb_rpte[PTE_USH]);

  assign l1_valid        = l1_pte[PTE_VSH];
  assign l1_xwr_resv     = l1_xwr == PTE_XWR_RESV0 || l1_xwr == PTE_XWR_RESV1;
  assign l1_sp_unaligned = l1_pte[PTE_PPN0SH+:PT_ADDRLEN] != 0;
  assign l1_ill          = (l1_exwr & ac_access) != ac_access ||
    (priv == PRIV_S && l1_pte[PTE_USH] && !ac_mstatus[MSTATUS_SUMSH]) ||
    (priv == PRIV_U && !l1_pte[PTE_USH]);
  assign l1_exc_pending  = !l1_valid || l1_xwr_resv || (l1_sp && (l1_sp_unaligned || l1_ill));

  assign l0_valid        = l0_pte[PTE_VSH];
  assign l0_xwr_resv     = l0_xwr == PTE_XWR_RESV0 || l0_xwr == PTE_XWR_RESV1;
  assign l0_ill          = (l0_exwr & ac_access) != ac_access ||
    (priv == PRIV_S && l0_pte[PTE_USH] && !ac_mstatus[MSTATUS_SUMSH]) ||
    (priv == PRIV_U && !l0_pte[PTE_USH]);
  assign l0_exc_pending  = !l0_valid || l0_xwr_resv || !l0_xwr || l0_ill;

  always_comb begin
    exc_code    = exc_code_r;
    exc_pending = exc_pending_r;

    unique0 case (state_r)
      ST_TLB:    exc_pending = tlb_ill;
      ST_L1:     exc_pending = l1_exc_pending;
      ST_L0:     exc_pending = l0_exc_pending;
      ST_ACCESS: exc_pending = 0;
    endcase

    if (state_r == ST_TLB || state_r == ST_L1 || state_r == ST_L0)
      unique0 case (ac_access)
        ACC_LOAD:  exc_code = CAUSE_LOAD_PAGE_FAULT;
        ACC_STORE: exc_code = CAUSE_STORE_AMO_PAGE_FAULT;
        ACC_FETCH: exc_code = CAUSE_FETCH_PAGE_FAULT;
      endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      exc_pending_r <= 0;
    else begin
      exc_code_r    <= exc_code;
      exc_pending_r <= exc_pending;
    end

  /*
   * State transitions
   */
  always_comb begin
    state = state_r;

    if (state_r == ST_TLB) begin
      if (ac_access != ACC_NONE) begin
        if (omit_translation)
          state = ST_ACCESS;
        else if (tlb_valid)
          state = tlb_ill ? ST_FINISH : ST_ACCESS;
        else
          state = ST_L1;
      end
    end else if (state_r == ST_FINISH)
      state = ST_TLB;
    else if (!asw_stall) begin
      state = state_t'(state_r + 1);

      unique0 case (state_r)
        ST_L1:
          if (l1_exc_pending)
            state = ST_FINISH;
          else
            state = l1_sp ? ST_UPDATE : ST_L0;

        ST_L0:
          state = l0_exc_pending ? ST_FINISH : ST_UPDATE;
      endcase
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      state_r <= ST_TLB;
    else
      state_r <= state;

  /*
   * Other application core signals
   */
  assign ac_rdata       = data_r;
  assign ac_exc_code    = exc_code_r;
  assign ac_exc_pending = exc_pending_r;
  assign ac_stall       = state_r != ST_FINISH;

  /*
   * Application switch signals
   */
  logic [XLEN - 1:0] l1_pte_addr;
  logic [XLEN - 1:0] l0_pte_addr;

  assign l1_pte_addr = {ac_satp[SATP_PPNSH+:PNLEN], ac_vaddr[VADDR_VPN1SH+:PT_ADDRLEN],
    {PTELENB_LOG{1'b0}}};

  assign l0_pte_addr = {l1_pte_r[PTE_PPN0SH+:PNLEN], ac_vaddr[VADDR_VPN0SH+:PT_ADDRLEN],
    {PTELENB_LOG{1'b0}}};

  always_comb begin
    asw_addr  = 'bx;
    asw_wdata = 'bx;
    asw_size  = 'bx;
    asw_ren   = 0;
    asw_wen   = 0;

    unique0 case (state_r)
      ST_TLB, ST_FINISH:
        asw_addr = 0;

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
        if (sp_r) begin
          asw_addr  = l1_pte_addr;
          asw_wdata = l1_updated_pte;
          asw_wen   = l1_needs_update;
        end else begin
          asw_addr  = l0_pte_addr;
          asw_wdata = l0_updated_pte;
          asw_wen   = l0_needs_update;
        end
        asw_size = PTELENB_LOG;
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
