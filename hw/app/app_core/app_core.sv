`default_nettype none

`include "isa_pkg.svh"
`include "soc_pkg.svh"

module app_core
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                   clk,
  input  logic                   nrst,

  input  logic [CNTLEN - 1:0]    clint_mtime,
  input  logic                   clint_intr_pending,

  input  logic [XLEN - 1:0]      asw_rdata,
  input  logic                   asw_stall,
  output logic [XLEN - 1:0]      asw_addr,
  output logic [XLEN - 1:0]      asw_wdata,
  output logic [XLENB_LOG - 1:0] asw_size,
  output logic                   asw_nsign,
  output logic                   asw_ren,
  output logic                   asw_wen,

  input  logic                   vcd_intr_pending,

  input  logic                   vgd_intr_pending,

  input  logic                   vmgr_busy,
  output logic                   vmgr_stallable
);
  typedef enum logic [2:0] {
    ST_IF_DEC,
    ST_EXE1,
    ST_MEM1,
    ST_EXE2,
    ST_MEM2,
    ST_COM
  } state_t;

  state_t                  state, state_r;
  state_t                  pv_state, pv_state_r;
  logic [XLEN - 1:0]       pc, pc_r;
  logic [XLEN - 1:0]       resv_addr, resv_addr_r;
  logic                    resv_valid, resv_valid_r;

  logic [ILEN - 1:0]       inst, inst_r;
  logic [OPCODELEN - 1:0]  _opcode;
  logic [OPCODELEN - 1:0]  opcode;
  logic [REGCNT_LOG - 1:0] rd;
  logic [FUNCT3LEN - 1:0]  funct3;
  logic [FUNCT5LEN - 1:0]  funct5;
  logic [FUNCT7LEN - 1:0]  funct7;
  logic [FUNCT12LEN - 1:0] funct12;
  logic [XLENB_LOG - 1:0]  _mem_size;
  logic [XLENB_LOG - 1:0]  mem_size;
  logic [XLEN - 1:0]       imm, imm_r;
  logic [XLEN - 1:0]       rs1_data, rs1_data_r;
  logic [XLEN - 1:0]       rs2_data, rs2_data_r;
  logic [XLEN - 1:0]       csr_rdata, csr_rdata_r;
  logic [XLEN - 1:0]       csr_wdata;
  logic [XLEN - 1:0]       rd_data1, rd_data1_r;
  logic [XLEN - 1:0]       mem_addr, mem_addr_r;
  logic [XLEN - 1:0]       amo_rmw_data, amo_rmw_data_r;
  logic [XLEN - 1:0]       jmp_pc, jmp_pc_r;
  logic                    mul, mul_r;
  logic                    div, div_r;
  logic                    mret, mret_r;
  logic                    sret, sret_r;
  logic                    sfence_vma, sfence_vma_r;
  logic                    tkn, tkn_r;
  logic                    fast, fast_r;
  logic                    amo_sc_succ;
  logic                    load_amo_lr;
  logic                    store_amo_sc_succ;
  logic                    amo_rmw;
  logic [XLEN - 1:0]       mem_data, mem_data_r;
  exc_t                    exc_code, exc_code_r;
  logic                    exc_pending, exc_pending_r;
  logic [XLEN - 1:0]       tval, tval_r;

  logic                    iv_mul;
  logic                    iv_div;
  logic                    iv_ecall;
  logic                    iv_ebreak;
  logic                    iv_mret;
  logic                    iv_sret;
  logic                    iv_sfence_vma;
  logic                    iv_valid;

  logic [XLEN - 1:0]       rf_wdata;
  logic                    rf_wen;

  logic [XLEN - 1:0]       csrrf_target_pc;
  logic                    csrrf_com;
  priv_t                   csrrf_priv;
  logic [XLEN - 1:0]       csrrf_mstatus;
  logic [XLEN - 1:0]       csrrf_satp;
  logic                    csrrf_ill;
  logic [XLEN - 1:0]       csrrf_tvec;
  logic                    csrrf_intr_handling;

  logic                    mmu_tlb_flush;
  logic [XLEN - 1:0]       mmu_rdata;
  exc_t                    mmu_exc_code;
  logic                    mmu_exc_pending;
  logic                    mmu_stall;

  logic                    stall;

  /*
   * Stalling
   */
  assign stall = vmgr_busy || mmu_stall;

  /*
   * Instruction fetch and decode stage
   */
  logic [OPCODELEN - 1:0]  __opcode;
  logic [FUNCT3LEN - 1:0]  __funct3;
  logic [FUNCT12LEN - 1:0] __funct12;
  logic [REGCNT_LOG - 1:0] _rs1;
  logic [REGCNT_LOG - 1:0] _rs2;
  logic [FUNCT3LEN - 1:0]  _funct3;
  logic [FUNCT5LEN - 1:0]  _funct5;
  logic [FUNCT7LEN - 1:0]  _funct7;
  logic [FUNCT12LEN - 1:0] _funct12;
  logic                    fence;
  logic                    wfi;
  logic [XLEN - 1:0]       rf_rdata1;
  logic [XLEN - 1:0]       rf_rdata2;
  logic [XLEN - 1:0]       ig_imm;
  logic                    csrrf_csr;
  logic                    csrrf_mret;
  logic                    csrrf_sret;
  logic [XLEN - 1:0]       csrrf_rdata;
  logic                    csrrf_ren;

  assign __opcode  = mmu_rdata[OPCODESH+:OPCODELEN];
  assign __funct3  = mmu_rdata[FUNCT3SH+:FUNCT3LEN];
  assign __funct12 = mmu_rdata[FUNCT12SH+:FUNCT12LEN];
  assign fence     = __opcode == OPCODE_MISC_MEM &&
    (__funct3 == FUNCT3_FENCE || __funct3 == FUNCT3_FENCEI);
  assign wfi       = __opcode == OPCODE_SYSTEM && __funct3 == FUNCT3_PRIV && __funct12 == FUNCT12_WFI;

  assign _opcode   = inst[OPCODESH+:OPCODELEN];
  assign _rs1      = inst[RS1SH+:REGCNT_LOG];
  assign _rs2      = inst[RS2SH+:REGCNT_LOG];
  assign _funct3   = inst[FUNCT3SH+:FUNCT3LEN];
  assign _funct5   = inst[FUNCT5SH+:FUNCT5LEN];
  assign _funct7   = inst[FUNCT7SH+:FUNCT7LEN];
  assign _funct12  = inst[FUNCT12SH+:FUNCT12LEN];

  assign _mem_size = _funct3[FUNCT3_SIZESH+:XLENB_LOG];

  assign opcode    = inst_r[OPCODESH+:OPCODELEN];
  assign rd        = inst_r[RDSH+:REGCNT_LOG];
  assign funct3    = inst_r[FUNCT3SH+:FUNCT3LEN];
  assign funct5    = inst_r[FUNCT5SH+:FUNCT5LEN];
  assign funct7    = inst_r[FUNCT7SH+:FUNCT7LEN];
  assign funct12   = inst_r[FUNCT12SH+:FUNCT12LEN];

  assign mem_size  = funct3[FUNCT3_SIZESH+:XLENB_LOG];

  inst_verifier INST_VERIFIER(
    .ac_opcode     (_opcode),
    .ac_funct3     (_funct3),
    .ac_funct5     (_funct5),
    .ac_funct7     (_funct7),
    .ac_funct12    (_funct12),
    .ac_mul        (iv_mul),
    .ac_div        (iv_div),
    .ac_ecall      (iv_ecall),
    .ac_ebreak     (iv_ebreak),
    .ac_mret       (iv_mret),
    .ac_sret       (iv_sret),
    .ac_sfence_vma (iv_sfence_vma),
    .ac_valid      (iv_valid)
  );

  reg_file #(
    .RSTARG  (0)
  ) REG_FILE(
    .clk     (clk),
    .nrst    (nrst),
    .nsrst   (1),
    .raddr1  (_rs1),
    .raddr2  (_rs2),
    .waddr   (rd),
    .wdata   (rf_wdata),
    .wen     (rf_wen),
    .srstarg (0),
    .rdata1  (rf_rdata1),
    .rdata2  (rf_rdata2)
  );

  assign csrrf_mret = state_r == ST_IF_DEC ? iv_mret : mret_r;
  assign csrrf_sret = state_r == ST_IF_DEC ? iv_sret : sret_r;
  assign csrrf_csr  = _opcode == OPCODE_SYSTEM && _funct3 != FUNCT3_PRIV;

  csr_reg_file CSR_REG_FILE(
    .clk                (clk),
    .nrst               (nrst),
    .ac_addr            (csr_addr_t'(_funct12)),
    .ac_wdata           (csr_wdata),
    .ac_pc              (pc_r),
    .ac_target_pc       (csrrf_target_pc),
    .ac_exc_code        (exc_code_r),
    .ac_exc_pending     (exc_pending_r),
    .ac_tval            (tval_r),
    .ac_csr             (csrrf_csr),
    .ac_mret            (csrrf_mret),
    .ac_sret            (csrrf_sret),
    .ac_com             (csrrf_com),
    .ac_mtime           (clint_mtime),
    .ac_rdata           (csrrf_rdata),
    .ac_priv            (csrrf_priv),
    .ac_mstatus         (csrrf_mstatus),
    .ac_satp            (csrrf_satp),
    .ac_ill             (csrrf_ill),
    .ac_tvec            (csrrf_tvec),
    .ac_intr_handling   (csrrf_intr_handling),
    .clint_intr_pending (clint_intr_pending),
    .vcd_intr_pending   (vcd_intr_pending),
    .vgd_intr_pending   (vgd_intr_pending)
  );

  imm_gen IMM_GEN(
    .inst (inst),
    .imm  (ig_imm)
  );

  always_comb begin
    inst       = inst_r;
    imm        = imm_r;
    rs1_data   = rs1_data_r;
    rs2_data   = rs2_data_r;
    csr_rdata  = csr_rdata_r;
    mem_addr   = mem_addr_r;
    mul        = mul_r;
    div        = div_r;
    mret       = mret_r;
    sret       = sret_r;
    sfence_vma = sfence_vma_r;
    fast       = fast_r;

    if (state_r == ST_IF_DEC && !stall) begin
      inst       = fence || wfi ? NOP : mmu_rdata;
      imm        = ig_imm;
      rs1_data   = rf_rdata1;
      rs2_data   = rf_rdata2;
      csr_rdata  = csrrf_rdata;
      mem_addr   = rs1_data + imm;
      mul        = iv_mul;
      div        = iv_div;
      mret       = iv_mret;
      sret       = iv_sret;
      sfence_vma = iv_sfence_vma;
      fast       = _opcode == OPCODE_LUI || _opcode == OPCODE_AUIPC || _opcode == OPCODE_OP_IMM ||
        (_opcode == OPCODE_OP && !iv_mul && !iv_div);
    end
  end

  always_ff @(posedge clk) begin
    inst_r       <= inst;
    imm_r        <= imm;
    rs1_data_r   <= rs1_data;
    rs2_data_r   <= rs2_data;
    csr_rdata_r  <= csr_rdata;
    mem_addr_r   <= mem_addr;
    mul_r        <= mul;
    div_r        <= div;
    mret_r       <= mret;
    sret_r       <= sret;
    sfence_vma_r <= sfence_vma;
    fast_r       <= fast;
  end

  /*
   * Execute stage 1
   */
  logic              bralu_res;
  logic [XLEN - 1:0] mul_res;
  logic [XLEN - 1:0] div_res;

  assign amo_sc_succ       = rs1_data_r == resv_addr_r && resv_valid_r;
  assign load_amo_lr       = opcode == OPCODE_LOAD ||
    (opcode == OPCODE_AMO && funct5 == FUNCT5_AMO_LR);
  assign store_amo_sc_succ = opcode == OPCODE_STORE ||
    (opcode == OPCODE_AMO && funct5 == FUNCT5_AMO_SC && amo_sc_succ);
  assign amo_rmw           = opcode == OPCODE_AMO && funct5 != FUNCT5_AMO_LR && funct5 != FUNCT5_AMO_SC;

  branch_alu BRANCH_ALU(
    .src1   (rs1_data_r),
    .src2   (rs2_data_r),
    .funct3 (funct3),
    .res    (bralu_res)
  );

  multiplier MULTIPLIER(
    .ac_src1   (rs1_data_r),
    .ac_src2   (rs2_data_r),
    .ac_funct3 (funct3),
    .ac_res    (mul_res)
  );

  divisor DIVISOR(
    .ac_src1   (rs1_data_r),
    .ac_src2   (rs2_data_r),
    .ac_funct3 (funct3),
    .ac_res    (div_res)
  );

  always_comb begin
    rd_data1 = rd_data1_r;
    jmp_pc   = jmp_pc_r;

    if (state_r == ST_EXE1 && !stall)
      case (opcode)
        OPCODE_JAL: begin
          jmp_pc   = pc_r + imm_r;
          rd_data1 = pc_r + ILENB;
        end

        OPCODE_JALR: begin
          jmp_pc   = rs1_data_r + imm_r;
          rd_data1 = pc_r + ILENB;
        end

        OPCODE_BRANCH:
          jmp_pc = pc_r + imm_r;

        OPCODE_OP:
          if (mul_r)
            rd_data1 = mul_res;
          else
            rd_data1 = div_res;

        OPCODE_AMO: begin
          mem_addr = rs1_data_r;
          rd_data1 = !amo_sc_succ;
        end

        OPCODE_SYSTEM:
          if (funct3 == FUNCT3_PRIV && (funct12 == FUNCT12_SRET || funct12 == FUNCT12_MRET))
            jmp_pc = csr_rdata_r;
      endcase
  end

  always_ff @(posedge clk) begin
    rd_data1_r <= rd_data1;
    jmp_pc_r   <= jmp_pc;
  end

  /*
   * Memory stage 1
   */
  always_comb begin
    mem_data = mem_data_r;

    if (state_r == ST_MEM1 && !stall)
      mem_data = mmu_rdata;
  end

  always_ff @(posedge clk)
    mem_data_r <= mem_data;

  /*
   * Execute stage 2
   */
  logic [XLEN - 1:0] amo_alu_res;

  amo_alu AMO_ALU(
    .ac_src1   (rs2_data_r),
    .ac_src2   (mem_data_r),
    .ac_funct5 (funct5),
    .ac_res    (amo_alu_res)
  );

  always_comb begin
    amo_rmw_data = amo_rmw_data_r;

    if (state_r == ST_EXE2)
      amo_rmw_data = amo_alu_res;
  end

  always_ff @(posedge clk)
    amo_rmw_data_r <= amo_rmw_data;

  /*
   * Completion stage
   */
  logic [XLEN - 1:0]      opalu_src2;
  logic [FUNCT7LEN - 1:0] opalu_funct7;
  logic [XLEN - 1:0]      opalu_res;
  logic [XLEN - 1:0]      csralu_res;
  logic [XLEN - 1:0]      rd_data2;

  assign opalu_src2   = opcode == OPCODE_OP_IMM ? imm_r : rs2_data_r;
  assign opalu_funct7 = opcode != OPCODE_OP_IMM || funct3 == FUNCT3_SRA ? funct7 : 0;

  op_alu OP_ALU(
    .src1   (rs1_data_r),
    .src2   (opalu_src2),
    .funct3 (funct3),
    .funct7 (opalu_funct7),
    .res    (opalu_res)
  );

  csr_alu CSR_ALU(
    .ac_csr    (csr_rdata_r),
    .ac_src    (rs1_data_r),
    .ac_imm    (imm_r),
    .ac_funct3 (funct3),
    .ac_res    (csralu_res)
  );

  assign csr_wdata = csralu_res;

  always_comb
    case (opcode)
      OPCODE_LUI:               rd_data2 = imm_r;
      OPCODE_AUIPC:             rd_data2 = pc_r + imm_r;
      OPCODE_OP_IMM, OPCODE_OP: rd_data2 = opalu_res;
      default:                  rd_data2 = 'bx;
    endcase

  always_comb
    if (load_amo_lr || amo_rmw)
      rf_wdata = mem_data_r;
    else if (opcode == OPCODE_SYSTEM)
      rf_wdata = csr_rdata_r;
    else if (fast_r)
      rf_wdata = rd_data2;
    else
      rf_wdata = rd_data1_r;

  assign rf_wen = state_r == ST_COM && !exc_pending_r &&
    (opcode == OPCODE_LUI || opcode == OPCODE_AUIPC || opcode == OPCODE_JAL ||
     opcode == OPCODE_JALR || opcode == OPCODE_LOAD || opcode == OPCODE_OP_IMM ||
     opcode == OPCODE_OP || opcode == OPCODE_AMO ||
     (opcode == OPCODE_SYSTEM && funct3 != FUNCT3_PRIV));

  assign csrrf_target_pc = tkn_r ? jmp_pc_r : pc_r + ILENB;
  assign csrrf_com       = state_r == ST_COM;

  always_comb begin
    pc         = pc_r;
    resv_addr  = resv_addr_r;
    resv_valid = resv_valid_r;

    if (state_r == ST_COM) begin
      if (exc_pending_r || csrrf_intr_handling)
        pc = csrrf_tvec;
      else
        pc = csrrf_target_pc;

      if (!exc_pending_r && opcode == OPCODE_AMO) begin
        if (funct5 == FUNCT5_AMO_SC)
          resv_valid = 0;
        else if (funct5 == FUNCT5_AMO_LR) begin
          resv_addr  = mem_addr_r;
          resv_valid = 1;
        end
      end
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      pc_r         <= AC_RESET_PC;
      resv_valid_r <= 0;
    end else begin
      pc_r         <= pc;
      resv_addr_r  <= resv_addr;
      resv_valid_r <= resv_valid;
    end

  /*
   * Flow transfer control
   */
  always_comb begin
    tkn = tkn_r;

    if (!stall)
      case (state_r)
        ST_IF_DEC:
          tkn = 0;

        ST_EXE1:
          case (opcode)
            OPCODE_JAL, OPCODE_JALR:
              tkn = 1;

            OPCODE_BRANCH:
              tkn = bralu_res;

            OPCODE_SYSTEM:
              tkn = funct3 == FUNCT3_PRIV && (funct12 == FUNCT12_SRET || funct12 == FUNCT12_MRET);
          endcase
      endcase
  end

  always_ff @(posedge clk)
    tkn_r <= tkn;

  /*
   * Exception detection
   */
  logic ill_inst;
  logic mem_access_unaligned;

  assign ill_inst             = !iv_valid || (iv_mret && csrrf_priv != PRIV_M) ||
    (iv_sret && csrrf_priv == PRIV_U) || (iv_sfence_vma && csrrf_priv == PRIV_U);
  assign mem_access_unaligned = (mem_addr & ((1 << _mem_size) - 1)) != 0;

  always_comb begin
    exc_code    = exc_code_r;
    exc_pending = exc_pending_r;
    tval        = tval_r;

    if (!stall)
      case (state_r)
        ST_IF_DEC:
          if (mmu_exc_pending) begin
            exc_code    = mmu_exc_code;
            exc_pending = 1;
            tval        = pc_r;
          end else if (ill_inst || csrrf_ill) begin
            exc_code    = CAUSE_ILLEGAL_INSTRUCTION;
            exc_pending = 1;
            tval        = inst;
          end else if (iv_ecall) begin
            exc_code    = exc_t'(CAUSE_USER_ECALL + csrrf_priv);
            exc_pending = 1;
            tval        = 0;
          end else if (iv_ebreak) begin
            exc_code    = CAUSE_BREAKPOINT;
            exc_pending = 1;
            tval        = pc_r;
          end else if (mem_access_unaligned) begin
            if (_opcode == OPCODE_LOAD) begin
              exc_code    = CAUSE_MISALIGNED_LOAD;
              exc_pending = 1;
              tval        = mem_addr;
            end else if (_opcode == OPCODE_STORE) begin
              exc_code    = CAUSE_MISALIGNED_STORE_AMO;
              exc_pending = 1;
              tval        = mem_addr;
            end
          end

        ST_EXE1:
          if (tkn && jmp_pc[ILENB_LOG - 1:0]) begin
            exc_code    = CAUSE_MISALIGNED_FETCH;
            exc_pending = 1;
            tval        = jmp_pc;
          end else if (mem_access_unaligned) begin
            if (load_amo_lr) begin
              exc_code    = CAUSE_MISALIGNED_LOAD;
              exc_pending = 1;
              tval        = mem_addr_r;
            end else if (store_amo_sc_succ || amo_rmw) begin
              exc_code    = CAUSE_MISALIGNED_STORE_AMO;
              exc_pending = 1;
              tval        = mem_addr_r;
            end
          end

        ST_MEM1, ST_MEM2:
          if (mmu_exc_pending) begin
            exc_code    = mmu_exc_code;
            exc_pending = 1;
            tval        = mem_addr_r;
          end

        ST_COM:
          exc_pending = 0;
      endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      exc_pending_r <= 0;
    else begin
      exc_code_r    <= exc_code;
      exc_pending_r <= exc_pending;
      tval_r        <= tval;
    end

  /*
   * State transitions
   */
  logic mem_access;

  assign mem_access = load_amo_lr || store_amo_sc_succ || amo_rmw;

  always_comb begin
    state    = state_r;
    pv_state = state_r;

    if (!stall) begin
      if (state_r == ST_COM)
        state = ST_IF_DEC;
      else if (exc_pending)
        state = ST_COM;
      else if (state_r == ST_IF_DEC) begin
        if (fast)
          state = ST_COM;
        else if (_opcode == OPCODE_LOAD || _opcode == OPCODE_STORE)
          state = ST_MEM1;
        else
          state = ST_EXE1;
      end else if (state_r == ST_EXE1 && !mem_access)
        state = ST_COM;
      else if (state_r == ST_MEM1 && !amo_rmw)
        state = ST_COM;
      else
        state = state_t'(state_r + 1);
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      state_r    <= ST_IF_DEC;
      pv_state_r <= ST_COM;
    end else begin
      state_r    <= state;
      pv_state_r <= pv_state;
    end

  /*
   * TLB flushing
   */
  assign mmu_tlb_flush = state_r == ST_COM && sfence_vma_r;

  /*
   * MMU
   */
  logic [XLEN - 1:0]      mmu_vaddr;
  logic [XLEN - 1:0]      mmu_wdata;
  logic [XLENB_LOG - 1:0] mmu_size;
  logic                   mmu_nsign;
  access_t                mmu_access;

  assign mmu_vaddr = state_r == ST_IF_DEC ? pc_r : mem_addr_r;
  assign mmu_wdata = state_r == ST_MEM1 ? rs2_data_r : amo_rmw_data_r;
  assign mmu_size  = state_r == ST_IF_DEC ? ILENB_LOG : mem_size;
  assign mmu_nsign = funct3[FUNCT3_NSIGNSH];

  always_comb begin
    mmu_access = ACC_NONE;

    case (state_r)
      ST_IF_DEC:
        mmu_access = ACC_FETCH;

      ST_MEM1:
        if (load_amo_lr || amo_rmw)
          mmu_access = ACC_LOAD;
        else
          mmu_access = ACC_STORE;

      ST_MEM2:
        mmu_access = ACC_STORE;
    endcase
  end

  mmu MMU(
    .clk            (clk),
    .nrst           (nrst),
    .ac_vaddr       (mmu_vaddr),
    .ac_wdata       (mmu_wdata),
    .ac_size        (mmu_size),
    .ac_nsign       (mmu_nsign),
    .ac_access      (mmu_access),
    .ac_priv        (csrrf_priv),
    .ac_mstatus     (csrrf_mstatus),
    .ac_satp        (csrrf_satp),
    .ac_tlb_flush   (mmu_tlb_flush),
    .ac_rdata       (mmu_rdata),
    .ac_exc_code    (mmu_exc_code),
    .ac_exc_pending (mmu_exc_pending),
    .ac_stall       (mmu_stall),
    .asw_rdata      (asw_rdata),
    .asw_stall      (asw_stall),
    .asw_addr       (asw_addr),
    .asw_wdata      (asw_wdata),
    .asw_size       (asw_size),
    .asw_nsign      (asw_nsign),
    .asw_ren        (asw_ren),
    .asw_wen        (asw_wen)
  );

  /*
   * VirtIO manager signals
   */
  assign vmgr_stallable = state_r == ST_EXE1;
endmodule
