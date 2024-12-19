#include <iostream>
#include <verilated.h>

#include "uartsim.h"
#include "uartsim.cpp"

#include "Vtop.h"

using namespace std;

static constexpr int RESET_CYCLES = 8;

Vtop *dut; /* do not optimize away */
UARTSIM *uart;

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  vluint64_t ticks = 0;
  dut = new Vtop;
  uart = new UARTSIM(0);
//  uart->setup(0x08001458);
  dut->nrst = 0;
  for (; !Verilated::gotFinish() && ticks < RESET_CYCLES; ticks++) {
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
  }
  dut->nrst = 1;
  for (; !Verilated::gotFinish(); ticks++) {
    dut->rx = uart->operator()(dut->tx);
    dut->clk = 0;
    dut->eval();
    dut->clk = 1;
    dut->eval();
  }
  cout << "ticks=" << ticks << endl;
  return 0;
}
