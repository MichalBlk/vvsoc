`default_nettype none

`include "isa.svh"
`include "soc.svh"
`include "board.svh"

module cache
  import isa_pkg::*;
  import soc_pkg::*;
  import board_pkg::*;
(
  input  logic                      clk,
  input  logic                      nrst,

  output logic [XLEN - 1:0]         ac_pte,

  input  logic [MMEM_ADDRLEN - 1:0] msw_addr,
  input  logic [XLEN - 1:0]         msw_wdata,
  input  logic [XLENB_LOG - 1:0]    msw_size,
  input  logic                      msw_nsign,
  input  logic                      msw_ren,
  input  logic                      msw_wen,
  output logic [XLEN - 1:0]         msw_rdata,
  output logic                      msw_stall,

  input  logic [MMEM_DATALEN - 1:0] mmem_rdata,
  input  logic                      mmem_stall,
  output logic [MMEM_ADDRLEN - 1:0] mmem_addr,
  output logic [MMEM_DATALEN - 1:0] mmem_wdata,
  output logic                      mmem_ren,
  output logic                      mmem_wen
);
  typedef enum logic [2:0] {
    ST_IDLE,
    ST_READ,
    ST_VICTIM_READ,
    ST_MMEM_WRITE,
    ST_MMEM_READ,
    ST_PROCESS,
    ST_FINISH
  } state_t;

  state_t                         state, state_r;

  logic [CACHE_LINELEN - 1:0]     line_data0 [CACHE_SETCNT - 1:0];
  logic [CACHE_LINELEN - 1:0]     line_data1 [CACHE_SETCNT - 1:0];
  logic [CACHE_LINELEN - 1:0]     line_data2 [CACHE_SETCNT - 1:0];
  logic [CACHE_LINELEN - 1:0]     line_data3 [CACHE_SETCNT - 1:0];

  logic [CACHE_TAGLEN - 1:0]      line_tag0 [CACHE_SETCNT - 1:0],
    line_tag0_r [CACHE_SETCNT - 1:0];
  logic [CACHE_TAGLEN - 1:0]      line_tag1 [CACHE_SETCNT - 1:0],
    line_tag1_r [CACHE_SETCNT - 1:0];
  logic [CACHE_TAGLEN - 1:0]      line_tag2 [CACHE_SETCNT - 1:0],
    line_tag2_r [CACHE_SETCNT - 1:0];
  logic [CACHE_TAGLEN - 1:0]      line_tag3 [CACHE_SETCNT - 1:0],
    line_tag3_r [CACHE_SETCNT - 1:0];

  logic                           line_dirty0 [CACHE_SETCNT - 1:0],
    line_dirty0_r [CACHE_SETCNT - 1:0];
  logic                           line_dirty1 [CACHE_SETCNT - 1:0],
    line_dirty1_r [CACHE_SETCNT - 1:0];
  logic                           line_dirty2 [CACHE_SETCNT - 1:0],
    line_dirty2_r [CACHE_SETCNT - 1:0];
  logic                           line_dirty3 [CACHE_SETCNT - 1:0],
    line_dirty3_r [CACHE_SETCNT - 1:0];

  logic                           line_valid0 [CACHE_SETCNT - 1:0],
    line_valid0_r [CACHE_SETCNT - 1:0];
  logic                           line_valid1 [CACHE_SETCNT - 1:0],
    line_valid1_r [CACHE_SETCNT - 1:0];
  logic                           line_valid2 [CACHE_SETCNT - 1:0],
    line_valid2_r [CACHE_SETCNT - 1:0];
  logic                           line_valid3 [CACHE_SETCNT - 1:0],
    line_valid3_r [CACHE_SETCNT - 1:0];

  logic [CACHE_LINECNT_LOG - 1:0] line_nxt [CACHE_SETCNT - 1:0],
    line_nxt_r [CACHE_SETCNT - 1:0];

  logic [MMEM_ADDRLEN - 1:0]      addr, addr_r;
  logic [CACHE_LINELEN - 1:0]     wdata, wdata_r;
  logic [XLENB_LOG - 1:0]         size, size_r;
  logic                           sign, sign_r;
  logic                           wen, wen_r;
  logic [CACHE_TAGLEN - 1:0]      tag;
  logic [CACHE_TAGLEN - 1:0]      victim_tag;
  logic [CACHE_SETCNT_LOG - 1:0]  set_idx;
  logic [CACHE_OFFSETLEN - 1:0]   offset;
  logic [CACHE_LINELEN_LOG - 1:0] offsetbit, offsetbit_r;
  logic [XLEN_LOG:0]              sizebit, sizebit_r;
  logic [CACHE_LINELEN - 1:0]     mask, mask_r;
  logic [CACHE_LINELEN - 1:0]     data0_r;
  logic [CACHE_LINELEN - 1:0]     data1_r;
  logic [CACHE_LINELEN - 1:0]     data2_r;
  logic [CACHE_LINELEN - 1:0]     data3_r;
  logic [CACHE_LINELEN - 1:0]     src_data, src_data_r;
  logic [CACHE_LINELEN - 1:0]     mdf_data0, mdf_data0_r;
  logic [CACHE_LINELEN - 1:0]     mdf_data1, mdf_data1_r;
  logic [CACHE_LINELEN - 1:0]     mdf_data2, mdf_data2_r;
  logic [CACHE_LINELEN - 1:0]     mdf_data3, mdf_data3_r;
  logic [CACHE_LINELEN - 1:0]     mdf_src_data, mdf_src_data_r;
  logic [XLEN - 1:0]              sh_data0, sh_data0_r;
  logic [XLEN - 1:0]              sh_data1, sh_data1_r;
  logic [XLEN - 1:0]              sh_data2, sh_data2_r;
  logic [XLEN - 1:0]              sh_data3, sh_data3_r;
  logic [XLEN - 1:0]              sh_src_data, sh_src_data_r;
  logic [CACHE_LINELEN - 1:0]     victim_data, victim_data_r;
  logic [CACHE_LINECNT_LOG - 1:0] line_idx, line_idx_r;
  logic [CACHE_LINECNT_LOG - 1:0] victim_line_idx, victim_line_idx_r;
  logic [MMEM_ADDRLEN - 1:0]      src_addr, src_addr_r;
  logic [MMEM_ADDRLEN - 1:0]      victim_addr, victim_addr_r;
  logic [CACHE_MMEM_CNTLEN - 1:0] cnt, cnt_r;
  logic                           hit, hit_r;
  logic                           free_line, free_line_r;
  logic                           victim_dirty;
  logic                           wen0, wen0_r;
  logic                           wen1, wen1_r;
  logic                           wen2, wen2_r;
  logic                           wen3, wen3_r;
  logic                           mem_finished;

  /*
   * Idle stage
   */
  always_comb begin
    addr  = addr_r;
    wdata = wdata_r;
    size  = size_r;
    sign  = sign_r;
    wen   = wen_r;

    if (state_r == ST_IDLE) begin
      addr  = msw_addr;
      wdata = CACHE_LINELEN'(msw_wdata);
      size  = msw_size;
      sign  = !msw_nsign;
      wen   = msw_wen;
    end
  end

  always_ff @(posedge clk) begin
    addr_r  <= addr;
    wdata_r <= wdata;
    size_r  <= size;
    sign_r  <= sign;
    wen_r   <= wen;
  end

  /*
   * Read stage
   */
  logic [CACHE_LINECNT_LOG - 1:0] free_line_idx;

  assign {tag, set_idx, offset} = addr_r;

  always_comb begin
    offsetbit = offsetbit_r;
    sizebit   = sizebit_r;
    mask      = mask_r;

    if (state_r == ST_READ) begin
      offsetbit = offset << BLEN_LOG;
      sizebit   = 1 << (size_r + BLEN_LOG);
      mask      = (1 << sizebit) - 1;
    end
  end

  always_ff @(posedge clk) begin
    offsetbit_r <= offsetbit;
    sizebit_r   <= sizebit;
    mask_r      <= mask;
  end

  always_ff @(posedge clk) begin
    data0_r <= line_data0[set_idx];
    data1_r <= line_data1[set_idx];
    data2_r <= line_data2[set_idx];
    data3_r <= line_data3[set_idx];
  end

  always_comb begin
    line_idx = line_idx_r;
    hit      = hit_r;

    if (state_r == ST_READ) begin
      hit = 0;

      unique0 if (line_tag0[set_idx] == tag && line_valid0[set_idx]) begin
        line_idx = 0;
        hit      = 1;
      end else if (line_tag1[set_idx] == tag && line_valid1[set_idx]) begin
        line_idx = 1;
        hit      = 1;
      end else if (line_tag2[set_idx] == tag && line_valid2[set_idx]) begin
        line_idx = 2;
        hit      = 1;
      end else if (line_tag3[set_idx] == tag && line_valid3[set_idx]) begin
        line_idx = 3;
        hit      = 1;
      end
    end
  end

  always_ff @(posedge clk) begin
    line_idx_r <= line_idx;
    hit_r      <= hit;
  end

  always_comb begin
    free_line_idx = 'bx;
    free_line     = free_line_r;

    if (state_r == ST_READ) begin
      free_line = 0;

      if (!line_valid0[set_idx]) begin
        free_line_idx = 0;
        free_line     = 1;
      end else if (!line_valid1[set_idx]) begin
        free_line_idx = 1;
        free_line     = 1;
      end else if (!line_valid2[set_idx]) begin
        free_line_idx = 2;
        free_line     = 1;
      end else if (!line_valid3[set_idx]) begin
        free_line_idx = 3;
        free_line     = 1;
      end
    end
  end

  always_ff @(posedge clk)
    free_line_r <= free_line;

  always_comb begin
    victim_line_idx = victim_line_idx_r;

    if (state_r == ST_READ)
      victim_line_idx = free_line ? free_line_idx : line_nxt_r[set_idx];
  end

  always_ff @(posedge clk)
    victim_line_idx_r <= victim_line_idx;

  /*
   * Victim read stage
   */
  always_comb
    case (victim_line_idx_r)
      0: begin
        victim_tag   = line_tag0_r[set_idx];
        victim_dirty = line_dirty0_r[set_idx];
      end

      1: begin
        victim_tag   = line_tag1_r[set_idx];
        victim_dirty = line_dirty1_r[set_idx];
      end

      2: begin
        victim_tag   = line_tag2_r[set_idx];
        victim_dirty = line_dirty2_r[set_idx];
      end

      3: begin
        victim_tag   = line_tag3_r[set_idx];
        victim_dirty = line_dirty3_r[set_idx];
      end
    endcase

  /*
   * Main memory read stage
   */
  always_comb begin
    src_data = src_data_r;

    if (state_r == ST_MMEM_READ && !mmem_stall)
      src_data = {mmem_rdata, src_data_r[CACHE_LINELEN - 1:MMEM_DATALEN]};
  end

  always_ff @(posedge clk)
    src_data_r <= src_data;

  /*
   * Process stage
   */
  always_comb begin
    mdf_data0    = mdf_data0_r;
    mdf_data1    = mdf_data1_r;
    mdf_data2    = mdf_data2_r;
    mdf_data3    = mdf_data3_r;
    mdf_src_data = mdf_src_data_r;

    if (state_r == ST_PROCESS) begin
      mdf_data0    = (data0_r & ~(mask_r << offsetbit_r)) | ((wdata_r & mask_r) << offsetbit_r);
      mdf_data1    = (data1_r & ~(mask_r << offsetbit_r)) | ((wdata_r & mask_r) << offsetbit_r);
      mdf_data2    = (data2_r & ~(mask_r << offsetbit_r)) | ((wdata_r & mask_r) << offsetbit_r);
      mdf_data3    = (data3_r & ~(mask_r << offsetbit_r)) | ((wdata_r & mask_r) << offsetbit_r);
      mdf_src_data = (src_data_r & ~(mask_r << offsetbit_r)) | ((wdata_r & mask_r) << offsetbit_r);
    end
  end

  always_ff @(posedge clk) begin
    mdf_data0_r    <= mdf_data0;
    mdf_data1_r    <= mdf_data1;
    mdf_data2_r    <= mdf_data2;
    mdf_data3_r    <= mdf_data3;
    mdf_src_data_r <= mdf_src_data;
  end

  always_comb begin
    sh_data0    = sh_data0_r;
    sh_data1    = sh_data1_r;
    sh_data2    = sh_data2_r;
    sh_data3    = sh_data3_r;
    sh_src_data = sh_src_data_r;

    if (state_r == ST_PROCESS) begin
      sh_data0    = (data0_r >> offsetbit_r) & mask_r;
      sh_data1    = (data1_r >> offsetbit_r) & mask_r;
      sh_data2    = (data2_r >> offsetbit_r) & mask_r;
      sh_data3    = (data3_r >> offsetbit_r) & mask_r;
      sh_src_data = (src_data_r >> offsetbit_r) & mask_r;
    end
  end

  always_ff @(posedge clk) begin
    sh_data0_r    <= sh_data0;
    sh_data1_r    <= sh_data1;
    sh_data2_r    <= sh_data2;
    sh_data3_r    <= sh_data3;
    sh_src_data_r <= sh_src_data;
  end

  always_comb begin
    wen0 = wen0_r;
    wen1 = wen1_r;
    wen2 = wen2_r;
    wen3 = wen3_r;

    if (state_r == ST_PROCESS) begin
      wen0 = (!hit_r && victim_line_idx_r == 0) || (hit_r && wen_r && line_idx_r == 0);
      wen1 = (!hit_r && victim_line_idx_r == 1) || (hit_r && wen_r && line_idx_r == 1);
      wen2 = (!hit_r && victim_line_idx_r == 2) || (hit_r && wen_r && line_idx_r == 2);
      wen3 = (!hit_r && victim_line_idx_r == 3) || (hit_r && wen_r && line_idx_r == 3);
    end
  end

  always_ff @(posedge clk) begin
    wen0_r <= wen0;
    wen1_r <= wen1;
    wen2_r <= wen2;
    wen3_r <= wen3;
  end

  /*
   * Finish stage
   */
  logic [CACHE_LINELEN - 1:0] cwdata0;
  logic [CACHE_LINELEN - 1:0] cwdata1;
  logic [CACHE_LINELEN - 1:0] cwdata2;
  logic [CACHE_LINELEN - 1:0] cwdata3;
  logic [XLEN - 1:0]          sh_data;

  always_comb
    if (hit_r) begin
      cwdata0 = mdf_data0_r;
      cwdata1 = mdf_data1_r;
      cwdata2 = mdf_data2_r;
      cwdata3 = mdf_data3_r;
    end else if (wen_r) begin
      cwdata0 = mdf_src_data_r;
      cwdata1 = mdf_src_data_r;
      cwdata2 = mdf_src_data_r;
      cwdata3 = mdf_src_data_r;
    end else begin
      cwdata0 = src_data_r;
      cwdata1 = src_data_r;
      cwdata2 = src_data_r;
      cwdata3 = src_data_r;
    end

  always_ff @(posedge clk) begin
    if (state_r == ST_FINISH && wen0_r)
      line_data0[set_idx] <= cwdata0;
    if (state_r == ST_FINISH && wen1_r)
      line_data1[set_idx] <= cwdata1;
    if (state_r == ST_FINISH && wen2_r)
      line_data2[set_idx] <= cwdata2;
    if (state_r == ST_FINISH && wen3_r)
      line_data3[set_idx] <= cwdata3;
  end

  always_comb begin
    for (int i = 0; i < CACHE_SETCNT; i++)
      line_nxt[i] = line_nxt_r[i];

    if (state_r == ST_FINISH && !hit_r && !free_line_r)
      line_nxt[set_idx] = line_nxt_r[set_idx] + 1;
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      for (int i = 0; i < CACHE_SETCNT; i++)
        line_nxt_r[i] <= 0;
    else
      for (int i = 0; i < CACHE_SETCNT; i++)
        line_nxt_r[i] <= line_nxt[i];

  always_comb
    if (hit_r)
      case (line_idx_r)
        0: sh_data = sh_data0_r;
        1: sh_data = sh_data1_r;
        2: sh_data = sh_data2_r;
        3: sh_data = sh_data3_r;
      endcase
    else
      sh_data = sh_src_data_r;

  assign ac_pte = sh_data;

  always_comb
    if (sign_r && (sh_data >> (sizebit_r - 1)))
      msw_rdata = sh_data | ~mask_r;
    else
      msw_rdata = sh_data;

  /*
   * Source address handling
   */
  always_comb begin
    src_addr = src_addr_r;

    if (state_r == ST_READ)
      src_addr = {tag, set_idx, {CACHE_OFFSETLEN{1'b0}}};
    else if (state_r == ST_MMEM_READ && !mmem_stall)
      src_addr = src_addr_r + MMEM_DATALENB;
  end

  always_ff @(posedge clk)
    src_addr_r <= src_addr;

  /*
   * Victim address/data handling
   */
  always_comb begin
    victim_addr = victim_addr_r;
    victim_data = victim_data_r;

    if (state_r == ST_VICTIM_READ) begin
      victim_addr = {victim_tag, set_idx, {CACHE_OFFSETLEN{1'b0}}};

      case (victim_line_idx_r)
        0: victim_data = data0_r;
        1: victim_data = data1_r;
        2: victim_data = data2_r;
        3: victim_data = data3_r;
      endcase
    end else if (state_r == ST_MMEM_WRITE && !mmem_stall) begin
      victim_addr = victim_addr_r + MMEM_DATALENB;
      victim_data = victim_data_r >> MMEM_DATALEN;
    end
  end

  always_ff @(posedge clk) begin
    victim_addr_r <= victim_addr;
    victim_data_r <= victim_data;
  end

  /*
   * Counter handling
   */
  always_comb begin
    cnt = cnt_r;

    if (state_r == ST_READ)
      cnt = CACHE_MMEM_CYCLES - 1;
    else if ((state_r == ST_MMEM_WRITE || state_r == ST_MMEM_READ) && !mmem_stall)
      cnt = cnt_r ? cnt_r - 1 : CACHE_MMEM_CYCLES - 1;
  end

  always_ff @(posedge clk)
    cnt_r <= cnt;

  /*
   * Line tag, dirty, and valid handling
   */
  logic [CACHE_LINECNT_LOG - 1:0] idx;

  assign idx = hit_r ? line_idx_r : victim_line_idx_r;

  always_comb begin
    for (int i = 0; i < CACHE_SETCNT; i++) begin
      line_tag0[i]   = line_tag0_r[i];
      line_tag1[i]   = line_tag1_r[i];
      line_tag2[i]   = line_tag2_r[i];
      line_tag3[i]   = line_tag3_r[i];

      line_dirty0[i] = line_dirty0_r[i];
      line_dirty1[i] = line_dirty1_r[i];
      line_dirty2[i] = line_dirty2_r[i];
      line_dirty3[i] = line_dirty3_r[i];

      line_valid0[i] = line_valid0_r[i];
      line_valid1[i] = line_valid1_r[i];
      line_valid2[i] = line_valid2_r[i];
      line_valid3[i] = line_valid3_r[i];
    end

    if (state_r == ST_PROCESS && !hit_r)
      case (victim_line_idx_r)
        0: begin
          line_tag0[set_idx]   = tag;
          line_dirty0[set_idx] = 0;
          line_valid0[set_idx] = 1;
        end

        1: begin
          line_tag1[set_idx]   = tag;
          line_dirty1[set_idx] = 0;
          line_valid1[set_idx] = 1;
        end

        2: begin
          line_tag2[set_idx]   = tag;
          line_dirty2[set_idx] = 0;
          line_valid2[set_idx] = 1;
        end

        3: begin
          line_tag3[set_idx]   = tag;
          line_dirty3[set_idx] = 0;
          line_valid3[set_idx] = 1;
        end
      endcase
    else if (state_r == ST_FINISH && wen_r)
      case (idx)
        0: line_dirty0[set_idx] = 1;
        1: line_dirty1[set_idx] = 1;
        2: line_dirty2[set_idx] = 1;
        3: line_dirty3[set_idx] = 1;
      endcase
  end

  always_ff @(posedge clk, negedge nrst)
    if (!nrst)
      for (int i = 0; i < CACHE_SETCNT; i++) begin
        line_valid0_r[i] <= 0;
        line_valid1_r[i] <= 0;
        line_valid2_r[i] <= 0;
        line_valid3_r[i] <= 0;
      end
    else
      for (int i = 0; i < CACHE_SETCNT; i++) begin
        line_tag0_r[i]   <= line_tag0[i];
        line_tag1_r[i]   <= line_tag1[i];
        line_tag2_r[i]   <= line_tag2[i];
        line_tag3_r[i]   <= line_tag3[i];

        line_dirty0_r[i] <= line_dirty0[i];
        line_dirty1_r[i] <= line_dirty1[i];
        line_dirty2_r[i] <= line_dirty2[i];
        line_dirty3_r[i] <= line_dirty3[i];

        line_valid0_r[i] <= line_valid0[i];
        line_valid1_r[i] <= line_valid1[i];
        line_valid2_r[i] <= line_valid2[i];
        line_valid3_r[i] <= line_valid3[i];
      end

  /*
   * State transitions
   */
  assign mem_finished = !cnt_r && !mmem_stall;

  always_comb begin
    state = state_r;

    unique0 case (state_r)
      ST_IDLE:
        if (msw_ren || msw_wen)
          state = ST_READ;

      ST_READ:
        if (hit)
          state = ST_PROCESS;
        else if (free_line)
          state = ST_MMEM_READ;
        else
          state = ST_VICTIM_READ;

      ST_VICTIM_READ:
        state = victim_dirty ? ST_MMEM_WRITE : ST_MMEM_READ;

      ST_MMEM_WRITE:
        if (mem_finished)
          state = ST_MMEM_READ;

      ST_MMEM_READ:
        if (mem_finished)
          state = ST_PROCESS;

      ST_PROCESS:
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
   * Main memory signals
   */
  assign mmem_addr  = state_r == ST_MMEM_WRITE ? victim_addr_r : src_addr_r;
  assign mmem_wdata = victim_data_r[MMEM_DATALEN - 1:0];
  assign mmem_ren   = state_r == ST_MMEM_READ;
  assign mmem_wen   = state_r == ST_MMEM_WRITE;

  /*
   * Other main switch signals
   */
  assign msw_stall = state_r != ST_FINISH;
endmodule
