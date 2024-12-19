`default_nettype none

`include "isa_pkg.svh"

module op_alu
  import isa_pkg::*;
(
  input  logic [XLEN - 1:0]      src1,
  input  logic [XLEN - 1:0]      src2,
  input  logic [FUNCT3LEN - 1:0] funct3,
  input  logic [FUNCT7LEN - 1:0] funct7,
  output logic [XLEN - 1:0]      res
);
  logic signed [XLEN - 1:0]     src1_s;
  logic signed [XLEN - 1:0]     src2_s;
  logic        [XLEN_LOG - 1:0] shamt;

  assign src1_s = src1;
  assign src2_s = src2;
  assign shamt  = src2;

  always_comb
    case (funct3)
      FUNCT3_ADD, FUNCT3_SUB: res = funct7 ? src1 - src2 : src1 + src2;
      FUNCT3_SLT:             res = src1_s < src2_s;
      FUNCT3_SLTU:            res = src1 < src2;
      FUNCT3_XOR:             res = src1 ^ src2;
      FUNCT3_OR:              res = src1 | src2;
      FUNCT3_AND:             res = src1 & src2;
      FUNCT3_SLL:             res = src1 << shamt;
      FUNCT3_SRL, FUNCT3_SRA: res = funct7 ? src1_s >>> shamt : src1_s >> shamt;
    endcase
endmodule
