`default_nettype none

`include "isa_pkg.svh"

module imm_gen
  import isa_pkg::*;
(
  input  logic [ILEN - 1:0] inst,
  output logic [XLEN - 1:0] imm
);
  logic [XLEN - 1:0] imm_I;
  logic [XLEN - 1:0] imm_S;
  logic [XLEN - 1:0] imm_B;
  logic [XLEN - 1:0] imm_U;
  logic [XLEN - 1:0] imm_J;
  logic [XLEN - 1:0] imm_CSR;

  assign imm_I = signed'(inst[IMM_ISH+:IMM_ILEN]);
  assign imm_S = signed'({inst[IMM_S5SH+:IMM_S5LEN], inst[IMM_S0SH+:IMM_S0LEN]});
  assign imm_B = signed'({inst[IMM_B12SH], inst[IMM_B11SH], inst[IMM_B5SH+:IMM_B5LEN],
    inst[IMM_B1SH+:IMM_B1LEN], 1'b0});
  assign imm_U = inst[IMM_USH+:IMM_ULEN] << IMM_USH;
  assign imm_J = signed'({inst[IMM_J20SH], inst[IMM_J12SH+:IMM_J12LEN], inst[IMM_J11SH],
    inst[IMM_J1SH+:IMM_J1LEN], 1'b0});
  assign imm_CSR = inst[RS1SH+:REGCNT_LOG];

  always_comb begin
    imm = 'bx;

    unique0 case (inst[OPCODESH+:OPCODELEN])
      OPCODE_LUI:    imm = imm_U;
      OPCODE_AUIPC:  imm = imm_U;
      OPCODE_JAL:    imm = imm_J;
      OPCODE_JALR:   imm = imm_I;
      OPCODE_BRANCH: imm = imm_B;
      OPCODE_LOAD:   imm = imm_I;
      OPCODE_STORE:  imm = imm_S;
      OPCODE_OP_IMM: imm = imm_I;
      OPCODE_SYSTEM: imm = imm_CSR;
    endcase
  end
endmodule
