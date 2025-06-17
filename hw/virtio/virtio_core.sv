`default_nettype none

`include "isa.svh"
`include "soc.svh"

module virtio_core
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                   clk,
  input  logic                   nrst,

  input  logic [XLEN - 1:0]      vsw_rdata,
  input  logic                   vsw_stall,
  output logic [XLEN - 1:0]      vsw_addr,
  output logic [XLEN - 1:0]      vsw_wdata,
  output logic [XLENB_LOG - 1:0] vsw_size,
  output logic                   vsw_nsign,
  output logic                   vsw_ren,
  output logic                   vsw_wen,

  input  logic [XLEN - 1:0]      vmem_raw_data
);
  typedef enum logic [1:0] {
    ST_IF_DEC,
    ST_EXE,
    ST_MEM,
    ST_WB
  } state_t;

  state_t                  state, state_r;
  logic [XLEN - 1:0]       pc, pc_r;

  logic [ILEN - 1:0]       inst, inst_r;
  logic [OPCODELEN - 1:0]  opcode;
  logic [REGCNT_LOG - 1:0] rd;
  logic [FUNCT3LEN - 1:0]  funct3;
  logic [FUNCT5LEN - 1:0]  funct5;
  logic [FUNCT7LEN - 1:0]  funct7;
  logic [XLENB_LOG - 1:0]  mem_size;
  logic [XLEN - 1:0]       imm, imm_r;
  logic [XLEN - 1:0]       rs1_data, rs1_data_r;
  logic [XLEN - 1:0]       rs2_data, rs2_data_r;
  logic [XLEN - 1:0]       rd_data, rd_data_r;
  logic [XLEN - 1:0]       mem_addr, mem_addr_r;
  logic [XLEN - 1:0]       jmp_pc, jmp_pc_r;
  logic                    tkn, tkn_r;
  logic [XLEN - 1:0]       mem_data, mem_data_r;
 
  logic [XLEN - 1:0]       rf_wdata;
  logic                    rf_wen;

  /*
   * Instruction fetch and decode stage
   */
  logic [REGCNT_LOG - 1:0] _rs1;
  logic [REGCNT_LOG - 1:0] _rs2;
  logic [XLEN - 1:0]       rf_rdata1;
  logic [XLEN - 1:0]       rf_rdata2;
  logic [XLEN - 1:0]       ig_imm;

  assign _rs1 = vmem_raw_data[RS1SH+:REGCNT_LOG];
  assign _rs2 = vmem_raw_data[RS2SH+:REGCNT_LOG];

  reg_file #(
    .RSTARG (0)
  ) REG_FILE(
    .clk     (clk),
    .nrst    (nrst),
    .raddr1  (_rs1),
    .raddr2  (_rs2),
    .waddr   (rd),
    .wdata   (rf_wdata),
    .wen     (rf_wen),
    .rdata1  (rf_rdata1),
    .rdata2  (rf_rdata2)
  );

  imm_gen IMM_GEN(
    .inst (vmem_raw_data),
    .imm  (ig_imm)
  );

  always_comb begin
    inst     = inst_r;
    imm      = imm_r;
    rs1_data = rs1_data_r;
    rs2_data = rs2_data_r;

    if (state_r == ST_IF_DEC) begin
      inst     = vmem_raw_data;
      imm      = ig_imm;
      rs1_data = rf_rdata1;
      rs2_data = rf_rdata2;
    end
  end

  always_ff @(posedge clk) begin
    inst_r     <= inst;
    imm_r      <= imm;
    rs1_data_r <= rs1_data;
    rs2_data_r <= rs2_data;
  end

  /*
   * Execute stage
   */
  logic [XLEN - 1:0]      opalu_src2;
  logic [FUNCT7LEN - 1:0] opalu_funct7;
  logic [XLEN - 1:0]      opalu_res;
  logic                   bralu_res;

  assign opcode       = inst_r[OPCODESH+:OPCODELEN];
  assign rd           = inst_r[RDSH+:REGCNT_LOG];
  assign funct3       = inst_r[FUNCT3SH+:FUNCT3LEN];
  assign funct5       = inst_r[FUNCT5SH+:FUNCT5LEN];
  assign funct7       = inst_r[FUNCT7SH+:FUNCT7LEN];

  assign mem_size     = funct3[FUNCT3_SIZESH+:XLENB_LOG];

  assign opalu_src2   = opcode == OPCODE_OP_IMM ? imm_r : rs2_data_r;
  assign opalu_funct7 = opcode != OPCODE_OP_IMM || funct3 == FUNCT3_SRA ? funct7 : 0;

  op_alu OP_ALU(
    .src1   (rs1_data_r),
    .src2   (opalu_src2),
    .funct3 (funct3),
    .funct7 (opalu_funct7),
    .res    (opalu_res)
  );

  branch_alu BRANCH_ALU(
    .src1   (rs1_data_r),
    .src2   (rs2_data_r),
    .funct3 (funct3),
    .res    (bralu_res)
  );

  always_comb begin
    rd_data  = rd_data_r;
    mem_addr = mem_addr_r;
    jmp_pc   = jmp_pc_r;
    tkn      = tkn_r;

    if (state_r == ST_EXE) begin
      tkn = 0;

      unique0 case (opcode)
        OPCODE_LUI:
          rd_data = imm_r;

        OPCODE_AUIPC:
          rd_data = pc_r + imm_r;

        OPCODE_JAL: begin
          tkn     = 1;
          jmp_pc  = pc_r + imm_r;
          rd_data = pc_r + ILENB;
        end

        OPCODE_JALR: begin
          tkn     = 1;
          jmp_pc  = rs1_data_r + imm_r;
          rd_data = pc_r + ILENB;
        end

        OPCODE_BRANCH: begin
          tkn    = bralu_res;
          jmp_pc = pc_r + imm_r;
        end

        OPCODE_LOAD, OPCODE_STORE:
          mem_addr = rs1_data_r + imm_r;

        OPCODE_OP, OPCODE_OP_IMM:
          rd_data = opalu_res;
      endcase
    end
  end

  always_ff @(posedge clk) begin
    rd_data_r  <= rd_data;
    mem_addr_r <= mem_addr;
    jmp_pc_r   <= jmp_pc;
    tkn_r      <= tkn;
  end

  /*
   * Program counter handling
   */
  always_comb begin
    pc = pc_r;

    if (state_r == ST_EXE)
      pc = tkn ? jmp_pc : pc_r + ILENB;
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      pc_r <= VC_RESET_PC;
    else
      pc_r <= pc;

  /*
   * Memory stage
   */
  always_comb begin
    mem_data = mem_data_r;

    if (state_r == ST_MEM)
      mem_data = vsw_rdata;
  end

  always_ff @(posedge clk)
    mem_data_r <= mem_data;

  /*
   * Write back stage
   */
  assign rf_wdata = opcode == OPCODE_LOAD ? mem_data_r : rd_data_r;
  assign rf_wen   = state_r == ST_WB &&
    (opcode == OPCODE_LUI || opcode == OPCODE_AUIPC || opcode == OPCODE_JAL ||
     opcode == OPCODE_JALR || opcode == OPCODE_LOAD || opcode == OPCODE_OP_IMM ||
     opcode == OPCODE_OP);

  /*
   * State transitions
   */
  logic mem_access;

  assign mem_access = opcode == OPCODE_LOAD || opcode == OPCODE_STORE;

  always_comb begin
    state = state_r;

    case (state_r)
      ST_IF_DEC:
        if (!vsw_stall)
          state = ST_EXE;

      ST_EXE:
        if (opcode == OPCODE_BRANCH)
          state = ST_IF_DEC;
        else
          state = mem_access ? ST_MEM : ST_WB;

      ST_MEM:
        if (!vsw_stall)
          state = opcode == OPCODE_STORE ? ST_IF_DEC : ST_WB;

      ST_WB:
        state = ST_IF_DEC;

      default:
        state = state_t'(state_r + 1);
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      state_r <= ST_IF_DEC;
    else
      state_r <= state;

  /*
   * VirtIO switch signals
   */
  assign vsw_addr  = state_r == ST_IF_DEC ? pc_r : mem_addr_r;
  assign vsw_wdata = rs2_data_r;
  assign vsw_size  = state_r == ST_IF_DEC ? ILENB_LOG : mem_size;
  assign vsw_nsign = funct3[FUNCT3_NSIGNSH];
  assign vsw_ren   = state_r == ST_IF_DEC || (state_r == ST_MEM && opcode == OPCODE_LOAD);
  assign vsw_wen   = state_r == ST_MEM && opcode == OPCODE_STORE;
endmodule
