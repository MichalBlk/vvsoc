`default_nettype none

`include "isa_pkg.svh"
`include "soc_pkg.svh"

module app_switch
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic [XLEN - 1:0]          ac_addr,
  input  logic [XLEN - 1:0]          ac_wdata,
  input  logic [XLENB_LOG - 1:0]     ac_size,
  input  logic                       ac_nsign,
  input  logic                       ac_ren,
  input  logic                       ac_wen,
  output logic [XLEN - 1:0]          ac_rdata,
  output logic                       ac_stall,

  input  logic [XLEN - 1:0]          clint_rdata,
  output logic [CLINT_ADDRLEN - 1:0] clint_addr,
  output logic [XLEN - 1:0]          clint_wdata,
  output logic                       clint_wen,

  input  logic [XLEN - 1:0]          msw_rdata,
  input  logic                       msw_stall,
  output logic [XLEN - 1:0]          msw_addr,
  output logic [XLEN - 1:0]          msw_wdata,
  output logic [XLENB_LOG - 1:0]     msw_size,
  output logic                       msw_nsign,
  output logic                       msw_ren,
  output logic                       msw_wen
);
  assign clint_addr  = ac_addr;
  assign clint_wdata = ac_wdata;

  assign msw_addr    = ac_addr;
  assign msw_wdata   = ac_wdata;
  assign msw_size    = ac_size;
  assign msw_nsign   = ac_nsign;

  always_comb begin
    ac_stall  = 0;

    clint_wen = 0;

    msw_ren   = 0;
    msw_wen   = 0;

    case (ac_addr[ADDR_DEVSH+:DEVLEN])
      DEV_CLINT: begin
        ac_rdata  = clint_rdata;

        clint_wen = ac_wen;
      end

      default: begin
        ac_rdata = msw_rdata;
        ac_stall = msw_stall;

        msw_ren  = ac_ren;
        msw_wen  = ac_wen;
      end
    endcase
  end
endmodule
