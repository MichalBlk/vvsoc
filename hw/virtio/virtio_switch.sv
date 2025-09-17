`default_nettype none

`include "isa.svh"
`include "soc.svh"

module virtio_switch
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic [XLEN - 1:0]         vc_addr,
  input  logic [XLEN - 1:0]         vc_wdata,
  input  logic [XLENB_LOG - 1:0]    vc_size,
  input  logic                      vc_nsign,
  input  logic                      vc_ren,
  input  logic                      vc_wen,
  output logic [XLEN - 1:0]         vc_rdata,
  output logic                      vc_stall,

  input  logic [XLEN - 1:0]         vmem_rdata,
  input  logic                      vmem_stall,
  output logic [VMEM_ADDRLEN - 1:0] vmem_addr,
  output logic [XLEN - 1:0]         vmem_wdata,
  output logic [XLENB_LOG - 1:0]    vmem_size,
  output logic                      vmem_nsign,
  output logic                      vmem_ren,
  output logic                      vmem_wen,

  input  logic [XLEN - 1:0]         vmgr_rdata,
  input  logic                      vmgr_stall,
  output logic [VMGR_ADDRLEN - 1:0] vmgr_addr,
  output logic [XLEN - 1:0]         vmgr_wdata,
  output logic                      vmgr_ren,
  output logic                      vmgr_wen,

  input  logic [XLEN - 1:0]         vcd_rdata,
  output logic [VCD_ADDRLEN - 1:0]  vcd_addr,
  output logic [XLEN - 1:0]         vcd_wdata,
  output logic                      vcd_wen,

  input  logic [XLEN - 1:0]         vgd_rdata,
  output logic [VGD_ADDRLEN - 1:0]  vgd_addr,
  output logic [XLEN - 1:0]         vgd_wdata,
  output logic                      vgd_wen,

  input  logic [XLEN - 1:0]         vkd_rdata,
  output logic [VKD_ADDRLEN - 1:0]  vkd_addr,
  output logic [XLEN - 1:0]         vkd_wdata,
  output logic                      vkd_wen,

  input  logic [XLEN - 1:0]         msw_rdata,
  input  logic                      msw_stall,
  output logic [XLEN - 1:0]         msw_addr,
  output logic [XLEN - 1:0]         msw_wdata,
  output logic [XLENB_LOG - 1:0]    msw_size,
  output logic                      msw_nsign,
  output logic                      msw_ren,
  output logic                      msw_wen
);
  dev_t dev;

  assign dev        = dev_t'(vc_addr[ADDR_DEVSH+:DEVLEN]);

  assign vmem_addr  = vc_addr;
  assign vmem_wdata = vc_wdata;
  assign vmem_size  = vc_size;
  assign vmem_nsign = vc_nsign;

  assign vmgr_addr  = vc_addr;
  assign vmgr_wdata = vc_wdata;

  assign vcd_addr   = vc_addr;
  assign vcd_wdata  = vc_wdata;

  assign vgd_addr   = vc_addr;
  assign vgd_wdata  = vc_wdata;

  assign vkd_addr   = vc_addr;
  assign vkd_wdata  = vc_wdata;

  assign msw_addr   = vc_addr;
  assign msw_wdata  = vc_wdata;
  assign msw_size   = vc_size;
  assign msw_nsign  = vc_nsign;

  always_comb begin
    vc_rdata = 'bx;
    vc_stall = 0;

    vmem_ren = 0;
    vmem_wen = 0;

    vmgr_ren = 0;
    vmgr_wen = 0;

    vcd_wen  = 0;

    vgd_wen  = 0;

    vkd_wen  = 0;

    msw_ren  = 0;
    msw_wen  = 0;

    unique0 case (dev)
      DEV_VMEM: begin
        vc_rdata = vmem_rdata;
        vc_stall = vmem_stall;

        vmem_ren = vc_ren;
        vmem_wen = vc_wen;
      end

      DEV_VMGR: begin
        vc_rdata = vmgr_rdata;
        vc_stall = vmgr_stall;

        vmgr_ren = vc_ren;
        vmgr_wen = vc_wen;
      end

      DEV_VCD: begin
        vc_rdata = vcd_rdata;

        vcd_wen  = vc_wen;
      end

      DEV_VGD: begin
        vc_rdata = vgd_rdata;

        vgd_wen  = vc_wen;
      end

      DEV_VKD: begin
        vc_rdata = vkd_rdata;

        vkd_wen  = vc_wen;
      end

      DEV_MMEM: begin
        vc_rdata = msw_rdata;
        vc_stall = msw_stall;

        msw_ren  = vc_ren;
        msw_wen  = vc_wen;
      end
    endcase
  end
endmodule
