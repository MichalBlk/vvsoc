`default_nettype none

`include "isa.svh"
`include "soc.svh"

module clint
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                       clk,
  input  logic                       nrst,

  input  logic [CLINT_ADDRLEN - 1:0] asw_addr,
  input  logic [XLEN - 1:0]          asw_wdata,
  input  logic                       asw_wen,
  output logic [XLEN - 1:0]          asw_rdata,

  output logic [CNTLEN - 1:0]        ac_mtime,
  output logic                       ac_intr_pending
);
  logic [CNTLEN - 1:0] mtime, mtime_r;
  logic [CNTLEN - 1:0] mtimecmp, mtimecmp_r;

  /*
   * Reading
   */
  always_comb begin
    asw_rdata = 'bx;

    case (asw_addr)
      CLINT_REG_MTIMECMP:  asw_rdata = mtimecmp_r;
      CLINT_REG_MTIMECMPH: asw_rdata = mtimecmp_r[XLEN+:XLEN];
      CLINT_REG_MTIME:     asw_rdata = mtime_r;
      CLINT_REG_MTIMEH:    asw_rdata = mtime_r[XLEN+:XLEN];
    endcase
  end

  /*
   * Writing
   */
  always_comb begin
    mtime    = mtime_r + 1;
    mtimecmp = mtimecmp_r;

    if (asw_wen)
      unique0 case (asw_addr)
        CLINT_REG_MTIMECMP:  mtimecmp[0+:XLEN]    = asw_wdata;
        CLINT_REG_MTIMECMPH: mtimecmp[XLEN+:XLEN] = asw_wdata;
        CLINT_REG_MTIME:     mtime[0+:XLEN]       = asw_wdata;
        CLINT_REG_MTIMEH:    mtime[XLEN+:XLEN]    = asw_wdata;
      endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      mtime_r    <= 0;
      mtimecmp_r <= {CNTLEN{1'b1}};
    end else begin
      mtime_r    <= mtime;
      mtimecmp_r <= mtimecmp;
    end

  /*
   * Application core signals signals
   */
  assign ac_mtime        = mtime_r;
  assign ac_intr_pending = mtime_r >= mtimecmp_r;
endmodule
