`default_nettype none

`include "isa.svh"
`include "virtio.svh"
`include "evdev.svh"
`include "soc.svh"

module virtio_manager
  import isa_pkg::*;
  import virtio_pkg::*;
  import evdev_pkg::*;
  import soc_pkg::*;
  import board_pkg::*;
(
  input  logic                          clk,
  input  logic                          nrst,

  input  logic [BLEN - 1:0]             dbgc_byte,
  input  logic                          dbgc_wen,
  output logic                          dbgc_stall,

  input  logic [BLEN - 1:0]             uart_rx_byte,
  input  logic                          uart_rx_ready,
  input  logic                          uart_tx_busy,
  output logic [BLEN - 1:0]             uart_tx_byte,
  output logic                          uart_tx_start,

  input  logic [VGA_FRAMESZ_LOG - 1:0]  vga_pos,
  output logic [VGA_COLORLEN - 1:0]     vga_r,
  output logic [VGA_COLORLEN - 1:0]     vga_g,
  output logic [VGA_COLORLEN - 1:0]     vga_b,

  input  logic [EV_CODELEN - 1:0]       kbd_code,
  input  logic                          kbd_value,
  input  logic                          kbd_ready,

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

  input  logic [VKD_QUEUECNT - 1:0]     vkd_queue_rdy,
  input  logic [VKD_QUEUECNT_LOG - 1:0] vkd_queue_num,
  input  logic                          vkd_notify,
  input  logic                          vkd_drvok,
  output logic                          vkd_used
);
  localparam VMGR_UART_RX_FIFO_ADDRLEN = $clog2(VMGR_UART_RX_FIFOSZ);
  localparam VMGR_UART_RX_FIFO_CNTLEN  = $clog2(VMGR_UART_RX_FIFOSZ + 1);

  localparam VMGR_KBD_FIFO_ADDRLEN     = $clog2(VMGR_KBD_FIFOSZ);
  localparam VMGR_KBD_FIFO_CNTLEN      = $clog2(VMGR_KBD_FIFOSZ + 1);

  typedef enum logic [1:0] {
    ST_IDLE,
    ST_BUSY,
    ST_FINISH
  } state_t;

  state_t                                 state, state_r;
  vmgr_dev_t                              dev, dev_r;
  logic [VMGR_MAXQUEUECNT_LOG - 1:0]      pend_queue_num, pend_queue_num_r;
  vmgr_exit_code_t                        exit_code, exit_code_r;
  logic [VMGR_DELAY_CNTLEN - 1:0]         delay_cnt, delay_cnt_r;
  logic                                   finished;

  logic [BLEN - 1:0]                      uart_rx_fifo [VMGR_UART_RX_FIFOSZ - 1:0],
    uart_rx_fifo_r [VMGR_UART_RX_FIFOSZ - 1:0];
  logic [VMGR_UART_RX_FIFO_ADDRLEN - 1:0] uart_rx_fifo_head, uart_rx_fifo_head_r;
  logic [VMGR_UART_RX_FIFO_ADDRLEN - 1:0] uart_rx_fifo_tail, uart_rx_fifo_tail_r;
  logic [VMGR_UART_RX_FIFO_CNTLEN - 1:0]  uart_rx_fifo_cnt, uart_rx_fifo_cnt_r;

  logic [VGA_COLORLEN - 1:0]              vga_frame_r [VGA_FRAMESZ - 1:0];
  logic [VGA_COLORLEN - 1:0]              vga_frame_g [VGA_FRAMESZ - 1:0];
  logic [VGA_COLORLEN - 1:0]              vga_frame_b [VGA_FRAMESZ - 1:0];
  logic [VGA_FRAMESZ_LOG - 1:0]           vga_idx, vga_idx_r;
  logic                                   vga_rdy, vga_rdy_r;
  logic [VGA_COLORLEN - 1:0]              vga_out_r;
  logic [VGA_COLORLEN - 1:0]              vga_out_g;
  logic [VGA_COLORLEN - 1:0]              vga_out_b;
  logic                                   vga_update;
  logic                                   vga_last_pixel;

  logic [EV_CODELEN - 1:0]                kbd_fifo_code [VMGR_KBD_FIFOSZ - 1:0],
    kbd_fifo_code_r [VMGR_KBD_FIFOSZ - 1:0];
  logic                                   kbd_fifo_value [VMGR_KBD_FIFOSZ - 1:0],
    kbd_fifo_value_r [VMGR_KBD_FIFOSZ - 1:0];
  logic [VMGR_KBD_FIFO_ADDRLEN - 1:0]     kbd_fifo_head, kbd_fifo_head_r;
  logic [VMGR_KBD_FIFO_ADDRLEN - 1:0]     kbd_fifo_tail, kbd_fifo_tail_r;
  logic [VMGR_KBD_FIFO_CNTLEN - 1:0]      kbd_fifo_cnt, kbd_fifo_cnt_r;

  logic [VMGR_QUEUE_NOTIF_CNTLEN - 1:0]
    queue_notif_cnt[VMGR_DEVCNT - 1:0][VMGR_MAXQUEUECNT - 1:0],
    queue_notif_cnt_r[VMGR_DEVCNT - 1:0][VMGR_MAXQUEUECNT - 1:0];

  logic [VCD_QUEUECNT_LOG - 1:0]          vcd_pend_queue_num;
  logic                                   vcd_pending;

  logic [VGD_QUEUECNT_LOG - 1:0]          vgd_pend_queue_num;
  logic                                   vgd_pending;

  logic [VKD_QUEUECNT_LOG - 1:0]          vkd_pend_queue_num;
  logic                                   vkd_pending;

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

  assign vga_update = vsw_wen && vsw_addr == VMGR_REG_VGA_UPDATE;

  assign vga_wr     = vsw_wdata[23-:VGA_COLORLEN];
  assign vga_wg     = vsw_wdata[15-:VGA_COLORLEN];
  assign vga_wb     = vsw_wdata[7-:VGA_COLORLEN];

  always_ff @(posedge clk)
    if (vga_update) begin
      vga_frame_r[vga_idx_r] <= vga_wr;
      vga_frame_g[vga_idx_r] <= vga_wg;
      vga_frame_b[vga_idx_r] <= vga_wb;
    end

  /*
   * VGA frame position calculation
   */
  assign vga_last_pixel = vga_idx_r == VGA_FRAMESZ - 1;

  always_comb begin
    vga_idx = vga_idx_r;

    if (vga_update) begin
      if (vga_last_pixel)
        vga_idx = 0;
      else
        vga_idx = vga_idx_r + 1;
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      vga_idx_r <= 0;
    else
      vga_idx_r <= vga_idx;

  /*
   * VGA frame readiness
   */
  logic vga_frame_done;

  assign vga_frame_done = vga_update && vga_last_pixel;

  always_comb begin
    vga_rdy = vga_rdy_r;

    if (vga_frame_done)
      vga_rdy = 1;
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      vga_rdy_r <= 0;
    else
      vga_rdy_r <= vga_rdy;

  /*
   * VGA output colors
   */
  always_ff @(posedge clk) begin
    vga_out_r <= vga_frame_r[vga_pos];
    vga_out_g <= vga_frame_g[vga_pos];
    vga_out_b <= vga_frame_b[vga_pos];
  end

  /*
   * VGA signals
   */
  assign vga_r = vga_rdy_r ? vga_out_r : 0;
  assign vga_g = vga_rdy_r ? vga_out_g : 0;
  assign vga_b = vga_rdy_r ? vga_out_b : {VGA_COLORLEN{1'b1}};

  /*
   * Keyboard receiving
   */
  always_comb begin
    for (int i = 0; i < VMGR_KBD_FIFOSZ; i++) begin
      kbd_fifo_code[i]  = kbd_fifo_code_r[i];
      kbd_fifo_value[i] = kbd_fifo_value_r[i];
    end

    kbd_fifo_head = kbd_fifo_head_r;
    kbd_fifo_tail = kbd_fifo_tail_r;
    kbd_fifo_cnt  = kbd_fifo_cnt_r;

    if (kbd_fifo_cnt_r && vsw_ren && vsw_addr == VMGR_REG_KBD) begin
      kbd_fifo_head = kbd_fifo_head_r + 1;
      if (!kbd_ready)
        kbd_fifo_cnt = kbd_fifo_cnt_r - 1;
      else begin
        kbd_fifo_code[kbd_fifo_tail_r]  = kbd_code;
        kbd_fifo_value[kbd_fifo_tail_r] = kbd_value;
        kbd_fifo_tail                   = kbd_fifo_tail_r + 1;
      end
    end else if (kbd_ready && kbd_fifo_cnt_r != VMGR_KBD_FIFOSZ) begin
      kbd_fifo_code[kbd_fifo_tail_r]  = kbd_code;
      kbd_fifo_value[kbd_fifo_tail_r] = kbd_value;
      kbd_fifo_tail                   = kbd_fifo_tail_r + 1;
      kbd_fifo_cnt                    = kbd_fifo_cnt_r + 1;
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      kbd_fifo_head_r <= 0;
      kbd_fifo_tail_r <= 0;
      kbd_fifo_cnt_r  <= 0;
    end else begin
      for (int i = 0; i < VMGR_KBD_FIFOSZ; i++) begin
        kbd_fifo_code_r[i]  <= kbd_fifo_code[i];
        kbd_fifo_value_r[i] <= kbd_fifo_value[i];
      end

      kbd_fifo_head_r <= kbd_fifo_head;
      kbd_fifo_tail_r <= kbd_fifo_tail;
      kbd_fifo_cnt_r  <= kbd_fifo_cnt;
    end

  /*
   * Debug console signals
   */
  assign dbgc_stall = uart_tx_busy;

  /*
   * VirtIO switch signals
   */
  logic [XLEN - 1:0] kbd_rdata;

  assign kbd_rdata = {kbd_fifo_code_r[kbd_fifo_head_r], kbd_fifo_value_r[kbd_fifo_head_r]};

  always_comb begin
    vsw_rdata = 'bx;

    unique0 case (vsw_addr)
      VMGR_REG_UART_RX:
        vsw_rdata = uart_rx_fifo_cnt_r ? uart_rx_fifo_r[uart_rx_fifo_head_r] : {XLEN{1'b1}};

      VMGR_REG_KBD:
        vsw_rdata = kbd_fifo_cnt_r ? kbd_rdata : {XLEN{1'b1}};

      VMGR_REG_REQ:
        vsw_rdata = {dev_r, pend_queue_num_r};
    endcase
  end

  assign vsw_stall = (vsw_addr == VMGR_REG_UART_TX && (uart_tx_busy || dbgc_wen)) ||
    (vsw_addr == VMGR_REG_REQ && state_r != ST_BUSY);

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
   * VirtIO keyboard signals
   */
  assign vkd_used = state_r == ST_FINISH && dev_r == VMGR_DEV_VKD &&
    exit_code_r == VMGR_EXIT_SUCCESS;

  /*
   * Queue notifications
   */
  logic vcd_notif_cnt_max;
  logic vgd_notif_cnt_max;
  logic vkd_notif_cnt_max;

  assign finished          = vsw_wen && vsw_addr == VMGR_REG_FINISH;

  assign vcd_notif_cnt_max =
    queue_notif_cnt_r[VMGR_DEV_VCD][vcd_queue_num] == {VMGR_QUEUE_NOTIF_CNTLEN{1'b1}};
  assign vgd_notif_cnt_max =
    queue_notif_cnt_r[VMGR_DEV_VGD][vgd_queue_num] == {VMGR_QUEUE_NOTIF_CNTLEN{1'b1}};
  assign vkd_notif_cnt_max =
    queue_notif_cnt_r[VMGR_DEV_VKD][vgd_queue_num] == {VMGR_QUEUE_NOTIF_CNTLEN{1'b1}};

  always_comb begin
    for (int i = 0; i < VMGR_DEVCNT; i++)
      for (int j = 0; j < VMGR_MAXQUEUECNT; j++)
        queue_notif_cnt[i][j] = queue_notif_cnt_r[i][j];

    if (state_r != ST_BUSY || !finished) begin
      unique0 if (vkd_notify && !vkd_notif_cnt_max)
        queue_notif_cnt[VMGR_DEV_VKD][vkd_queue_num] =
          queue_notif_cnt_r[VMGR_DEV_VKD][vkd_queue_num] + 1;
      else if (vgd_notify && !vgd_notif_cnt_max)
        queue_notif_cnt[VMGR_DEV_VGD][vgd_queue_num] =
          queue_notif_cnt_r[VMGR_DEV_VGD][vgd_queue_num] + 1;
      else if (vcd_notify && !vcd_notif_cnt_max)
        queue_notif_cnt[VMGR_DEV_VCD][vcd_queue_num] =
          queue_notif_cnt_r[VMGR_DEV_VCD][vcd_queue_num] + 1;
    end else begin
      queue_notif_cnt[dev_r][pend_queue_num_r] =
        queue_notif_cnt_r[dev_r][pend_queue_num_r] - 1;

      unique0 if (vkd_notify && dev_r != VMGR_DEV_VKD && !vkd_notif_cnt_max)
        queue_notif_cnt[VMGR_DEV_VKD][vkd_queue_num] =
          queue_notif_cnt_r[VMGR_DEV_VKD][vkd_queue_num] + 1;
      else if (vgd_notify && dev_r != VMGR_DEV_VGD && !vgd_notif_cnt_max)
        queue_notif_cnt[VMGR_DEV_VGD][vgd_queue_num] =
          queue_notif_cnt_r[VMGR_DEV_VGD][vgd_queue_num] + 1;
      else if (vcd_notify && dev_r != VMGR_DEV_VCD && !vcd_notif_cnt_max)
        queue_notif_cnt[VMGR_DEV_VCD][vcd_queue_num] =
          queue_notif_cnt_r[VMGR_DEV_VCD][vcd_queue_num] + 1;
    end
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
   * VirtIO keyboard queues
   */
  logic vkd_event_pending;
  logic vkd_status_pending;

  assign vkd_event_pending  = vkd_queue_rdy[VIRTIO_INPUT_EVENT_QUEUE_NUM] &&
    kbd_fifo_cnt_r;
  assign vkd_status_pending = vkd_queue_rdy[VIRTIO_INPUT_STATUS_QUEUE_NUM] &&
    queue_notif_cnt_r[VMGR_DEV_VKD][VIRTIO_INPUT_STATUS_QUEUE_NUM];

  assign vkd_pending        = vkd_drvok && (vkd_event_pending || vkd_status_pending);

  assign vkd_pend_queue_num = vkd_event_pending ? VIRTIO_INPUT_EVENT_QUEUE_NUM :
    VIRTIO_INPUT_STATUS_QUEUE_NUM;

  /*
   * Pending queue number and device selection
   */
  always_comb begin
    dev            = dev_r;
    pend_queue_num = pend_queue_num_r;

    if (state_r == ST_IDLE) begin
      if (vkd_pending) begin
        dev            = VMGR_DEV_VKD;
        pend_queue_num = vkd_pend_queue_num;
      end else if (vcd_pending) begin
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

  assign pending = vcd_pending || vgd_pending || vkd_pending;

  always_comb begin
    state = state_r;

    unique0 case (state_r)
      ST_IDLE:
        if (!delay_cnt_r && pending)
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
    else
      state_r <= state;
endmodule
