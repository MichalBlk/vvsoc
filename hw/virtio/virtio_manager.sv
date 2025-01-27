`default_nettype none

`include "isa_pkg.svh"
`include "virtio_pkg.svh"
`include "soc_pkg.svh"

module virtio_manager
  import isa_pkg::*;
  import virtio_pkg::*;
  import soc_pkg::*;
(
  input  logic                          clk,
  input  logic                          nrst,

  input  logic                          ac_stallable,

  input  logic [BLEN - 1:0]             uart_rx_byte,
  input  logic                          uart_rx_ready,
  input  logic                          uart_tx_busy,
  output logic [BLEN - 1:0]             uart_tx_byte,
  output logic                          uart_tx_start,

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

  output logic                          busy
);
  localparam VMGR_UART_RX_FIFO_ADDRLEN = $clog2(VMGR_UART_RX_FIFOSZ);
  localparam VMGR_UART_RX_FIFO_CNTLEN  = $clog2(VMGR_UART_RX_FIFOSZ + 1);

  typedef enum logic {
    ST_IDLE,
    ST_BUSY
  } state_t;

  state_t                                 state, state_r;
  logic [VMGR_DELAY_CNTLEN - 1:0]         delay_cnt, delay_cnt_r;

  logic [BLEN - 1:0]                      uart_rx_fifo [VMGR_UART_RX_FIFOSZ - 1:0],
    uart_rx_fifo_r [VMGR_UART_RX_FIFOSZ - 1:0];
  logic [VMGR_UART_RX_FIFO_ADDRLEN - 1:0] uart_rx_fifo_head, uart_rx_fifo_head_r;
  logic [VMGR_UART_RX_FIFO_ADDRLEN - 1:0] uart_rx_fifo_tail, uart_rx_fifo_tail_r;
  logic [VMGR_UART_RX_FIFO_CNTLEN - 1:0]  uart_rx_fifo_cnt, uart_rx_fifo_cnt_r;

  logic [VMGR_QUEUE_NOTIF_CNTLEN - 1:0]   queue_notif_cnt[VCD_QUEUECNT - 1:0],
    queue_notif_cnt_r[VCD_QUEUECNT - 1:0];
  logic [VCD_QUEUECNT_LOG - 1:0]          queue_num, queue_num_r;

  logic                                   rx_pending;
  logic                                   tx_pending;
  logic                                   finished;

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
      if (!uart_rx_ready) begin
        uart_rx_fifo_cnt = uart_rx_fifo_cnt_r - 1;
      end else begin
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
  assign uart_tx_byte  = vsw_wdata;
  assign uart_tx_start = vsw_wen && vsw_addr == VMGR_REG_UART_TX;

  /*
   * VirtIO core signals
   */
  assign vc_nsrst   = !(state != ST_BUSY);
  assign vc_srstarg = queue_num;

  /*
   * VirtIO switch signals
   */
  assign finished  = vsw_wen && vsw_addr == VMGR_REG_FINISH;

  assign vsw_rdata = uart_rx_fifo_cnt_r ? uart_rx_fifo_r[uart_rx_fifo_head_r] : {XLEN{1'b1}};
  assign vsw_stall = vsw_wen && vsw_addr == VMGR_REG_UART_TX && uart_tx_busy;

  /*
   * VirtIO console device signals
   */
  assign vcd_used = finished && vsw_wdata == VMGR_FINISH_SUCCESS;

  /*
   * Queue notifications
   */
  logic notif_cnt_max;

  assign notif_cnt_max = queue_notif_cnt_r[vcd_queue_num] == {VMGR_QUEUE_NOTIF_CNTLEN{1'b1}};

  always_comb begin
    for (int i = 0; i < VCD_QUEUECNT; i++)
      queue_notif_cnt[i] = queue_notif_cnt_r[i];

    if (vcd_notify && !notif_cnt_max)
      queue_notif_cnt[vcd_queue_num] = queue_notif_cnt_r[vcd_queue_num] + 1;
    else if (finished)
      queue_notif_cnt[queue_num_r] = queue_notif_cnt_r[queue_num_r] - 1;
  end

  always_ff @(posedge clk, negedge nrst) begin
    if (!nrst)
      for (int i = 0; i < VCD_QUEUECNT; i++)
        queue_notif_cnt_r[i] <= 0;
    else
      for (int i = 0; i < VCD_QUEUECNT; i++)
        queue_notif_cnt_r[i] <= queue_notif_cnt[i];
  end

  /*
   * Pending queues
   */
  assign rx_pending = vcd_queue_rdy[VIRTIO_CONSOLE_RX_QUEUE_NUM] &&
    queue_notif_cnt_r[VIRTIO_CONSOLE_RX_QUEUE_NUM] && uart_rx_fifo_cnt_r;
  assign tx_pending = vcd_queue_rdy[VIRTIO_CONSOLE_TX_QUEUE_NUM] &&
    queue_notif_cnt_r[VIRTIO_CONSOLE_TX_QUEUE_NUM];

  /*
   * Queue number
   */ 
  always_comb begin
    queue_num = queue_num_r;

    if (state_r == ST_IDLE) begin
      if (tx_pending)
        queue_num = VIRTIO_CONSOLE_TX_QUEUE_NUM;
      else
        queue_num = VIRTIO_CONSOLE_RX_QUEUE_NUM;
    end
  end

  always_ff @(posedge clk)
    queue_num_r <= queue_num;

  /*
   * Delay counter
   */
  always_comb begin
    delay_cnt = delay_cnt_r;

    case (state_r)
      ST_IDLE:
        if (delay_cnt_r)
          delay_cnt = delay_cnt_r - 1;

      ST_BUSY:
        if (finished)
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

  assign pending = rx_pending || tx_pending;

  always_comb begin
    state = state_r;

    case (state_r)
      ST_IDLE:
        if (ac_stallable && vcd_drvok && !delay_cnt_r && pending)
          state = ST_BUSY;
      ST_BUSY:
        if (finished)
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
        if (queue_num == 0)
          $display("[VMGR] waking up for receiving");
        else
          $display("[VMGR] waking up for transmitting");
      end else if (state_r == ST_BUSY && state == ST_IDLE) begin
        if (queue_num_r == 0)
          $display("[VMGR] receiving finished, result=%d", vsw_wdata);
        else
          $display("[VMGR] transmitting finished, result=%d", vsw_wdata);
      end
*/
    end

  /*
   * Other signals
   */
  assign busy = state == ST_BUSY;
endmodule
