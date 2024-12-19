`default_nettype none

`include "isa_pkg.svh"

module branch_alu
  import isa_pkg::*;
(
  input  logic [XLEN - 1:0]      src1,
  input  logic [XLEN - 1:0]      src2,
  input  logic [FUNCT3LEN - 1:0] funct3,
  output logic                   res
);
  logic signed [XLEN - 1:0] src1_s;
  logic signed [XLEN - 1:0] src2_s;

  assign src1_s = src1;
  assign src2_s = src2;

  always_comb
    case (funct3)
      FUNCT3_BEQ:  res = src1 == src2;
      FUNCT3_BNE:  res = src1 != src2;
      FUNCT3_BLT:  res = src1_s < src2_s;
      FUNCT3_BGE:  res = src1_s >= src2_s;
      FUNCT3_BLTU: res = src1 < src2;
      FUNCT3_BGEU: res = src1 >= src2;
      default:     res = 'bx;
    endcase
endmodule
