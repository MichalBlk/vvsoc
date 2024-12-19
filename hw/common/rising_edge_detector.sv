`default_nettype none

module rising_edge_detector(
  input logic  clk,
  input logic  nrst,

  input logic  src,
  output logic redge
);
  logic src_r;

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      src_r <= 0;
    else
      src_r <= src;

  assign redge = !src_r && src;
endmodule
