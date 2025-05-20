`default_nettype none

`include "isa.svh"
`include "virtio.svh"
`include "soc.svh"

module virtio_manager
  import isa_pkg::*;
  import virtio_pkg::*;
  import soc_pkg::*;
(
  input  logic                          clk,
  input  logic                          nrst,

  input  logic                          ac_stallable,

  input  logic [BLEN - 1:0]             dbgc_byte,
  input  logic                          dbgc_wen,
  output logic                          dbgc_stall,

  input  logic [BLEN - 1:0]             uart_rx_byte,
  input  logic                          uart_rx_ready,
  input  logic                          uart_tx_busy,
  output logic [BLEN - 1:0]             uart_tx_byte,
  output logic                          uart_tx_start,

  input  logic [VGA_POSLEN - 1:0]       vga_x,
  input  logic [VGA_POSLEN - 1:0]       vga_y,
  output logic [VGA_COLORLEN - 1:0]     vga_r,
  output logic [VGA_COLORLEN - 1:0]     vga_g,
  output logic [VGA_COLORLEN - 1:0]     vga_b,

  output logic                          vc_nsrst,
  output logic [XLEN - 1:0]             vc_srstarg,

  input  logic [VMGR_ADDRLEN - 1:0]     vsw_addr,
  input  logic [XLEN - 1:0]             vsw_wdata,
  input  logic                          vsw_ren,
  input  logic                          vsw_wen,
  output logic [XLEN - 1:0]             vsw_rdata,
  output logic                          vsw_stall,

  input  logic [VCD_QUEUECNT - 1:0]     vcd_queue_rdy,
  input  logic [VCD_QUEUECNT_LOG - 1:0] vcd_queue_num,
  input  logic                          vcd_notify,
  input  logic                          vcd_drvok,
  output logic                          vcd_used,

  input  logic [VGD_QUEUECNT - 1:0]     vgd_queue_rdy,
  input  logic [VGD_QUEUECNT_LOG - 1:0] vgd_queue_num,
  input  logic                          vgd_notify,
  input  logic                          vgd_drvok,
  output logic                          vgd_used,

  output logic                          busy
);
  localparam VMGR_UART_RX_FIFO_ADDRLEN   = $clog2(VMGR_UART_RX_FIFOSZ);
  localparam VMGR_UART_RX_FIFO_CNTLEN    = $clog2(VMGR_UART_RX_FIFOSZ + 1);

  localparam VMGR_VGA_FRAME_FIFO_ADDRLEN = $clog2(VMGR_VGA_FRAME_FIFOSZ);
  localparam VMGR_VGA_FRAME_FIFO_CNTLEN  = $clog2(VMGR_VGA_FRAME_FIFOSZ + 1);

  typedef enum logic [1:0] {
    ST_IDLE,
    ST_BUSY,
    ST_FINISH
  } state_t;

  state_t                                   state, state_r;
  vmgr_dev_t                                dev, dev_r;
  logic [VMGR_MAXQUEUECNT_LOG - 1:0]        pend_queue_num, pend_queue_num_r;
  vmgr_exit_code_t                          exit_code, exit_code_r;
  logic [VMGR_DELAY_CNTLEN - 1:0]           delay_cnt, delay_cnt_r;
  logic                                     finished;

  logic [BLEN - 1:0]                        uart_rx_fifo [VMGR_UART_RX_FIFOSZ - 1:0],
    uart_rx_fifo_r [VMGR_UART_RX_FIFOSZ - 1:0];
  logic [VMGR_UART_RX_FIFO_ADDRLEN - 1:0]   uart_rx_fifo_head, uart_rx_fifo_head_r;
  logic [VMGR_UART_RX_FIFO_ADDRLEN - 1:0]   uart_rx_fifo_tail, uart_rx_fifo_tail_r;
  logic [VMGR_UART_RX_FIFO_CNTLEN - 1:0]    uart_rx_fifo_cnt, uart_rx_fifo_cnt_r;

  logic [VGA_COLORLEN - 1:0]
    vga_frame_fifo_r [VMGR_VGA_FRAME_FIFOSZ - 1:0][VGA_HEIGHT - 1:0][VGA_WIDTH - 1:0];
  logic [VGA_COLORLEN - 1:0]
    vga_frame_fifo_g [VMGR_VGA_FRAME_FIFOSZ - 1:0][VGA_HEIGHT - 1:0][VGA_WIDTH - 1:0];
  logic [VGA_COLORLEN - 1:0]
    vga_frame_fifo_b [VMGR_VGA_FRAME_FIFOSZ - 1:0][VGA_HEIGHT - 1:0][VGA_WIDTH - 1:0];
  logic [VMGR_VGA_FRAME_FIFO_ADDRLEN - 1:0] vga_frame_fifo_head, vga_frame_fifo_head_r;
  logic [VMGR_VGA_FRAME_FIFO_ADDRLEN - 1:0] vga_frame_fifo_tail, vga_frame_fifo_tail_r;
  logic [VMGR_VGA_FRAME_FIFO_CNTLEN - 1:0]  vga_frame_fifo_cnt, vga_frame_fifo_cnt_r;
  logic [VGA_POSLEN - 1:0]                  vga_fx, vga_fx_r;
  logic [VGA_POSLEN - 1:0]                  vga_fy, vga_fy_r;
  logic                                     vga_rdy, vga_rdy_r;
  logic                                     vga_update;
  logic                                     vga_last_pixel;
  logic                                     vga_stall;

  logic [VMGR_QUEUE_NOTIF_CNTLEN - 1:0]
    queue_notif_cnt[VMGR_DEVCNT - 1:0][VMGR_MAXQUEUECNT - 1:0],
    queue_notif_cnt_r[VMGR_DEVCNT - 1:0][VMGR_MAXQUEUECNT - 1:0];

  logic [VCD_QUEUECNT_LOG - 1:0]            vcd_pend_queue_num;
  logic                                     vcd_pending;

  logic [VGD_QUEUECNT_LOG - 1:0]            vgd_pend_queue_num;
  logic                                     vgd_pending;

  /*
   * UART receiving
   */
  always_comb begin
    for (int i = 0; i < VMGR_UART_RX_FIFOSZ; i++)
      uart_rx_fifo[i] = uart_rx_fifo_r[i];

    uart_rx_fifo_head = uart_rx_fifo_head_r;
    uart_rx_fifo_tail = uart_rx_fifo_tail_r;
    uart_rx_fifo_cnt  = uart_rx_fifo_cnt_r;

    if (uart_rx_fifo_cnt_r && vsw_ren && vsw_addr == VMGR_REG_UART_RX) begin
      uart_rx_fifo_head = uart_rx_fifo_head_r + 1;
      if (!uart_rx_ready)
        uart_rx_fifo_cnt = uart_rx_fifo_cnt_r - 1;
      else begin
        uart_rx_fifo[uart_rx_fifo_tail_r] = uart_rx_byte;
        uart_rx_fifo_tail                 = uart_rx_fifo_tail_r + 1;
      end
    end else if (uart_rx_ready && uart_rx_fifo_cnt_r != VMGR_UART_RX_FIFOSZ) begin
      uart_rx_fifo[uart_rx_fifo_tail_r] = uart_rx_byte;
      uart_rx_fifo_tail                 = uart_rx_fifo_tail_r + 1;
      uart_rx_fifo_cnt                  = uart_rx_fifo_cnt_r + 1;
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      uart_rx_fifo_head_r <= 0;
      uart_rx_fifo_tail_r <= 0;
      uart_rx_fifo_cnt_r  <= 0;
    end else begin
      for (int i = 0; i < VMGR_UART_RX_FIFOSZ; i++)
        uart_rx_fifo_r[i] <= uart_rx_fifo[i];

      uart_rx_fifo_head_r <= uart_rx_fifo_head;
      uart_rx_fifo_tail_r <= uart_rx_fifo_tail;
      uart_rx_fifo_cnt_r  <= uart_rx_fifo_cnt;
    end

  /*
   * UART transmitting
   */
  assign uart_tx_byte  = dbgc_wen ? dbgc_byte : vsw_wdata;
  assign uart_tx_start = dbgc_wen || (vsw_wen && vsw_addr == VMGR_REG_UART_TX);

  /*
   * VGA frame updates
   */
  logic [VGA_COLORLEN - 1:0] vga_wr;
  logic [VGA_COLORLEN - 1:0] vga_wg;
  logic [VGA_COLORLEN - 1:0] vga_wb;

  assign vga_update               = vsw_wen && vsw_addr == VMGR_REG_VGA_UPDATE;

  assign {vga_wr, vga_wg, vga_wb} = (3 * VGA_COLORLEN)'(vsw_wdata);

  always_ff @(posedge clk)
    if (vga_update) begin
      vga_frame_fifo_r[vga_frame_fifo_tail_r][vga_fy_r][vga_fx_r] <= vga_wr;
      vga_frame_fifo_g[vga_frame_fifo_tail_r][vga_fy_r][vga_fx_r] <= vga_wg;
      vga_frame_fifo_b[vga_frame_fifo_tail_r][vga_fy_r][vga_fx_r] <= vga_wb;
    end

  /*
   * VGA frame position calculation
   */
  always_comb begin
    vga_fx = vga_fx_r;
    vga_fy = vga_fy_r;

    if (vga_update && !(vga_last_pixel && vga_stall)) begin
      if (vga_fx_r == VGA_WIDTH - 1) begin
        vga_fx = 0;
        if (vga_fy_r == VGA_HEIGHT - 1)
          vga_fy = 0;
        else
          vga_fy = vga_fy_r + 1;
      end else
        vga_fx = vga_fx_r + 1;
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      vga_fx_r <= 0;
      vga_fy_r <= 0;
    end else begin
      vga_fx_r <= vga_fx;
      vga_fy_r <= vga_fy;
    end

  /*
   * VGA frame fifo management
   */
  logic vga_flush;

  assign vga_last_pixel = vga_fx_r == VGA_WIDTH - 1 && vga_fy_r == VGA_HEIGHT - 1;
  assign vga_stall      = vga_frame_fifo_tail == vga_frame_fifo_tail_r;

  assign vga_flush      = vga_update && vga_last_pixel;

  always_comb begin
    vga_frame_fifo_head = vga_frame_fifo_head_r;
    vga_frame_fifo_tail = vga_frame_fifo_tail_r;
    vga_frame_fifo_cnt  = vga_frame_fifo_cnt_r;
    vga_rdy             = vga_rdy_r;

    if (vga_y == VGA_HEIGHT && !vga_x) begin
      if (!vga_rdy_r)
        vga_rdy = vga_frame_fifo_cnt_r != 0;
      else if (vga_frame_fifo_cnt_r != 1) begin
        vga_frame_fifo_head = vga_frame_fifo_head_r + 1;
        vga_frame_fifo_cnt  = vga_frame_fifo_cnt_r - 1;
      end
    end else if (vga_flush && vga_frame_fifo_cnt_r != VMGR_VGA_FRAME_FIFOSZ) begin
      vga_frame_fifo_tail = vga_frame_fifo_tail_r + 1;
      vga_frame_fifo_cnt  = vga_frame_fifo_cnt_r + 1;
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      vga_frame_fifo_head_r <= 0;
      vga_frame_fifo_tail_r <= 0;
      vga_frame_fifo_cnt_r  <= 0;
      vga_rdy_r             <= 0;
    end else begin
      vga_frame_fifo_head_r <= vga_frame_fifo_head;
      vga_frame_fifo_tail_r <= vga_frame_fifo_tail;
      vga_frame_fifo_cnt_r  <= vga_frame_fifo_cnt;
      vga_rdy_r             <= vga_rdy;
    end

  /*
   * VGA signals
   */
  assign vga_r = vga_rdy_r ? vga_frame_fifo_r[vga_frame_fifo_head_r][vga_y][vga_x] : 0;
  assign vga_g = vga_rdy_r ? vga_frame_fifo_g[vga_frame_fifo_head_r][vga_y][vga_x] : 0;
  assign vga_b = vga_rdy_r ? vga_frame_fifo_b[vga_frame_fifo_head_r][vga_y][vga_x] : 'hff;

  /*
   * Debug console signals
   */
  assign dbgc_stall = dbgc_wen && uart_tx_busy;

  /*
   * VirtIO core signals
   */
  assign vc_nsrst   = !(state_r == ST_IDLE);
  assign vc_srstarg = {dev_r, pend_queue_num_r};

  /*
   * VirtIO switch signals
   */
  assign finished  = vsw_wen && vsw_addr == VMGR_REG_FINISH;

  assign vsw_rdata = uart_rx_fifo_cnt_r ? uart_rx_fifo_r[uart_rx_fifo_head_r] : {XLEN{1'b1}};
  assign vsw_stall = (vsw_wen && vsw_addr == VMGR_REG_UART_TX && uart_tx_busy) ||
    (vga_flush && vga_stall);

  /*
   * VirtIO console signals
   */
  assign vcd_used = state_r == ST_FINISH && dev_r == VMGR_DEV_VCD &&
    exit_code_r == VMGR_EXIT_SUCCESS;

  /*
   * VirtIO GPU signals
   */
  assign vgd_used = state_r == ST_FINISH && dev_r == VMGR_DEV_VGD &&
    exit_code_r == VMGR_EXIT_SUCCESS;

  /*
   * Queue notifications
   */
  logic vcd_notif_cnt_max;
  logic vgd_notif_cnt_max;

  assign vcd_notif_cnt_max =
    queue_notif_cnt_r[VMGR_DEV_VCD][vcd_queue_num] == {VMGR_QUEUE_NOTIF_CNTLEN{1'b1}};
  assign vgd_notif_cnt_max =
    queue_notif_cnt_r[VMGR_DEV_VGD][vgd_queue_num] == {VMGR_QUEUE_NOTIF_CNTLEN{1'b1}};

  always_comb begin
    for (int i = 0; i < VMGR_DEVCNT; i++)
      for (int j = 0; j < VMGR_MAXQUEUECNT; j++)
        queue_notif_cnt[i][j] = queue_notif_cnt_r[i][j];

    unique0 case (state_r)
      ST_IDLE: begin
        if (vcd_notify && !vcd_notif_cnt_max)
          queue_notif_cnt[VMGR_DEV_VCD][vcd_queue_num] =
            queue_notif_cnt_r[VMGR_DEV_VCD][vcd_queue_num] + 1;

        if (vgd_notify && !vgd_notif_cnt_max)
          queue_notif_cnt[VMGR_DEV_VGD][vgd_queue_num] =
            queue_notif_cnt_r[VMGR_DEV_VGD][vgd_queue_num] + 1;
      end

      ST_FINISH:
        queue_notif_cnt[dev_r][pend_queue_num_r] = queue_notif_cnt[dev_r][pend_queue_num_r] - 1;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      for (int i = 0; i < VMGR_DEVCNT; i++)
        for (int j = 0; j < VMGR_MAXQUEUECNT; j++)
          queue_notif_cnt_r[i][j] <= 0;
    else
      for (int i = 0; i < VMGR_DEVCNT; i++)
        for (int j = 0; j < VMGR_MAXQUEUECNT; j++)
          queue_notif_cnt_r[i][j] <= queue_notif_cnt[i][j];

  /*
   * VirtIO console queues
   */
  logic vcd_rx_pending;
  logic vcd_tx_pending;

  assign vcd_rx_pending     = vcd_queue_rdy[VIRTIO_CONSOLE_RX_QUEUE_NUM] &&
    queue_notif_cnt_r[VMGR_DEV_VCD][VIRTIO_CONSOLE_RX_QUEUE_NUM] && uart_rx_fifo_cnt_r;
  assign vcd_tx_pending     = vcd_queue_rdy[VIRTIO_CONSOLE_TX_QUEUE_NUM] &&
    queue_notif_cnt_r[VMGR_DEV_VCD][VIRTIO_CONSOLE_TX_QUEUE_NUM];

  assign vcd_pending        = vcd_drvok && (vcd_rx_pending || vcd_tx_pending);

  assign vcd_pend_queue_num = vcd_tx_pending ? VIRTIO_CONSOLE_TX_QUEUE_NUM :
    VIRTIO_CONSOLE_RX_QUEUE_NUM;

  /*
   * VirtIO GPU queues
   */ 
  logic vgd_ctrl_pending;
  logic vgd_curs_pending;

  assign vgd_ctrl_pending   = vgd_queue_rdy[VIRTIO_GPU_CTRL_QUEUE_NUM] &&
    queue_notif_cnt_r[VMGR_DEV_VGD][VIRTIO_GPU_CTRL_QUEUE_NUM];
  assign vgd_curs_pending   = vgd_queue_rdy[VIRTIO_GPU_CURS_QUEUE_NUM] &&
    queue_notif_cnt_r[VMGR_DEV_VGD][VIRTIO_GPU_CURS_QUEUE_NUM];

  assign vgd_pending        = vgd_drvok && (vgd_ctrl_pending || vgd_curs_pending);

  assign vgd_pend_queue_num = vgd_ctrl_pending ? VIRTIO_GPU_CTRL_QUEUE_NUM :
    VIRTIO_GPU_CURS_QUEUE_NUM;

  /*
   * Pending queue number and device selection
   */
  always_comb begin
    dev            = dev_r;
    pend_queue_num = pend_queue_num_r;

    if (state_r == ST_IDLE) begin
      if (vcd_pending) begin
        dev            = VMGR_DEV_VCD;
        pend_queue_num = vcd_pend_queue_num;
      end else begin
        dev            = VMGR_DEV_VGD;
        pend_queue_num = vgd_pend_queue_num;
      end
    end
  end

  always_ff @(posedge clk) begin
    dev_r            <= dev;
    pend_queue_num_r <= pend_queue_num;
  end

  /*
   * Exit code handling
   */
  always_comb begin
    exit_code = exit_code_r;

    if (state_r == ST_BUSY && finished)
      exit_code = vmgr_exit_code_t'(vsw_wdata);
  end

  always_ff @(posedge clk)
    exit_code_r <= exit_code;

  /*
   * Delay counter
   */
  always_comb begin
    delay_cnt = delay_cnt_r;

    unique0 case (state_r)
      ST_IDLE:
        if (delay_cnt_r)
          delay_cnt = delay_cnt_r - 1;

      ST_FINISH:
        delay_cnt = VMGR_DELAY_CYCLES - 1;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      delay_cnt_r <= VMGR_DELAY_CYCLES - 1;
    else
      delay_cnt_r <= delay_cnt;

  /*
   * State transitions
   */
  logic pending;

  assign pending = vcd_pending || vgd_pending;

  always_comb begin
    state = state_r;

    unique0 case (state_r)
      ST_IDLE:
        if (ac_stallable && !delay_cnt_r && pending)
          state = ST_BUSY;

      ST_BUSY:
        if (finished)
          state = ST_FINISH;

      ST_FINISH:
        state = ST_IDLE;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      state_r <= ST_IDLE;
    else begin
      state_r <= state;
/*
      if (state_r == ST_IDLE && state == ST_BUSY) begin
        if (dev == VMGR_DEV_VCD) begin
          $display("[VMGR] waking up to handle the console");
          if (pend_queue_num == 0)
            $display("[VMGR] waking up for receiving");
          else
            $display("[VMGR] waking up for transmitting");
        end else if (dev == VMGR_DEV_VGD) begin
          $display("[VMGR] waking up to handle the display");
          if (pend_queue_num == 0)
            $display("[VMGR] waking up for control");
          else
            $display("[VMGR] waking up for coursor");
        end
      end else if (state_r == ST_BUSY && state == ST_FINISH)
        $display("[VMGR] finished, result=%d", vsw_wdata);
*/
    end

  /*
   * Other signals
   */
  assign busy = state_r == ST_BUSY;
endmodule
