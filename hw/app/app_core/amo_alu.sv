`default_nettype none

`include "isa.svh"

module amo_alu
  import isa_pkg::*;
(
  input  logic [XLEN - 1:0]      ac_src1,
  input  logic [XLEN - 1:0]      ac_src2,
  input  logic [FUNCT5LEN - 1:0] ac_funct5,
  output logic [XLEN - 1:0]      ac_res
);
  logic signed [XLEN - 1:0] src1_s;
  logic signed [XLEN - 1:0] src2_s;

  assign src1_s = ac_src1;
  assign src2_s = ac_src2;

  always_comb begin
    ac_res = 'bx;

    unique0 case (ac_funct5)
      FUNCT5_AMO_SWAP: ac_res = ac_src1;
      FUNCT5_AMO_ADD:  ac_res = ac_src1 + ac_src2;
      FUNCT5_AMO_XOR:  ac_res = ac_src1 ^ ac_src2;
      FUNCT5_AMO_AND:  ac_res = ac_src1 & ac_src2;
      FUNCT5_AMO_OR:   ac_res = ac_src1 | ac_src2;
      FUNCT5_AMO_MIN:  ac_res = (src1_s < src2_s ? ac_src1 : ac_src2);
      FUNCT5_AMO_MAX:  ac_res = (src1_s > src2_s ? ac_src1 : ac_src2);
      FUNCT5_AMO_MINU: ac_res = (ac_src1 < ac_src2 ? ac_src1 : ac_src2);
      FUNCT5_AMO_MAXU: ac_res = (ac_src1 > ac_src2 ? ac_src1 : ac_src2);
    endcase
  end
endmodule
