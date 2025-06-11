`default_nettype none

`include "evdev.svh"

module kbd
  import evdev_pkg::*;
(
  input  logic                    clk,
  input  logic                    kbd_clk,
  input  logic                    nrst,

  input  logic                    kbd_data,

  output logic [EV_CODELEN - 1:0] vmgr_code,
  output logic                    vmgr_value,
  output logic                    vmgr_ready
);
  typedef enum logic [2:0] {
    ST_READ,
    ST_PROCESS,
    ST_TRANSLATE,
    ST_FINISH,
    ST_WAIT
  } state_t;

  state_t      state, state_r;
  logic [15:0] full_scancode, full_scancode_r;
  logic [7:0]  scancode, scancode_r;
  logic [7:0]  evcode, evcode_r;
  logic [3:0]  cnt, cnt_r;
  logic        pressed, pressed_r;
  logic        rdy, rdy_r;

  logic        db_kbd_clk;
  logic        db_kbd_data;

  debouncer #(
    .CNT (40)  
  ) KBD_CLK_DEBOUNCER(
    .clk  (clk),
    .nrst (nrst),
    .src  (kbd_clk),
    .dst  (db_kbd_clk)
  );

  debouncer #(
    .CNT (40)
  ) KBD_DATA_DEBOUNCER(
    .clk  (clk),
    .nrst (nrst),
    .src  (kbd_data),
    .dst  (db_kbd_data)
  );

  /*
   * Scancode reading
   */
  always_comb begin
    scancode = scancode_r;

    case (cnt_r)
      1: scancode[0] = db_kbd_data;
      2: scancode[1] = db_kbd_data;
      3: scancode[2] = db_kbd_data;
      4: scancode[3] = db_kbd_data;
      5: scancode[4] = db_kbd_data;
      6: scancode[5] = db_kbd_data;
      7: scancode[6] = db_kbd_data;
      8: scancode[7] = db_kbd_data;
    endcase
  end

  always_ff @(negedge db_kbd_clk)
    scancode_r <= scancode;

  /*
   * Counter handling
   */
  assign cnt = cnt_r == 10 ? 0 : cnt_r + 1;

  always_ff @(negedge db_kbd_clk, negedge nrst)
    if (!nrst)
      cnt_r <= 0;
    else
      cnt_r <= cnt;

  /*
   * Full scancode construction
   */
  always_comb begin
    full_scancode = full_scancode_r;

    case (state_r)
      ST_PROCESS:
        if (scancode_r == 'he0)
          full_scancode[15:8] = 'he0;
        else
          full_scancode[7:0] = scancode_r;

      ST_FINISH:
        full_scancode = 0;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      full_scancode_r <= 0;
    else
      full_scancode_r <= full_scancode;

  /*
   * Key value handling
   */
  always_comb begin
    pressed = pressed_r;

    case (state_r)
      ST_PROCESS:
        if (scancode_r == 'hf0)
          pressed = 0;

      ST_FINISH:
        pressed = 1;
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      pressed_r <= 1;
    else
      pressed_r <= pressed;

  /*
   * Scancode readiness control
   */
  assign rdy = state_r == ST_READ && cnt_r == 9;

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      rdy_r <= 0;
    else
      rdy_r <= rdy;

  /*
   * Scancode to evdev translation
   */
  logic [7:0] kbdec_evcode;

  kbd_evdev_converter KBD_EVDEV_CONVERTER(
    .scancode (full_scancode_r),
    .evcode   (kbdec_evcode)
  );

  always_comb begin
    evcode = evcode_r;

    if (state_r == ST_TRANSLATE)
      evcode = kbdec_evcode;
  end

  always_ff @(posedge clk)
    evcode_r <= evcode;

  /*
   * State transitions
   */
  always_comb begin
    state = state_r;

    case (state_r)
      ST_READ:
        if (rdy_r)
          state = ST_PROCESS;

      ST_PROCESS:
        state = scancode_r == 'he0 || scancode_r == 'hf0 ? ST_WAIT : ST_TRANSLATE;

      ST_WAIT:
        if (cnt_r == 10)
          state = ST_READ;

      default:
        state = state_t'(state_r + 1);
    endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      state_r <= ST_READ;
    else
      state_r <= state;

  /*
   * VirtIO manager signals
   */
  assign vmgr_code  = evcode_r;
  assign vmgr_value = pressed_r ? KEY_EVENT_DOWN : KEY_EVENT_UP;
  assign vmgr_ready = state_r == ST_FINISH;
endmodule
