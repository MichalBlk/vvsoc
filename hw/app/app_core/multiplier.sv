`default_nettype none

`include "isa.svh"

module multiplier
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
    ST_FINISH
  } state_t;

  state_t                    state, state_r;

  logic        [XLEN - 1:0]  src1, src1_r;
  logic        [XLEN - 1:0]  src2, src2_r;
  logic signed [XLEN - 1:0]  src1_s, src1_s_r;
  logic signed [XLEN - 1:0]  src2_s, src2_s_r;
  logic signed [XLEN:0]      src1_su, src1_su_r;
  logic signed [XLEN:0]      src2_su, src2_su_r;
  logic        [DXLEN - 1:0] res_uu, res_uu_r;
  logic        [DXLEN - 1:0] res_ss, res_ss_r;
  logic        [DXLEN - 1:0] res_su, res_su_r;

  /*
   * Arguments
   */
  always_comb begin
    src1    = src1_r;
    src2    = src2_r;
    src1_s  = src1_s_r;
    src2_s  = src2_s_r;
    src1_su = src1_su_r;
    src2_su = src2_su_r;

    if (state_r == ST_IDLE) begin
      src1    = ac_src1;
      src2    = ac_src2;
      src1_s  = signed'(ac_src1);
      src2_s  = signed'(ac_src2);
      src1_su = signed'({ac_src1[XLEN - 1], ac_src1});
      src2_su = signed'({1'b0, ac_src2});
    end
  end

  always_ff @(posedge clk) begin
    src1_r    <= src1;
    src2_r    <= src2;
    src1_s_r  <= src1_s;
    src2_s_r  <= src2_s;
    src1_su_r <= src1_su;
    src2_su_r <= src2_su;
  end

  /*
   * Multiplication
   */
  always_comb begin
    res_uu = res_uu_r;
    res_ss = res_ss_r;
    res_su = res_su_r;

    if (state_r == ST_BUSY) begin
      res_uu = src1_r * src2_r;
      res_ss = src1_s_r * src2_s_r;
      res_su = src1_su_r * src2_su_r;
    end
  end

  always_ff @(posedge clk) begin
    res_uu_r <= res_uu;
    res_ss_r <= res_ss;
    res_su_r <= res_su;
  end

  /*
   * Reading
   */
  always_comb begin
    ac_res = 'bx;

    unique0 case (ac_funct3)
      FUNCT3_MUL:    ac_res = res_ss_r[0+:XLEN];
      FUNCT3_MULH:   ac_res = res_ss_r[XLEN+:XLEN];
      FUNCT3_MULHSU: ac_res = res_su_r[XLEN+:XLEN];
      FUNCT3_MULHU:  ac_res = res_uu_r[XLEN+:XLEN];
    endcase
  end

  /*
   * State transitions
   */
  always_comb begin
    state = state_r;

    unique case (state_r)
      ST_IDLE:
        if (ac_start)
          state = ST_BUSY;

      ST_BUSY:
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

  /*
   * Other output signals
   */
  assign ac_stall = state_r != ST_FINISH;
endmodule
