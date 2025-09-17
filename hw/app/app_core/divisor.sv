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
  logic [XLEN - 1:0]     src1_u, src1_u_r;
  logic [XLEN - 1:0]     src2_u, src2_u_r;
  logic                  sign_src1, sign_src1_r;
  logic                  sign_src2, sign_src2_r;
  logic                  diff_signs, diff_signs_r;
  logic                  sign, sign_r;
  logic                  zero, zero_r;
  logic                  ovf, ovf_r;

  always_comb begin
    sign_src1  = sign_src1_r;
    sign_src2  = sign_src2_r;
    diff_signs = diff_signs_r;
    sign       = sign_r;
    zero       = zero_r;
    ovf        = ovf_r;

    if (state_r == ST_IDLE) begin
      sign_src1  = ac_src1[XLEN - 1];
      sign_src2  = ac_src2[XLEN - 1];
      diff_signs = sign_src1 ^ sign_src2;
      sign       = ac_funct3 == FUNCT3_DIV || ac_funct3 == FUNCT3_REM;
      zero       = !ac_src2;
      ovf        = ac_src1 == MAXPW && ac_src2 == ALL;
    end
  end

  always_ff @(posedge clk) begin
    sign_src1_r  <= sign_src1;
    sign_src2_r  <= sign_src2;
    diff_signs_r <= diff_signs;
    sign_r       <= sign;
    zero_r       <= zero;
    ovf_r        <= ovf;
  end

  /*
   * Unsigned arguments
   */
  always_comb begin
    src1_u = src1_u_r;
    src2_u = src2_u_r;

    if (state_r == ST_IDLE) begin
      src1_u = ac_src1;
      src2_u = ac_src2;

      if (sign) begin
        if (sign_src1)
          src1_u = ~ac_src1 + 1;
        if (sign_src2)
          src2_u = ~ac_src2 + 1;
      end
    end
  end

  always_ff @(posedge clk) begin
    src1_u_r <= src1_u;
    src2_u_r <= src2_u;
  end

  /*
   * State transitions
   */
  logic special;

  assign special = zero || (ovf && sign);

  always_comb begin
    state = state_r;

    unique0 if (state_r == ST_IDLE && ac_start)
      state = special ? ST_FINISH : ST_BUSY;
    else if (state_r == ST_BUSY && !cnt_r)
      state = ST_FINISH;
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
  assign gte = val >= src2_u_r;

  always_comb begin
    q   = q_r;
    acc = acc_r;

    unique0 if (state_r == ST_IDLE && ac_start) begin
      q   = src1_u;
      acc = 0;
    end else if (state_r == ST_BUSY) begin
      q   = {q_r[0+:XLEN - 1], gte};
      acc = gte ? val - src2_u_r : val;
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
        unique if (zero_r)
          ac_res = ALL;
        else if (ovf_r)
          ac_res = MAXPW;
        else
          ac_res = diff_signs_r ? ~q_r + 1 : q_r;

      FUNCT3_DIVU:
        if (zero_r)
          ac_res = ALL;
        else
          ac_res = q_r;

      FUNCT3_REM:
        unique if (zero_r)
          ac_res = ac_src1;
        else if (ovf_r)
          ac_res = 0;
        else
          ac_res = sign_src1_r ? ~acc_r + 1 : acc_r;

      FUNCT3_REMU:
        if (zero_r)
          ac_res = ac_src1;
        else
          ac_res = acc_r;
    endcase
  end

  assign ac_stall = state_r != ST_FINISH;
endmodule
