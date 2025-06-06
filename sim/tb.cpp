#include <cstdio>
#include <SDL.h>
#include <verilated.h>

#include "uartsim.h"
#include "uartsim.cpp"

#include "Vtop.h"

using namespace std;

typedef unsigned long long ull;

typedef struct Pixel {
  uint8_t a;
  uint8_t b;
  uint8_t g;
  uint8_t r;
} Pixel;

static constexpr int RESET_CYCLES = 8, WIDTH = 640, HEIGHT = 480;

Pixel frame[2][WIDTH * HEIGHT];
Vtop *dut;
UARTSIM *uart;

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
  ull ticks = 0;
  dut = new Vtop;
  uart = new UARTSIM(0);
  uart->setup(0x08000364);
  dut->nrst = 1;
  dut->eval();
  dut->nrst = 0;
  dut->eval();
  for (; !Verilated::gotFinish() && ticks < RESET_CYCLES; ticks++) {
    dut->clk = dut->vga_clk = 1;
    dut->eval();
    dut->clk = dut->vga_clk = 0;
    dut->eval();
  }
  dut->nrst = 1;
  ull start_time = SDL_GetPerformanceCounter();
  bool refresh = false, idx = 0;
  for (ticks = 0; !Verilated::gotFinish(); ticks++) {
    dut->rx = uart->operator()(dut->tx);
    dut->clk = dut->vga_clk = 1;
    dut->eval();
    dut->clk = dut->vga_clk = 0;
    dut->eval();

    if (dut->x < WIDTH && dut->y < HEIGHT) {
      Pixel *p = &frame[idx][WIDTH * dut->y + dut->x];
      Pixel *pp = &frame[idx ^ 1][WIDTH * dut->y + dut->x];
      p->a = 0xff;
      p->b = dut->b;
      p->g = dut->g;
      p->r = dut->r;
      refresh |= p->b != pp->b || p->g != pp->g || p->r != pp->r;
    }

    if (dut->y == HEIGHT && !dut->x) {
      SDL_Event e;
      if (SDL_PollEvent(&e) && e.type == SDL_QUIT)
        break;
      if (refresh) {
        SDL_UpdateTexture(sdl_texture, NULL, frame[idx], WIDTH * sizeof(Pixel));
        SDL_RenderClear(sdl_renderer);
        SDL_RenderCopy(sdl_renderer, sdl_texture, NULL, NULL);
        SDL_RenderPresent(sdl_renderer);
        refresh = false;
      }
      idx ^= 1;
    }
  }
  ull end_time = SDL_GetPerformanceCounter();
  double time = ((double)end_time - start_time) / SDL_GetPerformanceFrequency();
  double hz = ticks / time;
  printf("hz=%.1f\n", hz);
  return 0;
}
