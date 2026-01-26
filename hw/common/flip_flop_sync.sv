module flip_flop_sync #(
  parameter WIDTH = 32,
  parameter CNT   = 2
)(
  input  logic               clk,
  input  logic               nrst,

  input  logic [WIDTH - 1:0] src,
  output logic [WIDTH - 1:0] res
);
`default_nettype none

  (* ASYNC_REG = "TRUE" *)
  logic [WIDTH - 1:0] data [CNT - 1:0], data_r [CNT - 1:0];

  always_comb begin
    data[0] = src;

    for (int i = 1; i < CNT; i++)
      data[i] = data_r[i - 1];
  end

  always @(posedge clk, negedge nrst)
    if (!nrst)
      for (int i = 0; i < CNT; i++)
        data_r[i] <= 0;
    else
      for (int i = 0; i < CNT; i++)
        data_r[i] <= data[i];

  assign res = data_r[CNT - 1];
endmodule
