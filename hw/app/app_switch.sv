`default_nettype none

`include "isa.svh"
`include "soc.svh"

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

  input  logic [XLEN - 1:0]          vcd_rdata,
  output logic [VCD_ADDRLEN - 1:0]   vcd_addr,
  output logic [XLEN - 1:0]          vcd_wdata,
  output logic                       vcd_wen,

  input  logic [XLEN - 1:0]          vgd_rdata,
  output logic [VGD_ADDRLEN - 1:0]   vgd_addr,
  output logic [XLEN - 1:0]          vgd_wdata,
  output logic                       vgd_wen,

  input  logic [XLEN - 1:0]          bmem_rdata,
  input  logic                       bmem_stall,
  output logic [BMEM_ADDRLEN- 1:0]   bmem_addr,
  output logic [XLEN - 1:0]          bmem_wdata,
  output logic [XLENB_LOG - 1:0]     bmem_size,
  output logic                       bmem_nsign,
  output logic                       bmem_ren,
  output logic                       bmem_wen,

  input  logic                       dbgc_stall,
  output logic [BLEN - 1:0]          dbgc_wdata,
  output logic                       dbgc_wen,

  input  logic [XLEN - 1:0]          clint_rdata,
  output logic [CLINT_ADDRLEN - 1:0] clint_addr,
  output logic [XLEN - 1:0]          clint_wdata,
  output logic                       clint_wen,

  input  logic [XLEN - 1:0]          fl_rdata,
  input  logic                       fl_stall,
  output logic [FL_ADDRLEN- 1:0]     fl_addr,
  output logic                       fl_nsign,
  output logic                       fl_ren,

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

  assign bmem_addr   = ac_addr;
  assign bmem_wdata  = ac_wdata;
  assign bmem_size   = ac_size;
  assign bmem_nsign  = ac_nsign;

  assign dbgc_wdata  = ac_wdata;

  assign clint_addr  = ac_addr;
  assign clint_wdata = ac_wdata;

  assign fl_addr     = ac_addr;
  assign fl_nsign    = ac_nsign;

  assign msw_addr    = ac_addr;
  assign msw_wdata   = ac_wdata;
  assign msw_size    = ac_size;
  assign msw_nsign   = ac_nsign;

  always_comb begin
    ac_rdata  = 'bx;
    ac_stall  = 0;

    vcd_wen   = 0;

    vgd_wen   = 0;

    bmem_ren  = 0;
    bmem_wen  = 0;

    dbgc_wen  = 0;

    clint_wen = 0;

    fl_ren    = 0;

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

      DEV_BMEM: begin
        ac_rdata = bmem_rdata;
        ac_stall = bmem_stall;

        bmem_ren = ac_ren;
        bmem_wen = ac_wen;
      end

      DEV_DBGC: begin
        ac_stall = dbgc_stall;

        dbgc_wen = ac_wen;
      end

      DEV_CLINT: begin
        ac_rdata  = clint_rdata;

        clint_wen = ac_wen;
      end

      DEV_FL: begin
        ac_rdata = fl_rdata;
        ac_stall = fl_stall;

        fl_ren   = ac_ren;
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
