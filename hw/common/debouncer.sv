`default_nettype none

module debouncer #(
  parameter CNT = 4
)(
  input  logic clk,
  input  logic nrst,

  input  logic src,
  output logic dst
);
  localparam CNTLEN = $clog2(CNT);

  logic [CNTLEN - 1:0] cnt, cnt_r;
  logic                cur, cur_r;
  logic                out, out_r;

  always_comb begin
    cnt = cnt_r;
    cur = cur_r;
    out = out_r;

    if (src == cur_r) begin
      if (cnt_r == CNT - 1)
        out = cur_r;
      else
        cnt = cnt_r + 1;
    end else begin
      cnt = 0;
      cur = src;
    end
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst) begin
      cnt_r <= 0;
      cur_r <= 0;
      out_r <= 0;
    end else begin
      cnt_r <= cnt;
      cur_r <= cur;
      out_r <= out;
    end

  assign dst = out_r;
endmodule
