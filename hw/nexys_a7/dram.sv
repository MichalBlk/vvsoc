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
  localparam DRAM_DATALEN = 64;
  localparam DRAM_CNTLEN  = $clog2(MMEM_DATALEN / DRAM_DATALEN);
  localparam MIG_ADDRLEN  = 27;

  typedef enum logic [2:0] {
    ST_IDLE,
    ST_PREREAD,
    ST_READ,
    ST_PREWRITE,
    ST_WRITE
  } state_t;

  typedef enum logic [1:0] {
    CMD_WRITE,
    CMD_READ
  } cmd_t;

  state_t                    state, state_r;

  cmd_t                      cmd, cmd_r;
  logic                      en, en_r;
  logic                      finished, finished_r;
  logic [MMEM_DATALEN - 1:0] rdata, rdata_r;
  logic [MMEM_DATALEN - 1:0] wdata, wdata_r;
  logic                      wren;
  logic                      wend;
  logic [DRAM_CNTLEN - 1:0]  cnt, cnt_r;
  logic                      last;

  logic                      fs_ren;
  logic                      fs_wen;
  logic                      fs_finished;

  logic                      ffs_on;

  logic [DRAM_DATALEN - 1:0] mig_rdata;
  logic                      mig_rvalid;
  logic                      mig_rdy;
  logic [DRAM_DATALEN - 1:0] mig_wdata;
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
    .app_wdf_data        (mig_wdata),
    .app_wdf_end         (wend),
    .app_wdf_mask        (8'h00),
    .app_wdf_wren        (wren),
    .app_rd_data         (mig_rdata),
    .app_rd_data_end     (),
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
   * Reading
   */
  always_comb begin
    rdata = rdata_r;

    if (state_r == ST_READ && mig_rvalid)
      rdata = {mig_rdata, rdata_r[MMEM_DATALEN - 1:DRAM_DATALEN]};
  end

  always_ff @(posedge mig_ui_clk)
    rdata_r <= rdata;

  /*
   * Writing
   */
  always_comb begin
    wdata = wdata_r;
    wren  = 0;
    wend  = 0;

    unique0 case (state_r)
      ST_IDLE:
        wdata = mmem_wdata;

      ST_WRITE:
        if (mig_wrdy) begin
          wdata = wdata_r >> DRAM_DATALEN;
          wren  = 1;
          wend  = last;
        end
    endcase
  end

  always_ff @(posedge mig_ui_clk)
    wdata_r <= wdata;

  assign mig_wdata = wdata_r[0+:DRAM_DATALEN];

  /*
   * Counter handling
   */
  assign last = cnt_r == DRAM_CNTLEN - 1;

  always_comb begin
    cnt = cnt_r;

    unique0 case (state_r)
      ST_READ:
        if (mig_rvalid)
          cnt = cnt_r + 1;

      ST_WRITE:
        if (mig_wrdy)
          cnt = cnt_r + 1;
    endcase
  end

  always_ff @(posedge mig_ui_clk)
    if (mig_ui_srst)
      cnt_r <= 0;
    else
      cnt_r <= cnt;

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
        if (mig_rvalid && last) begin
          state    = ST_IDLE;
          finished = 1;
        end

      ST_PREWRITE:
        if (mig_rdy)
          state = ST_WRITE;

      ST_WRITE:
        if (mig_wrdy && last) begin
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
