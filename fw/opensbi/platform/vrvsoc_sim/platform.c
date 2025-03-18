/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 */

#include <sbi/riscv_asm.h>
#include <sbi/riscv_encoding.h>
#include <sbi/sbi_string.h>
#include <sbi/sbi_console.h>
#include <sbi/sbi_const.h>
#include <sbi/sbi_platform.h>

#include <sbi_utils/timer/aclint_mtimer.h>

#define VRVSOC_HART_COUNT 1
#define VRVSOC_DBGC_ADDR 0x60000000
#define VRVSOC_CLINT_ADDR 0x70000000
#define VRVSOC_ACLINT_MTIMER_FREQ 50000000
#define VRVSOC_ACLINT_MTIMER_ADDR (VRVSOC_CLINT_ADDR + CLINT_MTIMER_OFFSET)
#define VRVSOC_INTR_PD0 16
#define VRVSOC_INTR_PD1 17

static struct aclint_mtimer_data mtimer = {
  .mtime_freq = VRVSOC_ACLINT_MTIMER_FREQ,
  .mtime_addr = VRVSOC_ACLINT_MTIMER_ADDR + ACLINT_DEFAULT_MTIME_OFFSET,
  .mtime_size = ACLINT_DEFAULT_MTIME_SIZE,
  .mtimecmp_addr = VRVSOC_ACLINT_MTIMER_ADDR + ACLINT_DEFAULT_MTIMECMP_OFFSET,
  .mtimecmp_size = ACLINT_DEFAULT_MTIMECMP_SIZE,
  .first_hartid = 0,
  .hart_count = VRVSOC_HART_COUNT,
  .has_64bit_mmio = false,
};

static void dbgc_putc(char c)
{
  *((volatile char *)VRVSOC_DBGC_ADDR) = c;
}

struct sbi_console_device console = {
  .console_putc = dbgc_putc,
};

static int platform_console_init(void)
{
  const char *name = "DBG console";
  size_t size = MIN(sbi_strlen(name), sizeof(console.name) - 1);
  sbi_memcpy(console.name, name, size);
  sbi_console_set_device(&console);
  return 0;
}

static int platform_irqchip_init(bool coldboot)
{
  csr_set(CSR_MIDELEG, (1 << VRVSOC_INTR_PD0) | (1 << VRVSOC_INTR_PD1));
  return 0;
}

static int platform_timer_init(bool coldboot)
{
  int ret;

  if (coldboot) {
    ret = aclint_mtimer_cold_init(&mtimer, NULL);
    if (ret)
      return ret;
  }

  return aclint_mtimer_warm_init();
}

const struct sbi_platform_operations platform_ops = {
  .console_init = platform_console_init,
  .irqchip_init = platform_irqchip_init,
  .timer_init = platform_timer_init
};

const struct sbi_platform platform = {
  .opensbi_version = OPENSBI_VERSION,
  .platform_version = SBI_PLATFORM_VERSION(0x0, 0x00),
  .name = "VirtIO RISC-V SoC",
  .features = SBI_PLATFORM_DEFAULT_FEATURES,
  .hart_count = VRVSOC_HART_COUNT,
  .hart_stack_size = SBI_PLATFORM_DEFAULT_HART_STACK_SIZE,
  .platform_ops_addr = (unsigned long)&platform_ops
};
