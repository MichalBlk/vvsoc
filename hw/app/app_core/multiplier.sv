`default_nettype none

`include "isa.svh"

module multiplier
  import isa_pkg::*;
(
  input  logic [XLEN - 1:0]      ac_src1,
  input  logic [XLEN - 1:0]      ac_src2,
  input  logic [FUNCT3LEN - 1:0] ac_funct3,
  output logic [XLEN - 1:0]      ac_res
);
  logic signed [XLEN - 1:0] src1_s;
  logic signed [XLEN - 1:0] src2_s;
  logic [DXLEN - 1:0]       res_ss;
  logic [DXLEN - 1:0]       res_uu;
  logic [DXLEN - 1:0]       res_su;

  assign src1_s = ac_src1;
  assign src2_s = ac_src2;

  assign res_ss = src1_s * src2_s;
  assign res_uu = ac_src1  * ac_src2;
  assign res_su = signed'({src1_s[XLEN - 1], src1_s}) * signed'({1'b0, ac_src2});

  always_comb begin
    ac_res = 'bx;

    unique0 case (ac_funct3)
      FUNCT3_MUL:    ac_res = res_ss[0+:XLEN];
      FUNCT3_MULH:   ac_res = res_ss[XLEN+:XLEN];
      FUNCT3_MULHSU: ac_res = res_su[XLEN+:XLEN];
      FUNCT3_MULHU:  ac_res = res_uu[XLEN+:XLEN];
    endcase
  end
endmodule
