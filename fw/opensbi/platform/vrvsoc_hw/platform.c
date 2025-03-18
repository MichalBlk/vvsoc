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
#define VRVSOC_VCD_ADDR 0x30000000
#define VRVSOC_CLINT_ADDR 0x70000000
#define VRVSOC_ACLINT_MTIMER_FREQ 50000000
#define VRVSOC_ACLINT_MTIMER_ADDR (VRVSOC_CLINT_ADDR + CLINT_MTIMER_OFFSET)
#define VRVSOC_INTR_PD0 16
#define VRVSOC_INTR_PD1 17

#define VCD_QUEUE_NUM_MAX 2

#define VIRTIO_REG_QUEUE_SELECT 0x30
#define VIRTIO_REG_QUEUE_READY 0x44
#define VIRTIO_REG_QUEUE_NOTIFY 0x50
#define VIRTIO_REG_INTERRUPT_ACK 0x64
#define VIRTIO_REG_STATUS 0x70
#define VIRTIO_REG_QUEUE_DESC_LOW 0x80
#define VIRTIO_REG_QUEUE_DRIVER_LOW 0x90
#define VIRTIO_REG_QUEUE_DEVICE_LOW 0xa0

#define VIRTIO_STATUS_DRIVER_OK 0x4

#define VIRTIO_INTERRUPT_USED_BUF 0x1

#define VIRTIO_CONSOLE_TX_QUEUE_NUM 1

typedef struct {
  void *addr;
  uint32_t __pad;
  uint32_t len;
  uint16_t flags;
  uint16_t next;
} desc_t;

typedef struct {
  uint16_t flags;
  uint16_t idx;
  uint16_t ring[VCD_QUEUE_NUM_MAX];
  uint16_t __pad;
} avail_vring_t;

typedef struct {
  uint16_t flags;
  uint16_t idx;
  struct {
    uint32_t idx;
    uint32_t len;
  } ring[VCD_QUEUE_NUM_MAX];
  uint16_t __pad;
} used_vring_t;

static desc_t vc_d;
static avail_vring_t vc_avr;
static used_vring_t vc_uvr;
static int vc_uidx;
static char vc_c;

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

static inline int vc_rd(int reg) {
  return *(volatile int *)(VRVSOC_VCD_ADDR + reg);
}

static inline void vc_wr(int reg, int val) {
  *(volatile int *)(VRVSOC_VCD_ADDR + reg) = val;
}

static void vc_putc(char c)
{
  vc_c = c;
  vc_avr.idx++;
  vc_wr(VIRTIO_REG_QUEUE_NOTIFY, VIRTIO_CONSOLE_TX_QUEUE_NUM);
  while (vc_uidx == ((volatile used_vring_t *)&vc_uvr)->idx)
    continue;
  vc_wr(VIRTIO_REG_INTERRUPT_ACK, VIRTIO_INTERRUPT_USED_BUF);
  vc_uidx++;
}

struct sbi_console_device console = {
  .console_putc = vc_putc,
};

static int platform_console_init(void)
{
  const char *name = "VirtIO console";
  size_t size = MIN(sbi_strlen(name), sizeof(console.name) - 1);
  sbi_memcpy(console.name, name, size);

  vc_wr(VIRTIO_REG_STATUS, VIRTIO_STATUS_DRIVER_OK);
  vc_wr(VIRTIO_REG_QUEUE_SELECT, VIRTIO_CONSOLE_TX_QUEUE_NUM);
  vc_wr(VIRTIO_REG_QUEUE_DESC_LOW, (int)&vc_d);
  vc_wr(VIRTIO_REG_QUEUE_DRIVER_LOW, (int)&vc_avr);
  vc_wr(VIRTIO_REG_QUEUE_DEVICE_LOW, (int)&vc_uvr);

  vc_d.addr = &vc_c;
  vc_d.len = 1;

  vc_avr.idx = 0;
  vc_avr.ring[0] = vc_avr.ring[1] = 0;

  vc_uidx = vc_uvr.idx = 0;

  vc_wr(VIRTIO_REG_QUEUE_READY, 1);

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
