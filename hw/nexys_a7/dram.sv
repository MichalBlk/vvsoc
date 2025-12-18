`default_nettype none

`include "isa.svh"
`include "soc.svh"

module dram
  import isa_pkg::*;
  import soc_pkg::*;
  import board_pkg::*;
(
  input  logic                      clk,
  input  logic                      dram_clk,
  input  logic                      nrst,

  input  logic [MMEM_ADDRLEN - 1:0] mmem_addr,
  input  logic [MMEM_DATALEN - 1:0] mmem_wdata,
  input  logic                      mmem_ren,
  input  logic                      mmem_wen,
  output logic [MMEM_DATALEN - 1:0] mmem_rdata,
  output logic                      mmem_done,
  output logic                      mmem_on,

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
  output logic                      ddr2_odt
);
  localparam DRAM_DATALEN = MMEM_DATALEN / 2;
  localparam MIG_ADDRLEN  = 27;

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_PREREAD,
    ST_READ,
    ST_PREWRITE,
    ST_WRITE_L,
    ST_WRITE_H
  } state_t;

  typedef enum logic [2:0] {
    CMD_WRITE,
    CMD_READ
  } cmd_t;

  state_t                    state, state_r;

  cmd_t                      cmd, cmd_r;
  logic                      en, en_r;
  logic                      finished, finished_r;
  logic [MMEM_DATALEN - 1:0] rdata, rdata_r;
  logic [DRAM_DATALEN - 1:0] wdata, wdata_r;
  logic                      wend, wend_r;
  logic                      wren, wren_r;

  logic                      fs_ren;
  logic                      fs_wen;
  logic                      fs_finished;

  logic                      ffs_on;

  logic [MIG_ADDRLEN - 1:0]  mig_addr;
  logic [DRAM_DATALEN - 1:0] mig_rdata;
  logic                      mig_rend;
  logic                      mig_rvalid;
  logic                      mig_rdy;
  logic                      mig_wrdy;
  logic                      mig_ui_clk;
  logic                      mig_ui_srst;
  logic                      mig_ui_nrst;

  flag_sync REN_SYNC(
    .src_clk  (clk),
    .src_nrst (nrst),
    .src_flag (mmem_ren),
    .dst_clk  (mig_ui_clk),
    .dst_nrst (mig_ui_nrst),
    .dst_flag (fs_ren)
  );

  flag_sync WEN_SYNC(
    .src_clk  (clk),
    .src_nrst (nrst),
    .src_flag (mmem_wen),
    .dst_clk  (mig_ui_clk),
    .dst_nrst (mig_ui_nrst),
    .dst_flag (fs_wen)
  );

  flag_sync FINISHED_SYNC(
    .src_clk  (mig_ui_clk),
    .src_nrst (mig_ui_nrst),
    .src_flag (finished_r),
    .dst_clk  (clk),
    .dst_nrst (nrst),
    .dst_flag (fs_finished)
  );

  flip_flop_sync #(
    .WIDTH (1),
    .CNT   (2)
  ) ON_SYNC(
    .clk  (clk),
    .nrst (nrst),
    .src  (mig_ui_nrst),
    .res  (ffs_on)
  );

  assign mig_ui_nrst = !mig_ui_srst;

  mig MIG(
    .ddr2_addr           (ddr2_addr),
    .ddr2_ba             (ddr2_ba),
    .ddr2_cas_n          (ddr2_cas_n),
    .ddr2_ck_n           (ddr2_ck_n),
    .ddr2_ck_p           (ddr2_ck_p),
    .ddr2_cke            (ddr2_cke),
    .ddr2_ras_n          (ddr2_ras_n),
    .ddr2_we_n           (ddr2_we_n),
    .ddr2_dq             (ddr2_dq),
    .ddr2_dqs_n          (ddr2_dqs_n),
    .ddr2_dqs_p          (ddr2_dqs_p),
    .ddr2_cs_n           (ddr2_cs_n),
    .ddr2_dm             (ddr2_dm),
    .ddr2_odt            (ddr2_odt),
    .app_addr            (mmem_addr),
    .app_cmd             (cmd_r),
    .app_en              (en_r),
    .app_wdf_data        (wdata_r),
    .app_wdf_end         (wend_r),
    .app_wdf_mask        (8'h00),
    .app_wdf_wren        (wren_r),
    .app_rd_data         (mig_rdata),
    .app_rd_data_end     (mig_rend),
    .app_rd_data_valid   (mig_rvalid),
    .app_rdy             (mig_rdy),
    .app_wdf_rdy         (mig_wrdy),
    .app_sr_req          (0),
    .app_ref_req         (0),
    .app_zq_req          (0),
    .app_sr_active       (),
    .app_ref_ack         (),
    .app_zq_ack          (),
    .ui_clk              (mig_ui_clk),
    .ui_clk_sync_rst     (mig_ui_srst),
    .init_calib_complete (),
    .sys_clk_i           (dram_clk),
    .sys_rst             (nrst)
  );

  /*
   * Reading
   */
  always_comb begin
    rdata = rdata_r;

    if (mig_rvalid && ((state_r == ST_PREREAD && mig_rdy) || state_r == ST_READ)) begin
      if (!mig_rend)
        rdata[0+:DRAM_DATALEN] = mig_rdata;
      else
        rdata[DRAM_DATALEN+:DRAM_DATALEN] = mig_rdata;
    end
  end

  always_ff @(posedge mig_ui_clk)
    rdata_r <= rdata;

  /*
   * Command handling
   */
  always_comb begin
    cmd = cmd_r;
    en  = en_r;

    unique0 case (state_r)
      ST_IDLE:
        if (fs_ren) begin
          cmd = CMD_READ;
          en  = 1;
        end else if (fs_wen) begin
          cmd = CMD_WRITE;
          en  = 1;
        end

      ST_PREREAD, ST_PREWRITE:
        if (mig_rdy)
          en = 0;
    endcase
  end

  always_ff @(posedge mig_ui_clk)
    if (mig_ui_srst)
      en_r <= 0;
    else begin
      cmd_r <= cmd;
      en_r  <= en;
    end

  /*
   * Writing
   */
  always_comb begin
    wdata = wdata_r;
    wend  = wend_r;
    wren  = wren_r;

    unique0 case (state_r)
      ST_IDLE:
        wren = 0;

      ST_WRITE_L:
        if (mig_wrdy) begin
          wdata = mmem_wdata[0+:DRAM_DATALEN];
          wend  = 0;
          wren  = 1;
        end 

      ST_WRITE_H:
        if (mig_wrdy) begin
          wdata = mmem_wdata[DRAM_DATALEN+:DRAM_DATALEN];
          wend  = 1;
          wren  = 1;
        end
    endcase
  end

  always_ff @(posedge mig_ui_clk)
    if (mig_ui_srst)
      wren_r <= 0;
    else begin
      wdata_r <= wdata;
      wend_r  <= wend;
      wren_r  <= wren;
    end

  /*
   * State transitions
   */
  always_comb begin
    state    = state_r;
    finished = finished_r;

    unique0 case (state_r)
      ST_IDLE: begin
        if (fs_ren)
          state = ST_PREREAD;
        else if (fs_wen)
          state = ST_PREWRITE;

        finished = 0;
      end

      ST_PREREAD:
        if (mig_rdy)
          state = ST_READ;

      ST_READ:
        if (mig_rvalid && mig_rend) begin
          state    = ST_IDLE;
          finished = 1;
        end

      ST_PREWRITE:
        if (mig_rdy)
          state = ST_WRITE_L;

      ST_WRITE_L:
        if (mig_wrdy)
          state = ST_WRITE_H;

      ST_WRITE_H:
        if (mig_wrdy) begin
          state    = ST_IDLE;
          finished = 1;
        end
    endcase
  end

  always_ff @(posedge mig_ui_clk)
    if (mig_ui_srst) begin
      state_r    <= ST_IDLE;
      finished_r <= 0;
    end else begin
      state_r    <= state;
      finished_r <= finished;
    end

  /*
   * Output signals
   */
  assign mmem_rdata = rdata_r;
  assign mmem_done  = fs_finished;
  assign mmem_on    = ffs_on;
endmodule
