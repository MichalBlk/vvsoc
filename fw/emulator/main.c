#include <riscvreg.h>
#include <soc.h>

void trap_entry(void);

static __attribute__((__noreturn__)) void halt(void) {
  for (;;)
    continue;
}

static int read_reg(int id) {
  return ((int *)EMU_END - 32)[id];
}

static void write_reg(int id, int val) {
  ((int *)EMU_END - 32)[id] = val;
}

static void set_mtimer(int low, int high) {
  volatile int *cmp = (volatile int *)(CLINT_START + CLINT_REG_MTIMECMP);
  cmp[1] = -1;
  cmp[0] = low;
  cmp[1] = high;
}

int init(void) {
  csr_write(mtvec, trap_entry);
  csr_write(mscratch, EMU_END - 32 * 4);
  csr_write(mstatus, 0x800 | (1 << 7));
  csr_write(mepc, 0x80000000);
  csr_set(medeleg, FETCH_PAGE_FAULT | LOAD_PAGE_FAULT | STORE_PAGE_FAULT | USER_ECALL);
  csr_set(mideleg, PD1I | STI);
  csr_set(mcounteren, 0x7);
}

void trap(void) {
  int cause = csr_read(mcause);
  if (cause & CAUSE_INTR) {
    if ((cause & CAUSE_CODE) != INTR_MT)
      halt();
    csr_set(mip, STI);
    csr_clear(mie, MTI);
    return;
  }
  if (cause == EXP_SCALL) {
    int a0 = read_reg(10), a1 = read_reg(11);
    if (read_reg(17) != SBI_EXT_ID_TIME || read_reg(16) != SBI_SET_TIMER)
      halt();
    set_mtimer(a0, a1);
    csr_set(mie, MTI);
    csr_clear(mip, STI);
    csr_write(mepc, csr_read(mepc) + 4);
    return;
  }
  halt();
}
