`include "isa.svh"
`include "soc.svh"

module spi_flash
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                    clk,
  input  logic                    fl_clk,
  input  logic                    nrst,

  input  logic [FL_ADDRLEN - 1:0] fl_addr,
  input  logic                    fl_ren,
  output logic [BLEN - 1:0]       fl_rdata,
  output logic                    fl_done,
  output logic                    fl_on,

  input  logic                    miso,
  output logic                    mosi,
  output logic                    sclk,
  output logic                    ncs
);
`default_nettype none

  localparam TICK         = 2;
  localparam MS           = 100000;
  localparam SPIFL_CNTLEN = 30;

  localparam CMD_RESET    = 8'hf0;
  localparam CMD_READ     = 8'h03;

  typedef enum logic [3:0] {
    ST_WAIT,
    ST_RESET_CS,
    ST_RESET_CMD,
    ST_RESET_WAIT,
    ST_IDLE,
    ST_RD_CS,
    ST_RD_CMD,
    ST_RD_ADDR,
    ST_RD_DATA
  } state_t;

  state_t                    state, state_r;

  logic [SPIFL_CNTLEN - 1:0] cnt, cnt_r;
  logic                      clk_cnt, clk_cnt_r;
  logic                      ready, ready_r;
  logic                      pending, pending_r;
  logic                      finished, finished_r;
  logic [BLEN - 1:0]         rdata, rdata_r;
  logic [FL_ADDRLEN - 1:0]   wshr, wshr_r;
  logic [BLEN - 1:0]         rshr, rshr_r;
  logic                      sclk_en, sclk_en_r;
  logic                      cs, cs_r;
  logic                      clk_50mhz;

  logic                      fs_ren;
  logic                      fs_finished;

  logic                      ffs_on;

  flag_sync REN_SYNC(
    .src_clk  (clk),
    .src_nrst (nrst),
    .src_flag (fl_ren),
    .dst_clk  (fl_clk),
    .dst_nrst (nrst),
    .dst_flag (fs_ren)
  );

  flag_sync FINISHED_SYNC(
    .src_clk  (fl_clk),
    .src_nrst (nrst),
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
    .src  (ready_r),
    .res  (ffs_on)
  );

  /*
   * Clock counter
   */
  assign clk_cnt = clk_cnt_r ^ 1;

  always_ff @(posedge fl_clk, negedge nrst)
    if (!nrst)
      clk_cnt_r <= 1;
    else
      clk_cnt_r <= clk_cnt;

  assign clk_50mhz = clk_cnt_r;

  /*
   * Chip select handling
   */
  always_comb begin
    cs = cs_r;

    unique0 case (state_r)
      ST_WAIT:
        if (cnt_r == MS - 1)
          cs = 1;

      ST_IDLE:
        if (fs_ren)
          cs = 1;

      ST_RESET_CMD, ST_RD_DATA:
        if (cnt_r == 8 * TICK - 2)
          cs = 0;
    endcase
  end

  always_ff @(posedge fl_clk, negedge nrst)
    if (!nrst)
      cs_r <= 0;
    else
      cs_r <= cs;

  /*
   * Slave clock handling
   */
  always_comb begin
    sclk_en = sclk_en_r;

    unique0 case (state_r)
      ST_RESET_CS, ST_RD_CS:
        if (!cnt_r)
          sclk_en = 1;

      ST_RESET_CMD, ST_RD_DATA:
        if (cnt_r == 8 * TICK - 2)
          sclk_en = 0;
    endcase
  end

  always_ff @(posedge fl_clk, negedge nrst)
    if (!nrst)
      sclk_en_r <= 0;
    else
      sclk_en_r <= sclk_en;

  /*
   * Serial output
   */
  always_comb begin
    wshr = wshr_r;

    if (!(cnt_r & 1))
      wshr = wshr_r << 1;

    unique0 case (state_r)
      ST_RESET_CS:
        wshr[23:16] = CMD_RESET;

      ST_RD_CS:
        wshr[23:16] = CMD_READ;

      ST_RD_CMD:
        if (cnt_r == 8 * TICK - 2)
          wshr = fl_addr;
    endcase
  end

  always_ff @(posedge fl_clk)
    wshr_r <= wshr;

  /*
   * Serial input
   */
  assign rshr = !(cnt_r & 1) ? {rshr_r[6:0], miso} : rshr_r;

  always_ff @(posedge fl_clk)
    rshr_r <= rshr;

  always_comb begin
    rdata = rdata_r;

    if (state_r == ST_RD_DATA && cnt_r == 8 * TICK - 1)
      rdata = rshr_r;
  end

  always_ff @(posedge fl_clk)
    rdata_r <= rdata;

  /*
   * State and counter handling
   */
  always_comb begin
    state    = state_r;
    cnt      = cnt_r + 1;
    ready    = ready_r;
    pending  = pending_r;
    finished = finished_r;

    unique0 case (state_r)
      ST_WAIT:
        if (cnt_r == MS - 1) begin
          state = ST_RESET_CS;
          cnt   = 0;
        end

      ST_RESET_CS:
        if (cnt_r == TICK - 1) begin
          state = ST_RESET_CMD;
          cnt   = 0;
        end

      ST_RESET_WAIT:
        if (cnt_r == MS - 1) begin
          state = ST_IDLE;
          cnt   = 0;
          ready = 1;
        end

      ST_IDLE: begin
        if (fs_ren)
          pending = 1;

        if (pending_r && (cnt_r & 1)) begin
          state = ST_RD_CS;
          cnt   = 0;
        end

        finished = 0;
      end

      ST_RD_CS:
        if (cnt_r == TICK - 1) begin
          state = ST_RD_CMD;
          cnt   = 0;
        end

      ST_RD_ADDR:
        if (cnt_r == 24 * TICK - 1) begin
          state = ST_RD_DATA;
          cnt   = 0;
        end

      ST_RD_DATA:
        if (cnt_r == 8 * TICK - 1) begin
          state    = ST_IDLE;
          cnt      = 0;
          pending  = 0;
          finished = 1;
        end

      default:
        if (cnt_r == 8 * TICK - 1) begin
          state = state_t'(state_r + 1);
          cnt   = 0;
        end
    endcase
  end

  always_ff @(posedge fl_clk, negedge nrst)
    if (!nrst) begin
      state_r    <= ST_WAIT;
      cnt_r      <= 0;
      ready_r    <= 0;
      pending_r  <= 0;
      finished_r <= 0;
    end else begin
      state_r    <= state;
      cnt_r      <= cnt;
      ready_r    <= ready;
      pending_r  <= pending;
      finished_r <= finished;
    end

  /*
   * SPI output signals
   */ 
  assign mosi = wshr_r[23];
  assign sclk = sclk_en_r ? clk_50mhz : 1;
  assign ncs  = !cs_r;

  /*
   * Flash output signals
   */
  assign fl_rdata = rdata_r;
  assign fl_done  = fs_finished;
  assign fl_on    = ffs_on;
endmodule
