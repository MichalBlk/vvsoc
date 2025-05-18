`default_nettype none

`include "isa.svh"

module divisor
  import isa_pkg::*;
(
  input  logic                   clk,
  input  logic                   nrst,
  input  logic [XLEN - 1:0]      ac_src1,
  input  logic [XLEN - 1:0]      ac_src2,
  input  logic [FUNCT3LEN - 1:0] ac_funct3,
  input  logic                   ac_start,
  output logic [XLEN - 1:0]      ac_res,
  output logic                   ac_stall
);
  typedef enum logic [1:0] {
    ST_IDLE,
    ST_BUSY,
    ST_SPECIAL,
    ST_FINISH
  } state_t;

  state_t                state, state_r;
  logic [XLEN_LOG - 1:0] cnt, cnt_r;
  logic [XLEN - 1:0]     q, q_r;
  logic [XLEN - 1:0]     acc, acc_r;
  logic [XLEN - 1:0]     src1_u, src2_u;
  logic                  sign_src1;
  logic                  sign_src2;
  logic                  diff_signs;
  logic                  sign;
  logic                  zero;
  logic                  ovf;

  assign sign_src1  = ac_src1[XLEN - 1];
  assign sign_src2  = ac_src2[XLEN - 1];
  assign diff_signs = sign_src1 ^ sign_src2;
  assign sign       = ac_funct3 == FUNCT3_DIV || ac_funct3 == FUNCT3_REM;
  assign zero       = !ac_src2;
  assign ovf        = ac_src1 == MAXPW && ac_src2 == ALL;

  always_comb begin
    src1_u = ac_src1;
    src2_u = ac_src2;

    if (sign) begin
      if (ac_src1[XLEN - 1])
        src1_u = ~ac_src1 + 1;
      if (ac_src2[XLEN - 1])
        src2_u = ~ac_src2 + 1;
    end
  end

  /*
   * State transitions
   */
  logic special;

  assign special = zero || (ovf && (ac_funct3 == FUNCT3_DIV || ac_funct3 == FUNCT3_REM));

  always_comb begin
    state = state_r;

    unique0 if (state_r == ST_IDLE && ac_start)
      state = special ? ST_FINISH : ST_BUSY;
    else if (state_r == ST_BUSY && !cnt_r)
      state = ST_IDLE;
    else if (state_r == ST_FINISH)
      state = ST_IDLE;
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      state_r <= ST_IDLE;
    else
      state_r <= state;

  /*
   * Bit counter
   */
  always_comb begin
    cnt = cnt_r;

    if (state_r == ST_BUSY)
      cnt = cnt_r - 1;
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      cnt_r <= XLEN - 1;
    else
      cnt_r <= cnt;

  /*
   * Division operation
   */
  logic [XLEN - 1:0] val;
  logic              gte;

  assign val = {acc_r[0+:XLEN - 1], q_r[XLEN - 1]};
  assign gte = val >= src2_u;

  always_comb begin
    q   = q_r;
    acc = acc_r;

    unique0 if (state_r == ST_IDLE && ac_start) begin
      q   = src1_u;
      acc = 0;
    end else if (state_r == ST_BUSY) begin
      q   = {q_r[0+:XLEN - 1], gte};
      acc = gte ? val - src2_u : val;
    end
  end

  always_ff @(posedge clk) begin
    q_r   <= q;
    acc_r <= acc;
  end

  /*
   * Application core signals
   */
  always_comb begin
    ac_res = 'bx;

    unique0 case (ac_funct3)
      FUNCT3_DIV:
        if (zero)
          ac_res = ALL;
        else if (ovf)
          ac_res = MAXPW;
        else
          ac_res = diff_signs ? ~q_r + 1 : q_r;

      FUNCT3_DIVU:
        if (zero)
          ac_res = ALL;
        else
          ac_res = q_r;

      FUNCT3_REM:
        if (zero)
          ac_res = ac_src1;
        else if (ovf)
          ac_res = 0;
        else
          ac_res = sign_src1 ? ~acc_r + 1 : acc_r;

      FUNCT3_REMU:
        if (zero)
          ac_res = ac_src1;
        else
          ac_res = acc_r;
    endcase
  end

  assign ac_stall = (state_r == ST_IDLE && ac_start) || state_r == ST_BUSY;
endmodule
