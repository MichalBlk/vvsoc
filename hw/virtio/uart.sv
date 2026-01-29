/*
 * Heavily based on the UART controller by Timothy Goddard:
 * https://github.com/freecores/osdvu/blob/master/uart.v
 */
`include "isa.svh"
`include "param.svh"

module uart
  import isa_pkg::BLEN;
  import isa_pkg::BLEN_LOG;
  import param_pkg::*;
  import board_pkg::*;
(
  input  logic              clk,
  input  logic              nrst,

  input  logic              rx,
  output logic              tx,

  input  logic [BLEN - 1:0] vmgr_tx_byte,
  input  logic              vmgr_tx_start,
  output logic [BLEN - 1:0] vmgr_rx_byte,
  output logic              vmgr_rx_ready,
  output logic              vmgr_tx_busy
);
`default_nettype none

  localparam BIT_PERIOD  = 16;
  localparam CLK_DIV     = CLK_FREQ / (UART_BAUD_RATE * BIT_PERIOD);
  localparam CLK_DIV_LOG = $clog2(CLK_DIV);
  localparam CNTLEN      = $clog2(BIT_PERIOD * 2);

  typedef enum logic [2:0] {
    ST_RX_IDLE,
    ST_RX_CHECK_START,
    ST_RX_READ_BITS,
    ST_RX_CHECK_STOP,
    ST_RX_RECEIVED,
    ST_RX_ERROR,
    ST_RX_DELAY_RESTART
  } rx_state_t;

  typedef enum logic [1:0] {
    ST_TX_IDLE,
    ST_TX_SENDING,
    ST_TX_DELAY_RESTART
  } tx_state_t;

  /*
   * Receiving
   */
  rx_state_t                rx_state, rx_state_r;
  logic [CLK_DIV_LOG - 1:0] rx_clk_div_cnt, rx_clk_div_cnt_r;
  logic [CNTLEN - 1:0]      rx_cnt, rx_cnt_r;
  logic [BLEN_LOG - 1:0]    rx_bit_cnt, rx_bit_cnt_r;
  logic [BLEN - 1:0]        rx_byte, rx_byte_r;
  logic                     rx_cnt_done;

  assign rx_cnt_done = !rx_cnt_r && !rx_clk_div_cnt_r;

  always_comb begin
    rx_state       = rx_state_r;
    rx_clk_div_cnt = rx_clk_div_cnt_r - 1;
    rx_cnt         = rx_cnt_r;
    rx_bit_cnt     = rx_bit_cnt_r;
    rx_byte        = rx_byte_r;

    if (!rx_clk_div_cnt_r) begin
      rx_clk_div_cnt = CLK_DIV - 1;
      rx_cnt         = rx_cnt_r - 1;
    end

    case (rx_state_r)
      ST_RX_IDLE:
        if (!rx) begin
          rx_state       = ST_RX_CHECK_START;
          rx_clk_div_cnt = CLK_DIV - 1;
          rx_cnt         = BIT_PERIOD / 2 - 1;
        end

      ST_RX_CHECK_START:
        if (rx_cnt_done) begin
          if (rx)
            rx_state = ST_RX_ERROR;
          else begin
            rx_state   = ST_RX_READ_BITS;
            rx_cnt     = BIT_PERIOD - 1;
            rx_bit_cnt = BLEN - 1;
          end
        end

      ST_RX_READ_BITS:
        if (rx_cnt_done) begin
          if (!rx_bit_cnt_r)
            rx_state = ST_RX_CHECK_STOP;

          rx_cnt     = BIT_PERIOD - 1;
          rx_bit_cnt = rx_bit_cnt_r - 1;
          rx_byte    = {rx, rx_byte_r[BLEN - 1:1]};
        end

      ST_RX_CHECK_STOP:
        if (rx_cnt_done)
          rx_state = rx ? ST_RX_RECEIVED : ST_RX_ERROR;

      ST_RX_RECEIVED:
        rx_state = ST_RX_IDLE;

      ST_RX_ERROR: begin
        rx_state = ST_RX_DELAY_RESTART;
        rx_cnt   = BIT_PERIOD * 2 - 1;
      end

      ST_RX_DELAY_RESTART:
        if (rx_cnt_done)
          rx_state = ST_RX_IDLE;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      rx_state_r <= ST_RX_IDLE;
    else begin
      rx_state_r       <= rx_state;
      rx_clk_div_cnt_r <= rx_clk_div_cnt;
      rx_cnt_r         <= rx_cnt;
      rx_bit_cnt_r     <= rx_bit_cnt;
      rx_byte_r        <= rx_byte;
    end

  /*
   * Transmitting
   */
  tx_state_t                tx_state, tx_state_r;
  logic [CLK_DIV_LOG - 1:0] tx_clk_div_cnt, tx_clk_div_cnt_r;
  logic [CNTLEN - 1:0]      tx_cnt, tx_cnt_r;
  logic [BLEN_LOG:0]        tx_bit_cnt, tx_bit_cnt_r;
  logic [BLEN - 1:0]        tx_byte, tx_byte_r;
  logic                     tx_bit, tx_bit_r;
  logic                     tx_cnt_done;

  assign tx_cnt_done = !tx_cnt_r && !tx_clk_div_cnt_r;

  always_comb begin
    tx_state       = tx_state_r;
    tx_clk_div_cnt = tx_clk_div_cnt_r - 1;
    tx_cnt         = tx_cnt_r;
    tx_bit_cnt     = tx_bit_cnt_r;
    tx_byte        = tx_byte_r;
    tx_bit         = tx_bit_r;

    if (!tx_clk_div_cnt_r) begin
      tx_clk_div_cnt = CLK_DIV - 1;
      tx_cnt         = tx_cnt_r - 1;
    end

    case (tx_state_r)
      ST_TX_IDLE:
        if (vmgr_tx_start) begin
          tx_state       = ST_TX_SENDING;
          tx_clk_div_cnt = CLK_DIV - 1;
          tx_cnt         = BIT_PERIOD - 1;
          tx_bit_cnt     = BLEN;
          tx_byte        = vmgr_tx_byte;
          tx_bit         = 0;
        end

      ST_TX_SENDING:
        if (tx_cnt_done) begin
          if (tx_bit_cnt_r) begin
            tx_cnt     = BIT_PERIOD - 1;
            tx_bit_cnt = tx_bit_cnt_r - 1;
            tx_byte    = tx_byte_r >> 1;
            tx_bit     = tx_byte_r[0];
          end else begin
            tx_state = ST_TX_DELAY_RESTART;
            tx_cnt   = BIT_PERIOD * 2 - 1;
            tx_bit   = 1;
          end
        end

      ST_TX_DELAY_RESTART:
        if (tx_cnt_done)
          tx_state = ST_TX_IDLE;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      tx_state_r <= ST_TX_IDLE;
      tx_bit_r   <= 1;
    end else begin
      tx_state_r       <= tx_state;
      tx_clk_div_cnt_r <= tx_clk_div_cnt;
      tx_cnt_r         <= tx_cnt;
      tx_bit_cnt_r     <= tx_bit_cnt;
      tx_byte_r        <= tx_byte;
      tx_bit_r         <= tx_bit;
    end

  /*
   * Device pins
   */
  assign tx = tx_bit_r;

  /*
   * VirtIO manager signals
   */
  assign vmgr_rx_byte  = rx_byte_r;
  assign vmgr_rx_ready = rx_state_r == ST_RX_RECEIVED;
  assign vmgr_tx_busy  = tx_state_r != ST_TX_IDLE;
endmodule
