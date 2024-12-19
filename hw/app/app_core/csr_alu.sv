`default_nettype none

`include "isa_pkg.svh"

module csr_alu
  import isa_pkg::*;
(
  input  logic [XLEN - 1:0]      ac_csr,
  input  logic [XLEN - 1:0]      ac_src,
  input  logic [XLEN - 1:0]      ac_imm,
  input  logic [FUNCT3LEN - 1:0] ac_funct3,
  output logic [XLEN - 1:0]      ac_res
);
  always_comb
    case (ac_funct3)
      FUNCT3_CSRRW:  ac_res = ac_src;
      FUNCT3_CSRRS:  ac_res = ac_csr | ac_src;
      FUNCT3_CSRRC:  ac_res = ac_csr & ~ac_src;
      FUNCT3_CSRRWI: ac_res = ac_imm;
      FUNCT3_CSRRSI: ac_res = ac_csr | ac_imm;
      FUNCT3_CSRRCI: ac_res = ac_csr & ~ac_imm;
      default:       ac_res = 'bx;
    endcase
endmodule
