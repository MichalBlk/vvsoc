`default_nettype none

`include "isa_pkg.svh"

module divisor
  import isa_pkg::*;
(
  input  logic [XLEN - 1:0]      ac_src1,
  input  logic [XLEN - 1:0]      ac_src2,
  input  logic [FUNCT3LEN - 1:0] ac_funct3,
  output logic [XLEN - 1:0]      ac_res
);
  localparam ALL   = {XLEN{1'b1}};
  localparam MAXPW = 1 << (XLEN - 1);

  logic signed [XLEN - 1:0] src1_s;
  logic signed [XLEN - 1:0] src2_s;
  logic [XLEN - 1:0]        q_s;
  logic [XLEN - 1:0]        q_u;
  logic [XLEN - 1:0]        r_s;
  logic [XLEN - 1:0]        r_u;
  logic                     zero;
  logic                     ovf;

  assign src1_s = ac_src1;
  assign src2_s = ac_src2;

  assign q_s = src1_s / src2_s;
  assign q_u = ac_src1 / ac_src2;
  assign r_s = src1_s % src2_s;
  assign r_u = ac_src1 % ac_src2;

  assign zero = !ac_src2;
  assign ovf  = ac_src1 == MAXPW && ac_src2 == ALL;

  always_comb
    case (ac_funct3)
      FUNCT3_DIV:
        if (zero)
          ac_res = ALL;
        else if (ovf)
          ac_res = MAXPW;
        else
          ac_res = q_s;

      FUNCT3_DIVU:
        if (zero)
          ac_res = ALL;
        else
          ac_res = q_u;

      FUNCT3_REM:
        if (zero)
          ac_res = ac_src1;
        else if (ovf)
          ac_res = 0;
        else
          ac_res = r_s;

      FUNCT3_REMU:
        if (zero)
          ac_res = ac_src1;
        else
          ac_res = r_u;

      default: ac_res = 'bx;
    endcase
endmodule
