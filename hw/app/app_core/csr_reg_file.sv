`default_nettype none

`include "isa_pkg.svh"

module csr_reg_file
  import isa_pkg::*;
(
  input  logic                clk,
  input  logic                nrst,

  input  csr_addr_t           ac_addr,
  input  logic [XLEN - 1:0]   ac_wdata,
  input  logic [XLEN - 1:0]   ac_pc,
  input  logic [XLEN - 1:0]   ac_target_pc,
  input  exc_t                ac_exc_code,
  input  logic                ac_exc_pending,
  input  logic [XLEN - 1:0]   ac_tval,
  input  logic                ac_csr,
  input  logic                ac_mret,
  input  logic                ac_sret,
  input  logic                ac_com,
  input  logic [CNTLEN - 1:0] ac_mtime,
  output logic [XLEN - 1:0]   ac_rdata,
  output priv_t               ac_priv,
  output logic [XLEN - 1:0]   ac_mstatus,
  output logic [XLEN - 1:0]   ac_satp,
  output logic                ac_ill,
  output logic [XLEN - 1:0]   ac_tvec,
  output logic                ac_intr_handling,

  input  logic                clint_intr_pending,

  input  logic                vcd_intr_pending,

  input  logic                vgd_intr_pending
);
  priv_t               priv, priv_r;

  logic [XLEN - 1:0]   mstatus, mstatus_r;
  logic [XLEN - 1:0]   medeleg, medeleg_r;
  logic [XLEN - 1:0]   mideleg, mideleg_r;
  logic [XLEN - 1:0]   mie, mie_r;
  logic [XLEN - 1:0]   mtvec, mtvec_r;
  logic [XLEN - 1:0]   mcounteren, mcounteren_r;
  logic [XLEN - 1:0]   mscratch, mscratch_r;
  logic [XLEN - 1:0]   mepc, mepc_r;
  logic [XLEN - 1:0]   mcause, mcause_r;
  logic [XLEN - 1:0]   mtval, mtval_r;
  logic [XLEN - 1:0]   mip, mip_r;

  logic [XLEN - 1:0]   stvec, stvec_r;
  logic [XLEN - 1:0]   scounteren, scounteren_r;
  logic [XLEN - 1:0]   sscratch, sscratch_r;
  logic [XLEN - 1:0]   sepc, sepc_r;
  logic [XLEN - 1:0]   scause, scause_r;
  logic [XLEN - 1:0]   stval, stval_r;
  logic [XLEN - 1:0]   satp, satp_r;

  logic [CNTLEN - 1:0] cycle, cycle_r;
  logic [CNTLEN - 1:0] instret, instret_r;

  /*
   * Reading
   */
  logic ill_priv;
  logic ill_addr;
  logic cnt_access;
  logic ill_cnt;

  assign ill_priv = ac_addr[FUNCT12_PRIVSH+:PRIVLEN] > priv_r;

  always_comb begin
    ac_rdata = 'bx;
    ill_addr = 0;

    if (ac_mret)
      ac_rdata = mepc_r;
    else if (ac_sret)
      ac_rdata = sepc_r;
    else
      case (ac_addr)
        CSR_CYCLE:      ac_rdata = cycle_r;
        CSR_TIME:       ac_rdata = ac_mtime;
        CSR_INSTRET:    ac_rdata = instret_r;
        CSR_CYCLEH:     ac_rdata = cycle_r[XLEN+:XLEN];
        CSR_TIMEH:      ac_rdata = ac_mtime[XLEN+:XLEN];
        CSR_INSTRETH:   ac_rdata = instret_r[XLEN+:XLEN];

        CSR_SSTATUS:    ac_rdata = mstatus_r & MSTATUS_SMASK;
        CSR_SIE:        ac_rdata = mie_r & mideleg_r;
        CSR_STVEC:      ac_rdata = stvec_r;
        CSR_SCOUNTEREN: ac_rdata = scounteren_r;
        CSR_SSCRATCH:   ac_rdata = sscratch_r;
        CSR_SEPC:       ac_rdata = sepc_r;
        CSR_SCAUSE:     ac_rdata = scause_r;
        CSR_STVAL:      ac_rdata = stval_r;
        CSR_SIP:        ac_rdata = mip_r & mideleg_r;
        CSR_SATP:       ac_rdata = satp_r;

        CSR_MVENDORID:  ac_rdata = 0;
        CSR_MARCHID:    ac_rdata = 0;
        CSR_MIMPID:     ac_rdata = 0;
        CSR_MHARTID:    ac_rdata = 0;
        CSR_MSTATUS:    ac_rdata = mstatus_r;
        CSR_MISA:       ac_rdata = MISA_VALUE;
        CSR_MEDELEG:    ac_rdata = medeleg_r;
        CSR_MIDELEG:    ac_rdata = mideleg_r;
        CSR_MIE:        ac_rdata = mie_r;
        CSR_MTVEC:      ac_rdata = mtvec_r;
        CSR_MCOUNTEREN: ac_rdata = mcounteren_r;
        CSR_MSTATUSH:   ac_rdata = 0;
        CSR_MSCRATCH:   ac_rdata = mscratch_r;
        CSR_MEPC:       ac_rdata = mepc_r;
        CSR_MCAUSE:     ac_rdata = mcause_r;
        CSR_MTVAL:      ac_rdata = mtval_r;
        CSR_MIP:        ac_rdata = mip_r;
        CSR_MCYCLE:     ac_rdata = cycle_r;
        CSR_MINSTRET:   ac_rdata = instret_r;
        CSR_MCYCLEH:    ac_rdata = cycle_r[XLEN+:XLEN];
        CSR_MINSTRETH:  ac_rdata = instret_r[XLEN+:XLEN];

        default:        ill_addr = 1;
      endcase
  end

  assign cnt_access = ac_addr == CSR_CYCLE || ac_addr == CSR_TIME || ac_addr == CSR_INSTRET ||
     ac_addr == CSR_CYCLEH || ac_addr == CSR_TIMEH || ac_addr == CSR_INSTRETH;

  always_comb
    case (priv_r)
      PRIV_S:  ill_cnt = !(mcounteren_r & (1 << ac_addr[CNTCNT_LOG - 1:0]));
      PRIV_U:  ill_cnt = !((mcounteren_r & scounteren_r) & (1 << ac_addr[CNTCNT_LOG - 1:0]));
      default: ill_cnt = 0;
    endcase

  assign ac_ill = ac_csr && (ill_priv || ill_addr || (cnt_access && ill_cnt));

  /*
   * Completion
   */
  logic [XLEN - 1:0]     pending_intrs;
  logic [XLEN - 1:0]     en_intrs;
  logic [XLEN - 1:0]     active_intrs;
  logic [XLEN_LOG - 1:0] intr_code;
  logic                  intr_deleg;
  logic                  exc_deleg;
  logic [XLEN - 1:0]     trap_m_mstatus;
  logic [XLEN - 1:0]     trap_s_mstatus;
  logic [XLEN - 1:0]     mret_mstatus;
  logic [XLEN - 1:0]     sret_mstatus;
  logic [XLEN - 1:0]     _csr_m_mstatus;
  logic [XLEN - 1:0]     csr_m_mstatus;

  assign pending_intrs = mip_r & mie_r;

  always_comb begin
    en_intrs = 0;

    case (priv_r)
      PRIV_U:
        en_intrs = {XLEN{1'b1}};

      PRIV_S:
        if (mstatus_r[MSTATUS_SIESH])
          en_intrs = {XLEN{1'b1}};
        else
          en_intrs = ~mideleg_r;

      PRIV_M:
        if (mstatus_r[MSTATUS_MIESH])
          en_intrs = ~mideleg_r;
    endcase
  end

  assign active_intrs = pending_intrs & en_intrs;

  always_comb begin
    intr_code = 'bx;

    if (active_intrs[PD0I])
      intr_code = PD0I;
    else if (active_intrs[PD1I])
      intr_code = PD1I;
    else if (active_intrs[MTI])
      intr_code = MTI;
    else if (active_intrs[STI])
      intr_code = STI;
  end

  assign intr_deleg     = priv_r != PRIV_M && ((mideleg_r >> intr_code) & 1);
  assign exc_deleg      = priv_r != PRIV_M && ((medeleg_r >> ac_exc_code) & 1);

  assign _csr_m_mstatus = ac_wdata & MSTATUS_MASK;

  always_comb begin
    trap_m_mstatus                         = mstatus_r;
    trap_s_mstatus                         = mstatus_r;
    mret_mstatus                           = mstatus_r;
    sret_mstatus                           = mstatus_r;
    csr_m_mstatus                          = _csr_m_mstatus;

    trap_m_mstatus[MSTATUS_MPIESH]         = mstatus_r[MSTATUS_MIESH];
    trap_m_mstatus[MSTATUS_MPPSH+:PRIVLEN] = priv_r;
    trap_m_mstatus[MSTATUS_MIESH]          = 0;

    trap_s_mstatus[MSTATUS_SPIESH]         = mstatus_r[MSTATUS_SIESH];
    trap_s_mstatus[MSTATUS_SPPSH]          = priv_r;
    trap_s_mstatus[MSTATUS_SIESH]          = 0;

    mret_mstatus[MSTATUS_MIESH]            = mstatus_r[MSTATUS_MPIESH];
    mret_mstatus[MSTATUS_MPPSH+:PRIVLEN]   = PRIV_U;
    mret_mstatus[MSTATUS_MPIESH]           = 1;
    if (priv_t'(mstatus_r[MSTATUS_MPPSH+:PRIVLEN]) != PRIV_M)
      mret_mstatus[MSTATUS_MPRVSH] = 0;

    sret_mstatus[MSTATUS_SIESH]            = mstatus_r[MSTATUS_SPIESH];
    sret_mstatus[MSTATUS_SPPSH]            = PRIV_U;
    sret_mstatus[MSTATUS_SPIESH]           = 1;
    sret_mstatus[MSTATUS_MPRVSH]           = 0;

    if (_csr_m_mstatus[MSTATUS_MPPSH+:PRIVLEN] == PRIV_H)
      csr_m_mstatus[MSTATUS_MPPSH+:PRIVLEN] = PRIV_U;
  end

  always_comb begin
    priv       = priv_r;

    mstatus    = mstatus_r;
    medeleg    = medeleg_r;
    mideleg    = mideleg_r;
    mie        = mie_r;
    mtvec      = mtvec_r;
    mcounteren = mcounteren_r;
    mscratch   = mscratch_r;
    mepc       = mepc_r;
    mcause     = mcause_r;
    mtval      = mtval_r;
    mip        = mip_r;

    stvec      = stvec_r;
    scounteren = scounteren_r;
    sscratch   = sscratch_r;
    sepc       = sepc_r;
    scause     = scause_r;
    stval      = stval_r;
    satp       = satp_r;

    cycle      = cycle_r;
    instret    = instret_r;

    if (ac_com) begin
      mip[MTI]  = clint_intr_pending;
      mip[PD0I] = vcd_intr_pending;
      mip[PD1I] = vgd_intr_pending;

      cycle     = cycle_r + 1;
      instret   = instret_r + 1;

      if (ac_exc_pending) begin
        if (exc_deleg) begin
          priv    = PRIV_S;
          mstatus = trap_s_mstatus;
          sepc    = ac_pc;
          scause  = ac_exc_code;
          stval   = ac_tval;
        end else begin
          priv    = PRIV_M;
          mstatus = trap_m_mstatus;
          mepc    = ac_pc;
          mcause  = ac_exc_code;
          mtval   = ac_tval;
        end
        instret = instret_r;
      end else if (ac_mret) begin
        priv    = priv_t'(mstatus_r[MSTATUS_MPPSH+:PRIVLEN]);
        mstatus = mret_mstatus;
      end else if (ac_sret) begin
        priv    = priv_t'(mstatus_r[MSTATUS_SPPSH]);
        mstatus = sret_mstatus;
      end else if (ac_csr)
        case (ac_addr)
          CSR_SSTATUS:    mstatus    = (mstatus_r & ~MSTATUS_SMASK) | (ac_wdata & MSTATUS_SMASK);
          CSR_SIE:        mie        = (mie & ~mideleg_r) | (ac_wdata & mideleg_r);
          CSR_STVEC:      stvec      = ac_wdata & ~((1 << TVEC_MODELEN) - 1);
          CSR_SCOUNTEREN: scounteren = ac_wdata & COUNTEREN_MASK;
          CSR_SSCRATCH:   sscratch   = ac_wdata;
          CSR_SEPC:       sepc       = ac_wdata & ~((1 << ILENB_LOG) - 1);
          CSR_SCAUSE:     scause     = ac_wdata;
          CSR_STVAL:      stval      = ac_wdata;
          CSR_SATP:       satp       = ac_wdata & SATP_MASK;

          CSR_MSTATUS:    mstatus    = csr_m_mstatus;
          CSR_MEDELEG:    medeleg    = ac_wdata & MEDELEG_MASK;
          CSR_MIDELEG:    mideleg    = ac_wdata & MIDELEG_MASK;
          CSR_MIE:        mie        = ac_wdata & MIE_MASK;
          CSR_MTVEC:      mtvec      = ac_wdata & ~((1 << TVEC_MODELEN) - 1);
          CSR_MCOUNTEREN: mcounteren = ac_wdata & COUNTEREN_MASK;
          CSR_MSCRATCH:   mscratch   = ac_wdata;
          CSR_MEPC:       mepc       = ac_wdata & ~((1 << ILENB_LOG) - 1);
          CSR_MCAUSE:     mcause     = ac_wdata;
          CSR_MTVAL:      mtval      = ac_wdata;
          CSR_MIP:        mip        = (mip & ~MIP_MASK) | (ac_wdata & MIP_MASK);

          CSR_MCYCLE:     cycle[0+:XLEN]      = ac_wdata;
          CSR_MINSTRET:   instret[0+:XLEN]    = ac_wdata;
          CSR_MCYCLEH:    cycle[XLEN+:XLEN]   = ac_wdata;
          CSR_MINSTRETH:  instret[XLEN+:XLEN] = ac_wdata;
        endcase
      else if (active_intrs) begin
        if (intr_deleg) begin
          priv    = PRIV_S;
          mstatus = trap_s_mstatus;
          sepc    = ac_target_pc;
          scause  = {1'b1, (XLEN - 1)'(intr_code)};
          stval   = 0;
        end else begin
          priv    = PRIV_M;
          mstatus = trap_m_mstatus;
          mepc    = ac_target_pc;
          mcause  = {1'b1, (XLEN - 1)'(intr_code)};
          mtval   = 0;
        end
      end
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      priv_r       <= PRIV_M;

      mstatus_r    <= 0;
      medeleg_r    <= 0;
      mideleg_r    <= 0;
      mie_r        <= 0;
      mtvec_r      <= 0;
      mcounteren_r <= 0;
      mepc_r       <= 0;
      mcause_r     <= 0;
      mtval_r      <= 0;
      mip_r        <= 0;

      stvec_r      <= 0;
      scounteren_r <= 0;
      sepc_r       <= 0;
      scause_r     <= 0;
      stval_r      <= 0;
      satp_r       <= 0;

      cycle_r      <= 0;
      instret_r    <= 0;
    end else begin
      priv_r       <= priv;

      mstatus_r    <= mstatus;
      medeleg_r    <= medeleg;
      mideleg_r    <= mideleg;
      mie_r        <= mie;
      mtvec_r      <= mtvec;
      mcounteren_r <= mcounteren;
      mscratch_r   <= mscratch;
      mepc_r       <= mepc;
      mcause_r     <= mcause;
      mtval_r      <= mtval;
      mip_r        <= mip;

      stvec_r      <= stvec;
      scounteren_r <= scounteren;
      sscratch_r   <= sscratch;
      sepc_r       <= sepc;
      scause_r     <= scause;
      stval_r      <= stval;
      satp_r       <= satp;

      cycle_r      <= cycle;
      instret_r    <= instret;
    end

  /*
   * Other output signals
   */
  assign ac_mstatus       = mstatus_r;
  assign ac_priv          = priv_r;
  assign ac_satp          = satp_r;
  assign ac_tvec          = priv == PRIV_M ? mtvec_r : stvec_r;
  assign ac_intr_handling = !ac_exc_pending && !ac_mret &&
    !ac_sret && !ac_csr && active_intrs;
endmodule
