`default_nettype none

`include "isa_pkg.svh"

module mmu
  import isa_pkg::*;
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
  logic                tlb_hit;
  logic [PTELEN - 1:0] l1_pte, l1_pte_r;
  logic [2:0]          l1_xwr, l1_exwr;
  logic                l1_sp;
  logic [PTELEN - 1:0] l0_pte, l0_pte_r;
  logic [2:0]          l0_xwr, l0_exwr;
  logic [XLEN - 1:0]   paddr, paddr_r;
  logic [PNLEN - 1:0]  ppn;
  logic [XLEN - 1:0]   mem_data, mem_data_r;
  exc_t                exc_code, exc_code_r;
  logic                exc_pending, exc_pending_r;

  logic [PNLEN - 1:0]  ltlb_rdata;
  logic                ltlb_wen;
  logic [PNLEN - 1:0]  stlb_rdata;
  logic                stlb_wen;
  logic [PNLEN - 1:0]  ftlb_rdata;
  logic                ftlb_wen;

  /*
   * TLB stage
   */
  logic [PNLEN - 1:0] vpn;
  logic               ltlb_valid;
  logic               stlb_valid;
  logic               ftlb_valid;

  assign priv             =
    ac_priv == PRIV_M && ac_mstatus[MSTATUS_MPRVSH] && ac_access != ACC_FETCH ?
    priv_t'(ac_mstatus[MSTATUS_MPPSH+:PRIVLEN]) : ac_priv;

  assign tlb_hit          = (ac_access == ACC_LOAD && ltlb_valid) ||
    (ac_access == ACC_STORE && stlb_valid) || (ac_access == ACC_FETCH && ftlb_valid);

  assign vpn              = ac_vaddr[VADDR_VPN0SH+:PNLEN];
  assign omit_translation = !ac_satp[SATP_MODESH] || priv == PRIV_M;

  tlb LOAD_TLB(
    .clk       (clk),
    .nrst      (nrst),
    .mmu_vpn   (vpn),
    .mmu_wdata (ppn),
    .mmu_wen   (ltlb_wen),
    .mmu_flush (ac_tlb_flush),
    .mmu_rdata (ltlb_rdata),
    .mmu_valid (ltlb_valid)
  );

  tlb STORE_TLB(
    .clk       (clk),
    .nrst      (nrst),
    .mmu_vpn   (vpn),
    .mmu_wdata (ppn),
    .mmu_wen   (stlb_wen),
    .mmu_flush (ac_tlb_flush),
    .mmu_rdata (stlb_rdata),
    .mmu_valid (stlb_valid)
  );

  tlb FETCH_TLB(
    .clk       (clk),
    .nrst      (nrst),
    .mmu_vpn   (vpn),
    .mmu_wdata (ppn),
    .mmu_wen   (ftlb_wen),
    .mmu_flush (ac_tlb_flush),
    .mmu_rdata (ftlb_rdata),
    .mmu_valid (ftlb_valid)
  );

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

    if (state_r == ST_L1 && !asw_stall)
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

    if (state_r == ST_L0 && !asw_stall)
      l0_pte = asw_rdata;
  end

  always_ff @(posedge clk)
    l0_pte_r <= l0_pte;

  /*
   * Update stage
   */
  assign ltlb_wen = state_r == ST_UPDATE && !asw_stall && ac_access == ACC_LOAD;
  assign stlb_wen = state_r == ST_UPDATE && !asw_stall && ac_access == ACC_STORE;
  assign ftlb_wen = state_r == ST_UPDATE && !asw_stall && ac_access == ACC_FETCH;

  /*
   * Access stage
   */
  always_comb begin
    mem_data = mem_data_r;

    if (state_r == ST_ACCESS && !asw_stall)
      mem_data = asw_rdata;
  end

  always_ff @(posedge clk)
    mem_data_r <= mem_data;

  /*
   * PA computation
   */
  logic [SPNLEN - 1:0] l1_spn;
  logic [PNLEN - 1:0]  l0_pn;

  assign ppn    = paddr_r[PAGESZ_LOG+:PNLEN];

  assign l1_spn = l1_pte[PTE_PPN1SH+:SPNLEN];
  assign l0_pn  = l0_pte[PTE_PPN0SH+:PNLEN];

  always_comb begin
    paddr = paddr_r;

    if (!asw_stall)
      case (state_r)
        ST_TLB:
          if (omit_translation)
            paddr = ac_vaddr;
          else
            case (ac_access)
              ACC_LOAD:
                paddr = {ltlb_rdata, ac_vaddr[0+:PAGESZ_LOG]};

              ACC_STORE:
                paddr = {stlb_rdata, ac_vaddr[0+:PAGESZ_LOG]};

              ACC_FETCH:
                paddr = {ftlb_rdata, ac_vaddr[0+:PAGESZ_LOG]};
            endcase

        ST_L1:
          paddr = {l1_spn, ac_vaddr[0+:SUPERPAGESZ_LOG]};

        ST_L0:
          paddr = {l0_pn, ac_vaddr[0+:PAGESZ_LOG]};
      endcase
  end

  always_ff @(posedge clk)
    paddr_r <= paddr;

  /*
   * Exception detection
   */
  logic l1_valid;
  logic l1_xwr_resv;
  logic l1_sp_unaligned;
  logic l1_ill;
  logic l0_valid;
  logic l0_xwr_resv;
  logic l0_ill;

  assign l1_valid        = l1_pte[PTE_VSH];
  assign l1_xwr_resv     = l1_xwr == PTE_XWR_RESV0 || l1_xwr == PTE_XWR_RESV1;
  assign l1_sp_unaligned = l1_pte[PTE_PPN0SH+:PT_ADDRLEN] != 0;
  assign l1_ill          = !(l1_exwr & ac_access) ||
    (priv == PRIV_S && l1_pte[PTE_USH] && !ac_mstatus[MSTATUS_SUMSH]) ||
    (priv == PRIV_U && !l1_pte[PTE_USH]);

  assign l0_valid        = l0_pte[PTE_VSH];
  assign l0_xwr_resv     = l0_xwr == PTE_XWR_RESV0 || l0_xwr == PTE_XWR_RESV1;
  assign l0_ill          = !(l0_exwr & ac_access) ||
    (priv == PRIV_S && l0_pte[PTE_USH] && !ac_mstatus[MSTATUS_SUMSH]) ||
    (priv == PRIV_U && !l0_pte[PTE_USH]);

  always_comb begin
    exc_code    = exc_code_r;
    exc_pending = exc_pending_r;

    if (!asw_stall)
      case (state_r)
        ST_L1:
          exc_pending = !l1_valid || l1_xwr_resv || (l1_sp && (l1_sp_unaligned || l1_ill));

        ST_L0:
          exc_pending = !l0_valid || l0_xwr_resv || !l0_xwr || l0_ill;

        ST_FINISH:
          exc_pending = 0;
      endcase

    if (exc_pending)
      case (ac_access)
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

    if (!asw_stall) begin
      if (state_r == ST_FINISH)
        state = ST_TLB;
      else if (exc_pending)
        state = ST_FINISH;
      else if (state_r == ST_TLB) begin
        if (ac_access != ACC_NONE) begin
          if (omit_translation || tlb_hit)
            state = ST_ACCESS;
          else
            state = ST_L1;
        end
      end else if (state_r == ST_L1 && l1_sp)
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
  assign ac_rdata       = mem_data_r;
  assign ac_exc_code    = exc_code_r;
  assign ac_exc_pending = exc_pending_r;
  assign ac_stall       = state != ST_TLB;

  /*
   * Application switch signals
   */
  logic [XLEN - 1:0]   l1_pte_addr;
  logic [PTELEN - 1:0] l1_updated_pte;
  logic                l1_needs_update;
  logic [XLEN - 1:0]   l0_pte_addr;
  logic [PTELEN - 1:0] l0_updated_pte;
  logic                l0_needs_update;

  assign l1_pte_addr     = {ac_satp[SATP_PPNSH+:PNLEN], ac_vaddr[VADDR_VPN1SH+:PT_ADDRLEN],
    {PTELENB_LOG{1'b0}}};
  assign l1_updated_pte  = l1_pte_r | (1 << PTE_ASH) | ((ac_access == ACC_STORE) << PTE_DSH);
  assign l1_needs_update = !l1_pte_r[PTE_ASH] || (ac_access == ACC_STORE && !l1_pte_r[PTE_DSH]);

  assign l0_pte_addr     = {l1_pte_r[PTE_PPN0SH+:PNLEN], ac_vaddr[VADDR_VPN0SH+:PT_ADDRLEN],
    {PTELENB_LOG{1'b0}}};
  assign l0_updated_pte  = l0_pte_r | (1 << PTE_ASH) | ((ac_access == ACC_STORE) << PTE_DSH);
  assign l0_needs_update = !l0_pte_r[PTE_ASH] || (ac_access == ACC_STORE && !l0_pte_r[PTE_DSH]);

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
        if (l1_sp) begin
          asw_addr  = l1_pte_addr;
          asw_wdata = l1_updated_pte;
          asw_size  = PTELENB_LOG;
          asw_wen   = l1_needs_update;
        end else begin
          asw_addr  = l0_pte_addr;
          asw_wdata = l0_updated_pte;
          asw_size  = PTELENB_LOG;
          asw_wen   = l0_needs_update;
        end
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
