`default_nettype none

`include "isa_pkg.svh"

module inst_verifier
  import isa_pkg::*;
(
  input  logic [OPCODELEN - 1:0]  ac_opcode,
  input  logic [FUNCT3LEN - 1:0]  ac_funct3,
  input  logic [FUNCT5LEN - 1:0]  ac_funct5,
  input  logic [FUNCT7LEN - 1:0]  ac_funct7,
  input  logic [FUNCT12LEN - 1:0] ac_funct12,
  output logic                    ac_mul,
  output logic                    ac_ecall,
  output logic                    ac_ebreak,
  output logic                    ac_mret,
  output logic                    ac_sret,
  output logic                    ac_sfence_vma,
  output logic                    ac_valid
);
  logic branch;
  logic load;
  logic store;
  logic op_imm;
  logic op;
  logic amo_lr;
  logic amo_sc;
  logic amo_rmw;
  logic csr;

  assign branch = ac_opcode == OPCODE_BRANCH &&
    (ac_funct3 == FUNCT3_BEQ || ac_funct3 == FUNCT3_BNE || ac_funct3 == FUNCT3_BLT ||
     ac_funct3 == FUNCT3_BGE || ac_funct3 == FUNCT3_BLTU || ac_funct3 == FUNCT3_BGEU);

  logic [XLENB_LOG - 1:0] size;
  logic                   nsign;

  assign size  = ac_funct3[FUNCT3_SIZESH+:XLENB_LOG];
  assign nsign = ac_funct3[FUNCT3_NSIGNSH];

  assign load  = ac_opcode == OPCODE_LOAD && size <= XLENB_LOG && !(size == XLENB_LOG && nsign);
  assign store = ac_opcode == OPCODE_STORE && size <= XLENB_LOG && !nsign;

  assign op_imm = ac_opcode == OPCODE_OP_IMM &&
    (ac_funct3 == FUNCT3_ADD || ac_funct3 == FUNCT3_SLT || ac_funct3 == FUNCT3_SLTU ||
     ac_funct3 == FUNCT3_XOR || ac_funct3 == FUNCT3_OR || ac_funct3 == FUNCT3_AND ||
     (ac_funct3 == FUNCT3_SLL && ac_funct7 == FUNCT7_SLL) ||
     (ac_funct3 == FUNCT3_SRL && ac_funct7 == FUNCT7_SRL) ||
     (ac_funct3 == FUNCT3_SRA && ac_funct7 == FUNCT7_SRA));

  assign op = ac_opcode == OPCODE_OP &&
    (ac_funct3 == FUNCT3_ADD && ac_funct7 == FUNCT7_ADD) ||
    (ac_funct3 == FUNCT3_SUB && ac_funct7 == FUNCT7_SUB) ||
    (ac_funct3 == FUNCT3_SLL && ac_funct7 == FUNCT7_SLL) ||
    (ac_funct3 == FUNCT3_SLT && ac_funct7 == FUNCT7_SLT) ||
    (ac_funct3 == FUNCT3_SLTU && ac_funct7 == FUNCT7_SLTU) ||
    (ac_funct3 == FUNCT3_XOR && ac_funct7 == FUNCT7_XOR) ||
    (ac_funct3 == FUNCT3_SRL && ac_funct7 == FUNCT7_SRL) ||
    (ac_funct3 == FUNCT3_SRA && ac_funct7 == FUNCT7_SRA) ||
    (ac_funct3 == FUNCT3_OR && ac_funct7 == FUNCT7_OR) ||
    (ac_funct3 == FUNCT3_AND && ac_funct7 == FUNCT7_AND);

  assign ac_mul = ac_opcode == OPCODE_OP && (ac_funct3 == FUNCT3_MUL || ac_funct3 == FUNCT3_MULH ||
    ac_funct3 == FUNCT3_MULHSU || ac_funct3 == FUNCT3_MULHU) && ac_funct7 == FUNCT7_MULDIV;

  assign amo_lr  = ac_opcode == OPCODE_AMO && size == XLENB_LOG && !nsign && ac_funct5 == FUNCT5_AMO_LR;
  assign amo_sc  = ac_opcode == OPCODE_AMO && size == XLENB_LOG && !nsign && ac_funct5 == FUNCT5_AMO_SC;
  assign amo_rmw = ac_opcode == OPCODE_AMO && size == XLENB_LOG && !nsign &&
    (ac_funct5 == FUNCT5_AMO_SWAP || ac_funct5 == FUNCT5_AMO_ADD || ac_funct5 == FUNCT5_AMO_XOR ||
    ac_funct5 == FUNCT5_AMO_AND || ac_funct5 == FUNCT5_AMO_OR || ac_funct5 == FUNCT5_AMO_MIN ||
    ac_funct5 == FUNCT5_AMO_MAX || ac_funct5 == FUNCT5_AMO_MINU || ac_funct5 == FUNCT5_AMO_MAXU);

  assign ac_ecall = ac_opcode == OPCODE_SYSTEM && ac_funct3 == FUNCT3_PRIV &&
    ac_funct12 == FUNCT12_ECALL;

  assign ac_ebreak = ac_opcode == OPCODE_SYSTEM && ac_funct3 == FUNCT3_PRIV &&
    ac_funct12 == FUNCT12_EBREAK;

  assign ac_mret = ac_opcode == OPCODE_SYSTEM && ac_funct3 == FUNCT3_PRIV &&
    ac_funct12 == FUNCT12_MRET;

  assign ac_sret = ac_opcode == OPCODE_SYSTEM && ac_funct3 == FUNCT3_PRIV &&
    ac_funct12 == FUNCT12_SRET;

  assign ac_sfence_vma = ac_opcode == OPCODE_SYSTEM && ac_funct3 == FUNCT3_PRIV &&
    ac_funct12 == FUNCT12_SFENCE_VMA;

  assign csr = ac_opcode == OPCODE_SYSTEM &&
    (ac_funct3 == FUNCT3_CSRRW || ac_funct3 == FUNCT3_CSRRS || ac_funct3 == FUNCT3_CSRRC ||
     ac_funct3 == FUNCT3_CSRRWI || ac_funct3 == FUNCT3_CSRRSI || ac_funct3 == FUNCT3_CSRRCI);

  assign ac_valid = ac_opcode == OPCODE_LUI || ac_opcode == OPCODE_AUIPC || ac_opcode == OPCODE_JAL ||
    ac_opcode == OPCODE_JALR || branch || load || store || op_imm || op || ac_mul ||
    amo_lr || amo_sc || amo_rmw || csr || ac_ecall || ac_ebreak || ac_mret || ac_sret || ac_sfence_vma;
endmodule
