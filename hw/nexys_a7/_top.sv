`default_nettype none

`include "board.svh"

module _top
  import board_pkg::*;
(
  input  logic                      CLK100MHZ,
  input  logic                      CPU_RESETN,

  inout  logic [DDR2_DQLEN - 1:0]   ddr2_dq,
  inout  logic [DDR2_DQSLEN - 1:0]  ddr2_dqs_n,
  inout  logic [DDR2_DQSLEN - 1:0]  ddr2_dqs_p,
  output logic [DDR2_ADDRLEN - 1:0] ddr2_addr,
  output logic [DDR2_BALEN - 1:0]   ddr2_ba,
  output logic                      ddr2_ras_n,
  output logic                      ddr2_cas_n,
  output logic                      ddr2_we_n,
  output logic                      ddr2_ck_p,
  output logic                      ddr2_ck_n,
  output logic                      ddr2_cke,
  output logic                      ddr2_cs_n,
  output logic [DDR2_DMLEN - 1:0]   ddr2_dm,
  output logic                      ddr2_odt,

  input  logic                      QSPI_MISO,
  output logic                      QSPI_MOSI,
  output logic                      QSPI_WPN,
  output logic                      QSPI_RESETN,
  output logic                      QSPI_CSN,

  input  logic                      UART_TXD_IN,
  output logic                      UART_RXD_OUT
);
  logic       cpu_clk;
  logic       dram_clk;
  logic       fl_clk;

  logic       qspi_sclk;
  logic [3:0] dc;

  pll PLL(
    .clk_in   (CLK100MHZ),
    .clk_cpu  (cpu_clk),
    .clk_dram (dram_clk),
    .clk_fl   (fl_clk)
  );

  STARTUPE2 STARTUPE2_0(
    .CFGCLK    (dc[0]),
    .CFGMCLK   (dc[1]),
    .EOS       (dc[2]),
    .PREQ      (dc[3]),
    .CLK       (0),
    .GSR       (0),
    .GTS       (0),
    .KEYCLEARB (0),
    .PACK      (0),
    .USRCCLKO  (qspi_sclk),
    .USRCCLKTS (0),
    .USRDONEO  (1),
    .USRDONETS (1)
  );

  top TOP(
    .clk        (cpu_clk),
    .nrst       (CPU_RESETN),
    .dram_clk   (dram_clk),
    .fl_clk     (fl_clk),
    .ddr2_addr  (ddr2_addr),
    .ddr2_ba    (ddr2_ba),
    .ddr2_cas_n (ddr2_cas_n),
    .ddr2_ck_n  (ddr2_ck_n),
    .ddr2_ck_p  (ddr2_ck_p),
    .ddr2_cke   (ddr2_cke),
    .ddr2_ras_n (ddr2_ras_n),
    .ddr2_we_n  (ddr2_we_n),
    .ddr2_dq    (ddr2_dq),
    .ddr2_dqs_n (ddr2_dqs_n),
    .ddr2_dqs_p (ddr2_dqs_p),
    .ddr2_cs_n  (ddr2_cs_n),
    .ddr2_dm    (ddr2_dm),
    .ddr2_odt   (ddr2_odt),
    .fl_miso    (QSPI_MISO),
    .fl_mosi    (QSPI_MOSI),
    .fl_sclk    (qspi_sclk),
    .fl_ncs     (QSPI_CSN),
    .rx         (UART_TXD_IN),
    .tx         (UART_RXD_OUT)
  );

  assign QSPI_WPN    = 1;
  assign QSPI_RESETN = 1;
endmodule
