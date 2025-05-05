`default_nettype none

module flag_sync(
  input  logic src_clk,
  input  logic src_nrst,
  input  logic src_flag,

  input  logic dst_clk,
  input  logic dst_nrst,
  output logic dst_flag
);
  logic src_diff, src_diff_r;

  assign src_diff = src_diff_r ^ src_flag;

  always_ff @(posedge src_clk, negedge src_nrst)
    if (!src_nrst)
      src_diff_r <= 0;
    else
      src_diff_r <= src_diff;

  (* ASYNC_REG = "TRUE" *)
  logic [2:0] dst_diff, dst_diff_r;

  assign dst_diff = {dst_diff_r[1:0], src_diff_r};

  always_ff @(posedge dst_clk, negedge dst_nrst)
    if (!dst_nrst)
      dst_diff_r <= 0;
    else
      dst_diff_r <= dst_diff;

  assign dst_flag = dst_diff_r[2] ^ dst_diff_r[1];
endmodule
