`default_nettype none

`include "isa.svh"
`include "soc.svh"

module flash
  import isa_pkg::*;
  import soc_pkg::*;
  import board_pkg::*;
(
  input  logic                    clk,
  input  logic                    nrst,

  input  logic [FL_ADDRLEN - 1:0] asw_addr,
  input  logic                    asw_nsign,
  input  logic                    asw_ren,
  output logic [XLEN - 1:0]       asw_rdata,
  output logic                    asw_stall
);
  logic [BLEN - 1:0] mem [FLSZ - 1:0];

  initial begin
    $display("[FL] Loading OpenSBI...");
    $readmemh("opensbi.mif", mem, FL_OPENSBI_OFF);

    $display("[FL] Loading dtb...");
    $readmemh("vrvsoc.mif", mem, FL_DTB_OFF);

    $display("[FL] Loading kernel...");
    $readmemh("kernel.mif", mem, FL_KERNEL_OFF);

    $display("[FL] Loading initrd...");
    $readmemh("initrd.mif", mem, FL_INITRD_OFF);

    $display("[FL] Images loaded successfully");
  end

  /*
   * Application switch signals
   */
  assign asw_rdata = mem[asw_addr];
  assign asw_stall = 0;
endmodule
