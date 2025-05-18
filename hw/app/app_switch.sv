`default_nettype none

`include "isa.svh"
`include "soc.svh"

module app_switch
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                       clk,

  input  logic [XLEN - 1:0]          ac_addr,
  input  logic [XLEN - 1:0]          ac_wdata,
  input  logic [XLENB_LOG - 1:0]     ac_size,
  input  logic                       ac_nsign,
  input  logic                       ac_ren,
  input  logic                       ac_wen,
  output logic [XLEN - 1:0]          ac_rdata,
  output logic                       ac_stall,

  input  logic [XLEN - 1:0]          vcd_rdata,
  output logic [VCD_ADDRLEN - 1:0]   vcd_addr,
  output logic [XLEN - 1:0]          vcd_wdata,
  output logic                       vcd_wen,

  input  logic [XLEN - 1:0]          vgd_rdata,
  output logic [VGD_ADDRLEN - 1:0]   vgd_addr,
  output logic [XLEN - 1:0]          vgd_wdata,
  output logic                       vgd_wen,

  output logic [BLEN - 1:0]          dbgc_wdata,
  output logic                       dbgc_wen,

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
  dev_t dev;

  assign dev         = dev_t'(ac_addr[ADDR_DEVSH+:DEVLEN]);

  assign vcd_addr    = ac_addr;
  assign vcd_wdata   = ac_wdata;

  assign vgd_addr    = ac_addr;
  assign vgd_wdata   = ac_wdata;

  assign dbgc_wdata  = ac_wdata;

  assign clint_addr  = ac_addr;
  assign clint_wdata = ac_wdata;

  assign msw_addr    = ac_addr;
  assign msw_wdata   = ac_wdata;
  assign msw_size    = ac_size;
  assign msw_nsign   = ac_nsign;

  always_comb begin
    ac_rdata  = 'bx;
    ac_stall  = 0;

    vcd_wen   = 0;

    vgd_wen   = 0;

    dbgc_wen  = 0;

    clint_wen = 0;

    msw_ren   = 0;
    msw_wen   = 0;

    unique0 case (dev)
      DEV_VCD: begin
        ac_rdata = vcd_rdata;

        vcd_wen  = ac_wen;
      end

      DEV_VGD: begin
        ac_rdata = vgd_rdata;

        vgd_wen  = ac_wen;
      end

      DEV_DBGC:
        dbgc_wen = ac_wen;

      DEV_CLINT: begin
        ac_rdata  = clint_rdata;

        clint_wen = ac_wen;
      end

      DEV_MMEM: begin
        ac_rdata = msw_rdata;
        ac_stall = msw_stall;

        msw_ren  = ac_ren;
        msw_wen  = ac_wen;
      end
    endcase
  end
endmodule
