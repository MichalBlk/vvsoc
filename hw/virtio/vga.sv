`default_nettype none

`include "soc.svh"

module vga
  import soc_pkg::*;
  import board_pkg::*;
(
  input  logic                         vga_clk,
  input  logic                         nrst,

  output logic [VGA_POSLEN - 1:0]      x,
  output logic [VGA_POSLEN - 1:0]      y,
  output logic [VGA_COLORLEN - 1:0]    r,
  output logic [VGA_COLORLEN - 1:0]    g,
  output logic [VGA_COLORLEN - 1:0]    b,
  output logic                         hsync,
  output logic                         vsync,

  input  logic [VGA_COLORLEN - 1:0]    vmgr_r,
  input  logic [VGA_COLORLEN - 1:0]    vmgr_g,
  input  logic [VGA_COLORLEN - 1:0]    vmgr_b,
  output logic [VGA_FRAMESZ_LOG - 1:0] vmgr_pos
);
  logic [VGA_POSLEN - 1:0]      cx, cx_r;
  logic [VGA_POSLEN - 1:0]      cy, cy_r;
  logic [VGA_POSLEN - 1:0]      bx, bx_r;
  logic [VGA_POSLEN - 1:0]      by, by_r;
  logic [VGA_COLORLEN - 1:0]    br, br_r;
  logic [VGA_COLORLEN - 1:0]    bg, bg_r;
  logic [VGA_COLORLEN - 1:0]    bb, bb_r;
  logic [VGA_FRAMESZ_LOG - 1:0] cpos, cpos_r;
  logic [VGA_FRAMESZ_LOG - 1:0] spos, spos_r;
  logic                         chsync;
  logic                         cvsync;
  logic                         cblank;
  logic                         bhsync, bhsync_r;
  logic                         bvsync, bvsync_r;

  /*
   * Coordinate calculation
   */
  always_comb begin
    cx = cx_r;
    cy = cy_r;

    if (cx_r == VGA_H_MAX) begin
      cx = 0;
      if (cy_r == VGA_V_MAX)
        cy = 0;
      else
        cy = cy_r + 1;
    end else
      cx = cx_r + 1;
  end

  always_ff @(posedge vga_clk, negedge nrst) begin
    if (!nrst) begin
      cx_r <= 0;
      cy_r <= 0;
    end else begin
      cx_r <= cx;
      cy_r <= cy;
    end
  end

  /*
   * Sync and blank signals
   */
  assign chsync = !(cx_r >= VGA_H_SYNCSTART && cx_r < VGA_H_SYNCEND);
  assign cvsync = !(cy_r >= VGA_V_SYNCSTART && cy_r < VGA_V_SYNCEND);
  assign cblank = cx_r >= VGA_H_ACTIVECNT || cy_r >= VGA_V_ACTIVECNT;

  /*
   * Frame position calculation
   */
  always_comb begin
    cpos = cpos_r;
    spos = spos_r;

    if (cx_r < VGA_WIDTH && cy_r < VGA_HEIGHT) begin
      if (cx_r[0]) begin
        if (cx_r == VGA_WIDTH - 1) begin
          if (cy_r[0])
            cpos = cy_r == VGA_HEIGHT - 1 ? 0 : cpos_r + 1;
          else
            cpos = spos_r;
        end else
          cpos = cpos_r + 1;
      end else if (!cx_r)
        spos = cpos_r;
    end
  end

  always_ff @(posedge vga_clk, negedge nrst)
    if (!nrst)
      cpos_r <= 0;
    else begin
      cpos_r <= cpos;
      spos_r <= spos;
    end

  /*
   * Output buffering
   */
  assign bx     = cx_r;
  assign by     = cy_r;
  assign br     = cblank ? 0 : vmgr_r;
  assign bg     = cblank ? 0 : vmgr_g;
  assign bb     = cblank ? 0 : vmgr_b;
  assign bhsync = chsync;
  assign bvsync = cvsync;

  always_ff @(posedge vga_clk, negedge nrst) begin
    if (!nrst) begin
      bx_r     <= 0;
      by_r     <= 0;
      br_r     <= 0;
      bg_r     <= 0;
      bb_r     <= 0;
      bhsync_r <= 1;
      bvsync_r <= 1;
    end else begin
      bx_r     <= bx;
      by_r     <= by;
      br_r     <= br;
      bg_r     <= bg;
      bb_r     <= bb;
      bhsync_r <= bhsync;
      bvsync_r <= bvsync;
    end
  end

  /*
   * VirtIO manager signals
   */
  assign vmgr_pos = cpos_r;

  /*
   * Other signals
   */
  assign x     = bx_r;
  assign y     = by_r;
  assign r     = br_r;
  assign g     = bg_r;
  assign b     = bb_r;
  assign hsync = bhsync_r;
  assign vsync = bvsync_r;
endmodule
