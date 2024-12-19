#include <riscvreg.h>
#include <soc.h>

#define max(a,b) \
  ({ __typeof__ (a) _a = (a); \
      __typeof__ (b) _b = (b); \
    _a > _b ? _a : _b; })


#define min(a,b) \
  ({ __typeof__ (a) _a = (a); \
      __typeof__ (b) _b = (b); \
    _a < _b ? _a : _b; })

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

static int read_word(int address, int *data){
	int result, tmp, failed;
	__asm__ __volatile__ (
		"  	li       %[tmp],  0x00020000\n"
		"	csrs     mstatus,  %[tmp]\n"
		"  	la       %[tmp],  1f\n"
		"	csrw     mtvec,  %[tmp]\n"
		"	li       %[failed], 1\n"
		"	lw       %[result], 0(%[address])\n"
		"	li       %[failed], 0\n"
		"1:\n"
		"  	li       %[tmp],  0x00020000\n"
		"	csrc     mstatus,  %[tmp]\n"
		: [result]"=&r" (result), [failed]"=&r" (failed), [tmp]"=&r" (tmp)
		: [address]"r" (address)
		: "memory"
	);
  csr_write(mtvec, trap_entry);
	*data = result;
	return failed;
}

static int write_word(int address, int data){
	int tmp, failed;
	__asm__ __volatile__ (
		"  	li       %[tmp],  0x00020000\n"
		"	csrs     mstatus,  %[tmp]\n"
		"  	la       %[tmp],  1f\n"
		"	csrw     mtvec,  %[tmp]\n"
		"	li       %[failed], 1\n"
		"	sw       %[data], 0(%[address])\n"
		"	li       %[failed], 0\n"
		"1:\n"
		"  	li       %[tmp],  0x00020000\n"
		"	csrc     mstatus,  %[tmp]\n"
		: [failed]"=&r" (failed), [tmp]"=&r" (tmp)
		: [address]"r" (address), [data]"r" (data)
		: "memory"
	);
  csr_write(mtvec, trap_entry);
	return failed;
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
  if (cause != EXP_ILLEGAL_INSTRUCTION)
    halt();
  int inst = csr_read(mtval);
  int opcode = inst & 0x7f;
  if (opcode != 0x2f)
    halt();
  int sel = inst >> 27, addr = read_reg((inst >> 15) & 0x1f);
  int src = read_reg((inst >> 20) & 0x1f), rd = (inst >> 7) & 0x1f;
  int rval, wval;
  if (read_word(addr, &rval))
    halt();
  switch (sel) {
    case 0x0: wval = src + rval; break;
    case 0x1: wval = src; break;
    case 0x4: wval = src ^ rval; break;
    case 0x8: wval = src | rval; break;
    case 0xc: wval = src & rval; break;
    case 0x10: wval = min(src, rval); break;
    case 0x14: wval = max(src, rval); break;
    case 0x18: wval = min((unsigned)src, (unsigned)rval); break;
    case 0x1c: wval = max((unsigned)src, (unsigned)rval); break;
    default: halt();
  }
  if (write_word(addr, wval))
    halt();
  write_reg(rd, rval);
  csr_write(mepc, csr_read(mepc) + 4);
}
