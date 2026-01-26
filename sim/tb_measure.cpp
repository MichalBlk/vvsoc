#include <cstdio>
#include <SDL.h>
#include <verilated.h>
#include <termios.h>
#include <unistd.h>

#include "uartsim.h"
#include "uartsim.cpp"

#include "Vtop.h"
#include "Vtop_top.h"
#include "Vtop_clint.h"
#include "Vtop_app_core.h"
#include "Vtop_mmu.h"
#include "Vtop_inst_verifier.h"
#include "Vtop_reg_file.h"
#include "Vtop_csr_reg_file.h"
#include "Vtop_cache.h"
#include "Vtop_virtio_core.h"
#include "Vtop_virtio_manager.h"
#include "Vtop_uart.h"

using namespace std;

typedef unsigned long long ull;

typedef struct Pixel {
  uint8_t a;
  uint8_t b;
  uint8_t g;
  uint8_t r;
} Pixel;

typedef enum {
  OP_LUI,
  OP_AUIPC,
  OP_JMP,
  OP_BRANCH,
  OP_LOAD,
  OP_STORE,
  OP_IMM,
  OP_OP,
  OP_FENCEI,
  OP_MUL,
  OP_DIV,
  OP_LR,
  OP_SC,
  OP_RMW,
  OP_CSR,
  OP_ECALL,
  OP_EBREAK,
  OP_MRET,
  OP_SRET,
  OP_SFENCE_VMA,
  OP_NOP,
  OP_CNT
} op_t;

static constexpr int RESET_CYCLES = 8, WIDTH = 640, HEIGHT = 480, INSTRUCTIONS = 1e9;

Pixel frame[WIDTH * HEIGHT];
termios oldt, newt;
SDL_Window *sdl_window;
SDL_Renderer *sdl_renderer;
SDL_Texture *sdl_texture;
Vtop *dut;
UARTSIM *uart;
int op_cnt[OP_CNT], cycle_cnt[OP_CNT];
bool refresh;

static void restore_terminal(void) {
  tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
}

static void signal_handler(int signo) {
  restore_terminal();
  exit(EXIT_FAILURE);
}

static inline bool done(void) {
  return Verilated::gotFinish() ||
    dut->__PVT__top->__PVT__APP_CORE->pc_r == 0x00000000;
}

static inline int opcode2op(int opcode) {
  if (dut->__PVT__top->__PVT__APP_CORE->iv_nop)
    return OP_NOP;
  if (opcode == 0x37)
    return OP_LUI; 
  if (opcode == 0x17)
    return OP_AUIPC;
  if (opcode == 0x67 || opcode == 0x6f)
    return OP_JMP;
  if (opcode == 0x63)
    return OP_BRANCH;
  if (opcode == 0x3)
    return OP_LOAD;
  if (opcode == 0x23)
    return OP_STORE;
  if (opcode == 0x13)
    return OP_IMM;
  if (opcode == 0x33)
    return OP_OP;
  if (dut->__PVT__top->__PVT__APP_CORE->iv_fencei)
    return OP_FENCEI;
  if (dut->__PVT__top->__PVT__APP_CORE->iv_mul)
    return OP_MUL;
  if (dut->__PVT__top->__PVT__APP_CORE->iv_div)
    return OP_DIV;
  if (dut->__PVT__top->__PVT__APP_CORE->__PVT__INST_VERIFIER->amo_lr)
    return OP_LR;
  if (dut->__PVT__top->__PVT__APP_CORE->__PVT__INST_VERIFIER->amo_sc)
    return OP_SC;
  if (dut->__PVT__top->__PVT__APP_CORE->__PVT__INST_VERIFIER->amo_rmw)
    return OP_RMW;
  if (dut->__PVT__top->__PVT__APP_CORE->__PVT__INST_VERIFIER->csr)
    return OP_CSR;
  if (dut->__PVT__top->__PVT__APP_CORE->__PVT__INST_VERIFIER->ac_ecall)
    return OP_ECALL;
  if (dut->__PVT__top->__PVT__APP_CORE->__PVT__INST_VERIFIER->ac_ebreak)
    return OP_EBREAK;
  if (dut->__PVT__top->__PVT__APP_CORE->__PVT__INST_VERIFIER->ac_mret)
    return OP_MRET;
  if (dut->__PVT__top->__PVT__APP_CORE->__PVT__INST_VERIFIER->ac_sret)
    return OP_SRET;
  if (dut->__PVT__top->__PVT__APP_CORE->__PVT__INST_VERIFIER->ac_sfence_vma)
    return OP_SFENCE_VMA;
  printf("Unknown instruction!\n");
  exit(EXIT_FAILURE);
}

static bool update_frame(void) {
  if (dut->x < WIDTH && dut->y < HEIGHT) {
    Pixel *p = &frame[WIDTH * dut->y + dut->x];
    if (p->b != dut->b || p->g != dut->g || p->r != dut->r) {
      p->b = dut->b;
      p->g = dut->g;
      p->r = dut->r;
      refresh = true;
    }
  }
  if (dut->y == HEIGHT && !dut->x) {
    SDL_Event e;
    if (SDL_PollEvent(&e) && e.type == SDL_QUIT)
      return true;
    if (refresh) {
      SDL_UpdateTexture(sdl_texture, NULL, frame, WIDTH * sizeof(Pixel));
      SDL_RenderClear(sdl_renderer);
      SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
      SDL_RenderPresent(sdl_renderer);
      refresh = false;
    }
  }
  return false;
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  if (SDL_Init(SDL_INIT_VIDEO) < 0) {
    printf("SDL video initialization failed\n");
    exit(EXIT_FAILURE);
  }
  if (!(sdl_window = SDL_CreateWindow("Display", SDL_WINDOWPOS_CENTERED,
    SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, SDL_WINDOW_SHOWN))) {
    printf("SDL window creation failed: %s\n", SDL_GetError());
    exit(EXIT_FAILURE);
  }
  if (!(sdl_renderer = SDL_CreateRenderer(sdl_window, -1,
    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC))) {
    printf("SDL renderer creation failed: %s\n", SDL_GetError());
    exit(EXIT_FAILURE);
  }
  if (!(sdl_texture = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_RGBA8888,
    SDL_TEXTUREACCESS_TARGET, WIDTH, HEIGHT))) {
    printf("SDL texture creation failed: %s\n", SDL_GetError());
    exit(EXIT_FAILURE);
  }

  tcgetattr(STDIN_FILENO, &oldt);
  newt = oldt;
  newt.c_lflag &= ~(ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &newt);
  signal(SIGINT, signal_handler);
  signal(SIGTERM, signal_handler);
  signal(SIGSEGV, signal_handler);

  for (int i = 0; i < WIDTH * HEIGHT; i++)
    frame[i].a = 0xff;

  dut = new Vtop;
  uart = new UARTSIM(0);
  uart->setup(0x08000364);
  dut->nrst = 1;
  dut->eval();
  dut->nrst = 0;
  dut->eval();
  for (int i = 1; !Verilated::gotFinish() && i <= RESET_CYCLES; i++) {
    dut->clk = dut->vga_clk = 0;
    dut->eval();
    dut->clk = dut->vga_clk = 1;
    dut->eval();
  }
  dut->nrst = 1;

  ull start_time = SDL_GetPerformanceCounter(), ticks = 0, pc = 0;
  for (int i = 1; !done() && i <= INSTRUCTIONS; i++) {
    int cycles = 1;
    for (; !done() && !dut->__PVT__top->__PVT__APP_CORE->state; cycles++, ticks++) {
      dut->rx = uart->operator()(dut->tx);
      dut->clk = dut->vga_clk = 0;
      dut->clk = 0;
      dut->eval();
      dut->clk = dut->vga_clk = 1;
      dut->eval();
      if (update_frame())
        goto end;
    }
    if (done())
      break;
    int op = opcode2op(dut->__PVT__top->__PVT__APP_CORE->_opcode);
    op_cnt[op]++;
    for (; !done() && dut->__PVT__top->__PVT__APP_CORE->state; cycles++, ticks++) {
      dut->rx = uart->operator()(dut->tx);
      dut->clk = dut->vga_clk = 0;
      dut->eval();
      dut->clk = dut->vga_clk = 1;
      dut->eval();
      if (update_frame())
        goto end;
    }
    cycle_cnt[op] += cycles;
  }
end:
  ull end_time = SDL_GetPerformanceCounter();
  double time = ((double)end_time - start_time) / SDL_GetPerformanceFrequency();
  double hz = ticks / time;
  printf("hz=%.1f\n", hz);

#define REPORT(OP) printf(#OP " ops=%d, cycles=%d\n", op_cnt[OP_##OP], cycle_cnt[OP_##OP])
  REPORT(LUI);
  REPORT(AUIPC);
  REPORT(JMP);
  REPORT(BRANCH);
  REPORT(LOAD);
  REPORT(STORE);
  REPORT(IMM);
  REPORT(OP);
  REPORT(MUL);
  REPORT(DIV);
  REPORT(LR);
  REPORT(SC);
  REPORT(RMW);
  REPORT(CSR);
  REPORT(ECALL);
  REPORT(EBREAK);
  REPORT(MRET);
  REPORT(SRET);
  REPORT(SFENCE_VMA);
  REPORT(NOP);

  printf("ICACHE: total=%d, hit=%d\n",
    dut->__PVT__top->__PVT__APP_CORE->__PVT__MMU->ic_cnt_r,
    dut->__PVT__top->__PVT__APP_CORE->__PVT__MMU->ic_hcnt_r);

  printf("TLB: total=%d, hit=%d\n",
    dut->__PVT__top->__PVT__APP_CORE->__PVT__MMU->tlb_cnt_r,
    dut->__PVT__top->__PVT__APP_CORE->__PVT__MMU->tlb_hcnt_r);

  printf("CACHE: total=%d, hit=%d\n",
    dut->__PVT__top->__PVT__CACHE->cnt_r, dut->__PVT__top->__PVT__CACHE->hcnt_r);

  restore_terminal();
  return 0;
}
