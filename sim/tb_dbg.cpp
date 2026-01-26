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

#define PRINT_PC 1

typedef unsigned long long ull;

typedef struct Pixel {
  uint8_t a;
  uint8_t b;
  uint8_t g;
  uint8_t r;
} Pixel;

static constexpr int RESET_CYCLES = 8, WIDTH = 640, HEIGHT = 480;

Pixel frame[WIDTH * HEIGHT];
termios oldt, newt;
Vtop *dut;
UARTSIM *uart;

static void restore_terminal(void) {
  tcsetattr(STDIN_FILENO, TCSANOW, &oldt);
}

static void signal_handler(int signo) {
  restore_terminal();
  exit(EXIT_FAILURE);
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);

  if (SDL_Init(SDL_INIT_VIDEO) < 0) {
    printf("SDL video initialization failed\n");
    exit(EXIT_FAILURE);
  }
  SDL_Window *sdl_window = SDL_CreateWindow("Display", SDL_WINDOWPOS_CENTERED,
    SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, SDL_WINDOW_SHOWN);
  if (!sdl_window) {
    printf("SDL window creation failed: %s\n", SDL_GetError());
    exit(EXIT_FAILURE);
  }
  SDL_Renderer *sdl_renderer = SDL_CreateRenderer(sdl_window, -1,
    SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
  if (!sdl_renderer) {
    printf("SDL renderer creation failed: %s\n", SDL_GetError());
    exit(EXIT_FAILURE);
  }
  SDL_Texture *sdl_texture = SDL_CreateTexture(sdl_renderer, SDL_PIXELFORMAT_RGBA8888,
    SDL_TEXTUREACCESS_TARGET, WIDTH, HEIGHT);
  if (!sdl_texture) {
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
  bool refresh = false;
  for (ticks = 0; !Verilated::gotFinish(); ticks++) {
    dut->rx = uart->operator()(dut->tx);
    dut->clk = dut->vga_clk = 0;
    dut->eval();
    dut->clk = dut->vga_clk = 1;
    dut->eval();

#if PRINT_PC
    if (dut->__PVT__top->__PVT__APP_CORE->pc_r != pc) {
      fprintf(stderr, "%08x\n", dut->__PVT__top->__PVT__APP_CORE->pc_r);
      pc = dut->__PVT__top->__PVT__APP_CORE->pc_r;
    }
#endif

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
        break;
      if (refresh) {
        SDL_UpdateTexture(sdl_texture, NULL, frame, WIDTH * sizeof(Pixel));
        SDL_RenderClear(sdl_renderer);
        SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
        SDL_RenderPresent(sdl_renderer);
        refresh = false;
      }
    }
  }
  ull end_time = SDL_GetPerformanceCounter();
  double time = ((double)end_time - start_time) / SDL_GetPerformanceFrequency();
  double hz = ticks / time;
  printf("hz=%.1f\n", hz);

  restore_terminal();
  return 0;
}
