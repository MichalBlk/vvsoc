#ifndef __SOC_H__
#define __SOC_H__

#define PAGESZ 4096

/*
 * VirtIO memory
 */
#define VMEMSZ 4 * PAGESZ
#define VMEM_START 0x10000000

/*
 * VirtIO manager
 */
#define VMGR_START 0x20000000

#define VMGR_REG_UART_RX 0x0
#define VMGR_REG_UART_TX 0x4
#define VMGR_REG_FINISH 0x8

#define VMGR_FINISH_SUCCESS 0
#define VMGR_FINISH_FAILURE 1

/*
 * VirtIO console device
 */
#define VCD_START 0x30000000

#define VCD_QUEUE_NUM_MAX 2

/*
 * Debug console
 */
#define DBGC_START 0x60000000

/*
 * CLINT
 */
#define CLINT_START 0x70000000

#define CLINT_REG_MTIMECMP 0x4000
#define CLINT_REG_MTIME 0xbff8

/*
 * Main memory
 */
#define MMEM_START 0x80000000

#define EMU_START 0x80100000
#define EMU_END 0x80200000

#define DTB_START 0x80200000

#endif /* !__SOC_H__ */
