`default_nettype none

`include "isa_pkg.svh"

module reg_file
  import isa_pkg::*;
#(
  parameter RSTARG = 0
)(
  input  logic                    clk,
  input  logic                    nrst,
  input  logic                    nsrst,

  input  logic [REGCNT_LOG - 1:0] raddr1,
  input  logic [REGCNT_LOG - 1:0] raddr2,
  input  logic [REGCNT_LOG - 1:0] waddr,
  input  logic [XLEN - 1:0]       wdata,
  input  logic                    wen,
  input  logic [XLEN - 1:0]       srstarg,
  output logic [XLEN - 1:0]       rdata1,
  output logic [XLEN - 1:0]       rdata2
);
  logic [XLEN - 1:0] x [REGCNT - 1:0], x_r [REGCNT - 1:0];

  logic              red_redge;

  /*
   * Rising edge detector for synchronous reset
   */
  rising_edge_detector REDGE_DETECTOR(
    .clk   (clk),
    .nrst  (nrst),
    .src   (nsrst),
    .redge (red_redge)
  );

  /*
   * Reading
   */
  assign rdata1 = x_r[raddr1];
  assign rdata2 = x_r[raddr2];

  /*
   * Writing
   */
  always_comb begin
    for (int i = 0; i < REGCNT; i++)
      x[i] = x_r[i];

    if (red_redge)
      x[REG_A0] = srstarg;
    else if (wen && waddr)
      x[waddr] = wdata;
  end

  always_ff @(posedge clk, negedge nrst) begin
    if (!nrst) begin
      for (int i = 0; i < REGCNT; i++)
        x_r[i] <= 0;

      x_r[REG_A0] <= RSTARG;
    end else if (!nsrst) begin
      for (int i = 0; i < REGCNT; i++)
        x_r[i] <= 0;
    end else begin
      for (int i = 0; i < REGCNT; i++)
        x_r[i] <= x[i];
    end
  end
endmodule
