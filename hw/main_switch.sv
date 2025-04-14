`default_nettype none

`include "isa_pkg.svh"
`include "soc_pkg.svh"

module main_switch
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic [XLEN - 1:0]         asw_addr,
  input  logic [XLEN - 1:0]         asw_wdata,
  input  logic [XLENB_LOG - 1:0]    asw_size,
  input  logic                      asw_nsign,
  input  logic                      asw_ren,
  input  logic                      asw_wen,
  output logic [XLEN - 1:0]         asw_rdata,
  output logic                      asw_stall,

  input  logic [XLEN - 1:0]         vsw_addr,
  input  logic [XLEN - 1:0]         vsw_wdata,
  input  logic [XLENB_LOG - 1:0]    vsw_size,
  input  logic                      vsw_nsign,
  input  logic                      vsw_ren,
  input  logic                      vsw_wen,
  output logic [XLEN - 1:0]         vsw_rdata,
  output logic                      vsw_stall,

  input  logic                      vmgr_busy,

  input  logic [XLEN - 1:0]         mmem_rdata,
  input  logic                      mmem_stall,
  output logic [MMEM_ADDRLEN - 1:0] mmem_addr,
  output logic [XLEN - 1:0]         mmem_wdata,
  output logic [XLENB_LOG - 1:0]    mmem_size,
  output logic                      mmem_nsign,
  output logic                      mmem_ren,
  output logic                      mmem_wen
);
  assign asw_rdata = mmem_rdata;

  assign vsw_rdata = mmem_rdata;

  always_comb begin
    asw_stall = 0;

    vsw_rdata = 'bx;
    vsw_stall = 0;

    if (vmgr_busy) begin
      vsw_stall = mmem_stall;

      mmem_addr  = vsw_addr;
      mmem_wdata = vsw_wdata;
      mmem_size  = vsw_size;
      mmem_nsign = vsw_nsign;
      mmem_ren   = vsw_ren;
      mmem_wen   = vsw_wen;
    end else begin
      asw_stall = mmem_stall;

      mmem_addr  = asw_addr;
      mmem_wdata = asw_wdata;
      mmem_size  = asw_size;
      mmem_nsign = asw_nsign;
      mmem_ren   = asw_ren;
      mmem_wen   = asw_wen;
    end
  end
endmodule
