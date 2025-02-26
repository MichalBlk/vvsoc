`default_nettype none

`include "isa_pkg.svh"
`include "soc_pkg.svh"

module top
  import isa_pkg::*;
  import soc_pkg::*;
(
  input  logic                      clk,
  input  logic                      vga_clk,
  input  logic                      nrst,

  input  logic                      rx,
  output logic                      tx,

  output logic [VGA_POSLEN - 1:0]   x,
  output logic [VGA_POSLEN - 1:0]   y,
  output logic [VGA_COLORLEN - 1:0] r,
  output logic [VGA_COLORLEN - 1:0] g,
  output logic [VGA_COLORLEN - 1:0] b,
  output logic                      hsync,
  output logic                      vsync
);
  logic [XLEN - 1:0]             clint_asw_rdata;
  logic [CNTLEN - 1:0]           clint_ac_mtime;
  logic                          clint_ac_intr_pending;

  logic [XLEN - 1:0]             ac_asw_addr;
  logic [XLEN - 1:0]             ac_asw_wdata;
  logic [XLENB_LOG - 1:0]        ac_asw_size;
  logic                          ac_asw_nsign;
  logic                          ac_asw_ren;
  logic                          ac_asw_wen;
  logic                          ac_vmgr_stallable;

  logic [XLEN - 1:0]             asw_ac_rdata;
  logic                          asw_ac_stall;
  logic [BLEN - 1:0]             asw_dbgc_wdata;
  logic                          asw_dbgc_wen;
  logic [CLINT_ADDRLEN - 1:0]    asw_clint_addr;
  logic [XLEN - 1:0]             asw_clint_wdata;
  logic                          asw_clint_wen;
  logic [XLEN - 1:0]             asw_msw_addr;
  logic [XLEN - 1:0]             asw_msw_wdata;
  logic [XLENB_LOG - 1:0]        asw_msw_size;
  logic                          asw_msw_nsign;
  logic                          asw_msw_ren;
  logic                          asw_msw_wen;

  logic [XLEN - 1:0]             msw_asw_rdata;
  logic                          msw_asw_stall;
  logic [XLEN - 1:0]             msw_vsw_rdata;
  logic                          msw_vsw_stall;
  logic [MMEM_ADDRLEN - 1:0]     msw_mmem_addr;
  logic [XLEN - 1:0]             msw_mmem_wdata;
  logic [XLENB_LOG - 1:0]        msw_mmem_size;
  logic                          msw_mmem_nsign;
  logic                          msw_mmem_ren;
  logic                          msw_mmem_wen;
  logic [VCD_ADDRLEN - 1:0]      msw_vcd_addr;
  logic [XLEN - 1:0]             msw_vcd_wdata;
  logic                          msw_vcd_ren;
  logic                          msw_vcd_wen;
  logic [VGD_ADDRLEN - 1:0]      msw_vgd_addr;
  logic [XLEN - 1:0]             msw_vgd_wdata;
  logic                          msw_vgd_ren;
  logic                          msw_vgd_wen;

  logic [XLEN - 1:0]             mmem_msw_rdata;
  logic                          mmem_msw_stall;

  logic                          vcd_ac_intr_pending;
  logic [XLEN - 1:0]             vcd_msw_rdata;
  logic [VCD_QUEUECNT - 1:0]     vcd_vmgr_queue_rdy;
  logic [VCD_QUEUECNT_LOG - 1:0] vcd_vmgr_queue_num;
  logic                          vcd_vmgr_notify;
  logic                          vcd_vmgr_drvok;

  logic                          vgd_ac_intr_pending;
  logic [XLEN - 1:0]             vgd_msw_rdata;
  logic [VGD_QUEUECNT - 1:0]     vgd_vmgr_queue_rdy;
  logic [VGD_QUEUECNT_LOG - 1:0] vgd_vmgr_queue_num;
  logic                          vgd_vmgr_notify;
  logic                          vgd_vmgr_drvok;

  logic [XLEN - 1:0]             vsw_vc_rdata;
  logic                          vsw_vc_stall;
  logic [VMEM_ADDRLEN - 1:0]     vsw_vmem_addr;
  logic [XLEN - 1:0]             vsw_vmem_wdata;
  logic [XLENB_LOG - 1:0]        vsw_vmem_size;
  logic                          vsw_vmem_nsign;
  logic                          vsw_vmem_ren;
  logic                          vsw_vmem_wen;
  logic [VMGR_ADDRLEN - 1:0]     vsw_vmgr_addr;
  logic [XLEN - 1:0]             vsw_vmgr_wdata;
  logic                          vsw_vmgr_ren;
  logic                          vsw_vmgr_wen;
  logic [XLEN - 1:0]             vsw_msw_addr;
  logic [XLEN - 1:0]             vsw_msw_wdata;
  logic [XLENB_LOG - 1:0]        vsw_msw_size;
  logic                          vsw_msw_nsign;
  logic                          vsw_msw_ren;
  logic                          vsw_msw_wen;

  logic [XLEN - 1:0]             vc_vsw_addr;
  logic [XLEN - 1:0]             vc_vsw_wdata;
  logic [XLENB_LOG - 1:0]        vc_vsw_size;
  logic                          vc_vsw_nsign;
  logic                          vc_vsw_ren;
  logic                          vc_vsw_wen;

  logic [BLEN - 1:0]             vmgr_uart_tx_byte;
  logic                          vmgr_uart_tx_start;
  logic [VGA_COLORLEN - 1:0]     vmgr_vga_r;
  logic [VGA_COLORLEN - 1:0]     vmgr_vga_g;
  logic [VGA_COLORLEN - 1:0]     vmgr_vga_b;
  logic                          vmgr_vc_nsrst;
  logic [XLEN - 1:0]             vmgr_vc_srstarg;
  logic [XLEN - 1:0]             vmgr_vsw_rdata;
  logic                          vmgr_vsw_stall;
  logic                          vmgr_vcd_used;
  logic                          vmgr_vgd_used;
  logic                          vmgr_busy;

  logic [XLEN - 1:0]             vmem_vsw_rdata;
  logic                          vmem_vsw_stall;

  logic [BLEN - 1:0]             uart_vmgr_rx_byte;
  logic                          uart_vmgr_rx_ready;
  logic                          uart_vmgr_tx_busy;

  logic [VGA_POSLEN - 1:0]       vga_vmgr_x;
  logic [VGA_POSLEN - 1:0]       vga_vmgr_y;

  initial begin
    integer file;
    $display("[TOP] Loading kernel...");
    file = $fopen("kernel.bin", "rb");
    $fread(MAIN_MEMORY.mem, file, MMEM_KERNEL_OFFW);
    $fclose(file);

    $display("[TOP] Loading firmware...");
    file = $fopen("fw.bin", "rb");
    $fread(MAIN_MEMORY.mem, file, MMEM_FW_OFFW);
    $fclose(file);

    $display("[TOP] Loading dtb...");
    file = $fopen("vrvsoc.dtb", "rb");
    $fread(MAIN_MEMORY.mem, file, MMEM_DTB_OFFW);
    $fclose(file);

    $display("[TOP] Loading initrd...");
    file = $fopen("initrd.cpio", "rb");
    $fread(MAIN_MEMORY.mem, file, MMEM_INITRD_OFFW);
    $fclose(file);

    $display("[TOP] Loading VirtIO core image...");
    file = $fopen("virtio.bin", "rb");
    $fread(VIRTIO_MEMORY.mem, file);
    $fclose(file);

    $display("[TOP] Images loaded successfully");
  end

  dbg_console DBG_CONSOLE (
    .clk       (clk),
    .asw_wdata (asw_dbgc_wdata),
    .asw_wen   (asw_dbgc_wen)
  );

  clint CLINT(
    .clk             (clk),
    .nrst            (nrst),
    .asw_addr        (asw_clint_addr),
    .asw_wdata       (asw_clint_wdata),
    .asw_wen         (asw_clint_wen),
    .asw_rdata       (clint_asw_rdata),
    .ac_mtime        (clint_ac_mtime),
    .ac_intr_pending (clint_ac_intr_pending)
  );

  app_core APP_CORE(
    .clk                (clk),
    .nrst               (nrst),
    .clint_mtime        (clint_ac_mtime),
    .clint_intr_pending (clint_ac_intr_pending),
    .asw_rdata          (asw_ac_rdata),
    .asw_stall          (asw_ac_stall),
    .asw_addr           (ac_asw_addr),
    .asw_wdata          (ac_asw_wdata),
    .asw_size           (ac_asw_size),
    .asw_nsign          (ac_asw_nsign),
    .asw_ren            (ac_asw_ren),
    .asw_wen            (ac_asw_wen),
    .vcd_intr_pending   (vcd_ac_intr_pending),
    .vgd_intr_pending   (vgd_ac_intr_pending),
    .vmgr_busy          (vmgr_busy),
    .vmgr_stallable     (ac_vmgr_stallable)
  );

  app_switch APP_SWITCH(
    .clk         (clk),
    .ac_addr     (ac_asw_addr),
    .ac_wdata    (ac_asw_wdata),
    .ac_size     (ac_asw_size),
    .ac_nsign    (ac_asw_nsign),
    .ac_ren      (ac_asw_ren),
    .ac_wen      (ac_asw_wen),
    .ac_rdata    (asw_ac_rdata),
    .ac_stall    (asw_ac_stall),
    .dbgc_wdata  (asw_dbgc_wdata),
    .dbgc_wen    (asw_dbgc_wen),
    .clint_rdata (clint_asw_rdata),
    .clint_addr  (asw_clint_addr),
    .clint_wdata (asw_clint_wdata),
    .clint_wen   (asw_clint_wen),
    .msw_rdata   (msw_asw_rdata),
    .msw_stall   (msw_asw_stall),
    .msw_addr    (asw_msw_addr),
    .msw_wdata   (asw_msw_wdata),
    .msw_size    (asw_msw_size),
    .msw_nsign   (asw_msw_nsign),
    .msw_ren     (asw_msw_ren),
    .msw_wen     (asw_msw_wen)
  );

  main_switch MAIN_SWITCH(
    .asw_addr   (asw_msw_addr),
    .asw_wdata  (asw_msw_wdata),
    .asw_size   (asw_msw_size),
    .asw_nsign  (asw_msw_nsign),
    .asw_ren    (asw_msw_ren),
    .asw_wen    (asw_msw_wen),
    .asw_rdata  (msw_asw_rdata),
    .asw_stall  (msw_asw_stall),
    .vsw_addr   (vsw_msw_addr),
    .vsw_wdata  (vsw_msw_wdata),
    .vsw_size   (vsw_msw_size),
    .vsw_nsign  (vsw_msw_nsign),
    .vsw_ren    (vsw_msw_ren),
    .vsw_wen    (vsw_msw_wen),
    .vsw_rdata  (msw_vsw_rdata),
    .vsw_stall  (msw_vsw_stall),
    .vmgr_busy  (vmgr_busy),
    .mmem_rdata (mmem_msw_rdata),
    .mmem_stall (mmem_msw_stall),
    .mmem_addr  (msw_mmem_addr),
    .mmem_wdata (msw_mmem_wdata),
    .mmem_size  (msw_mmem_size),
    .mmem_nsign (msw_mmem_nsign),
    .mmem_ren   (msw_mmem_ren),
    .mmem_wen   (msw_mmem_wen),
    .vcd_rdata  (vcd_msw_rdata),
    .vcd_addr   (msw_vcd_addr),
    .vcd_wdata  (msw_vcd_wdata),
    .vcd_ren    (msw_vcd_ren),
    .vcd_wen    (msw_vcd_wen),
    .vgd_rdata  (vgd_msw_rdata),
    .vgd_addr   (msw_vgd_addr),
    .vgd_wdata  (msw_vgd_wdata),
    .vgd_ren    (msw_vgd_ren),
    .vgd_wen    (msw_vgd_wen)
  );

  memory #(
    .SZ    (MMEMSZ)
  ) MAIN_MEMORY(
    .clk   (clk),
    .nrst  (nrst),
    .addr  (msw_mmem_addr),
    .wdata (msw_mmem_wdata),
    .size  (msw_mmem_size),
    .nsign (msw_mmem_nsign),
    .ren   (msw_mmem_ren),
    .wen   (msw_mmem_wen),
    .rdata (mmem_msw_rdata),
    .stall (mmem_msw_stall)
  );

  virtio_console_dev VIRTIO_CONSOLE_DEV(
    .clk             (clk),
    .nrst            (nrst),
    .ac_intr_pending (vcd_ac_intr_pending),
    .msw_addr        (msw_vcd_addr),
    .msw_wdata       (msw_vcd_wdata),
    .msw_ren         (msw_vcd_ren),
    .msw_wen         (msw_vcd_wen),
    .msw_rdata       (vcd_msw_rdata),
    .vmgr_busy       (vmgr_busy),
    .vmgr_used       (vmgr_vcd_used),
    .vmgr_queue_rdy  (vcd_vmgr_queue_rdy),
    .vmgr_queue_num  (vcd_vmgr_queue_num),
    .vmgr_notify     (vcd_vmgr_notify),
    .vmgr_drvok      (vcd_vmgr_drvok)
  );

  virtio_gpu_dev VIRTIO_GPU_DEV(
    .clk             (clk),
    .nrst            (nrst),
    .ac_intr_pending (vgd_ac_intr_pending),
    .msw_addr        (msw_vgd_addr),
    .msw_wdata       (msw_vgd_wdata),
    .msw_ren         (msw_vgd_ren),
    .msw_wen         (msw_vgd_wen),
    .msw_rdata       (vgd_msw_rdata),
    .vmgr_busy       (vmgr_busy),
    .vmgr_used       (vmgr_vgd_used),
    .vmgr_queue_rdy  (vgd_vmgr_queue_rdy),
    .vmgr_queue_num  (vgd_vmgr_queue_num),
    .vmgr_notify     (vgd_vmgr_notify),
    .vmgr_drvok      (vgd_vmgr_drvok)
  );

  virtio_switch VIRTIO_SWITCH(
    .clk        (clk),
    .vc_addr    (vc_vsw_addr),
    .vc_wdata   (vc_vsw_wdata),
    .vc_size    (vc_vsw_size),
    .vc_nsign   (vc_vsw_nsign),
    .vc_ren     (vc_vsw_ren),
    .vc_wen     (vc_vsw_wen),
    .vc_rdata   (vsw_vc_rdata),
    .vc_stall   (vsw_vc_stall),
    .vmem_rdata (vmem_vsw_rdata),
    .vmem_stall (vmem_vsw_stall),
    .vmem_addr  (vsw_vmem_addr),
    .vmem_wdata (vsw_vmem_wdata),
    .vmem_size  (vsw_vmem_size),
    .vmem_nsign (vsw_vmem_nsign),
    .vmem_ren   (vsw_vmem_ren),
    .vmem_wen   (vsw_vmem_wen),
    .vmgr_rdata (vmgr_vsw_rdata),
    .vmgr_stall (vmgr_vsw_stall),
    .vmgr_addr  (vsw_vmgr_addr),
    .vmgr_wdata (vsw_vmgr_wdata),
    .vmgr_ren   (vsw_vmgr_ren),
    .vmgr_wen   (vsw_vmgr_wen),
    .msw_rdata  (msw_vsw_rdata),
    .msw_stall  (msw_vsw_stall),
    .msw_addr   (vsw_msw_addr),
    .msw_wdata  (vsw_msw_wdata),
    .msw_size   (vsw_msw_size),
    .msw_nsign  (vsw_msw_nsign),
    .msw_ren    (vsw_msw_ren),
    .msw_wen    (vsw_msw_wen)
  );

  virtio_core VIRTIO_CORE(
    .clk          (clk),
    .nrst         (nrst),
    .vmgr_nsrst   (vmgr_vc_nsrst),
    .vmgr_srstarg (vmgr_vc_srstarg),
    .vsw_rdata    (vsw_vc_rdata),
    .vsw_stall    (vsw_vc_stall),
    .vsw_addr     (vc_vsw_addr),
    .vsw_wdata    (vc_vsw_wdata),
    .vsw_size     (vc_vsw_size),
    .vsw_nsign    (vc_vsw_nsign),
    .vsw_ren      (vc_vsw_ren),
    .vsw_wen      (vc_vsw_wen)
  );

  virtio_manager VIRTIO_MANAGER(
    .clk              (clk),
    .nrst             (nrst),
    .ac_stallable     (ac_vmgr_stallable),
    .uart_rx_byte     (uart_vmgr_rx_byte),
    .uart_rx_ready    (uart_vmgr_rx_ready),
    .uart_tx_busy     (uart_vmgr_tx_busy),
    .uart_tx_byte     (vmgr_uart_tx_byte),
    .uart_tx_start    (vmgr_uart_tx_start),
    .vga_x            (vga_vmgr_x),
    .vga_y            (vga_vmgr_y),
    .vga_r            (vmgr_vga_r),
    .vga_g            (vmgr_vga_g),
    .vga_b            (vmgr_vga_b),
    .vc_nsrst         (vmgr_vc_nsrst),
    .vc_srstarg       (vmgr_vc_srstarg),
    .vsw_addr         (vsw_vmgr_addr),
    .vsw_wdata        (vsw_vmgr_wdata),
    .vsw_ren          (vsw_vmgr_ren),
    .vsw_wen          (vsw_vmgr_wen),
    .vsw_rdata        (vmgr_vsw_rdata),
    .vsw_stall        (vmgr_vsw_stall),
    .vcd_queue_rdy    (vcd_vmgr_queue_rdy),
    .vcd_queue_num    (vcd_vmgr_queue_num),
    .vcd_drvok        (vcd_vmgr_drvok),
    .vcd_notify       (vcd_vmgr_notify),
    .vcd_used         (vmgr_vcd_used),
    .vgd_queue_rdy    (vgd_vmgr_queue_rdy),
    .vgd_queue_num    (vgd_vmgr_queue_num),
    .vgd_drvok        (vgd_vmgr_drvok),
    .vgd_notify       (vgd_vmgr_notify),
    .vgd_used         (vmgr_vgd_used),
    .busy             (vmgr_busy)
  );

  memory #(
    .SZ    (VMEMSZ)
  ) VIRTIO_MEMORY(
    .clk   (clk),
    .nrst  (nrst),
    .addr  (vsw_vmem_addr),
    .wdata (vsw_vmem_wdata),
    .size  (vsw_vmem_size),
    .nsign (vsw_vmem_nsign),
    .ren   (vsw_vmem_ren),
    .wen   (vsw_vmem_wen),
    .rdata (vmem_vsw_rdata),
    .stall (vmem_vsw_stall)
  );

  uart UART(
    .clk           (clk),
    .nrst          (nrst),
    .rx            (rx),
    .tx            (tx),
    .vmgr_tx_byte  (vmgr_uart_tx_byte),
    .vmgr_tx_start (vmgr_uart_tx_start),
    .vmgr_rx_byte  (uart_vmgr_rx_byte),
    .vmgr_rx_ready (uart_vmgr_rx_ready),
    .vmgr_tx_busy  (uart_vmgr_tx_busy)
  );

  vga VGA(
    .vga_clk    (vga_clk),
    .nrst       (nrst),
    .x          (x),
    .y          (y),
    .r          (r),
    .g          (g),
    .b          (b),
    .hsync      (hsync),
    .vsync      (vsync),
    .vmgr_r     (vmgr_vga_r),
    .vmgr_g     (vmgr_vga_g),
    .vmgr_b     (vmgr_vga_b),
    .vmgr_x     (vga_vmgr_x),
    .vmgr_y     (vga_vmgr_y)
  );
endmodule
