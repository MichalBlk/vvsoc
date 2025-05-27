#ifndef __SOC_H__
#define __SOC_H__

#define PAGESZ 4096

/*
 * VirtIO memory
 */
#define VMEMSZ (2 * PAGESZ)
#define VMEM_START 0x10000000

/*
 * VirtIO manager
 */
#define VMGR_START 0x20000000

#define VMGR_REG_UART_RX 0x0
#define VMGR_REG_UART_TX 0x4
#define VMGR_REG_VGA_UPDATE 0x8
#define VMGR_REG_FINISH 0xc

#define VMGR_FINISH_SUCCESS 0
#define VMGR_FINISH_FAILURE 1

#define VMGR_DEV_VCD 0
#define VMGR_DEV_VGD 1

#define VMGR_ARG_QN_MASK 0x1
#define VMGR_ARG_DEV_SH 1

/*
 * VirtIO console device
 */
#define VCD_START 0x30000000

#define VCD_QUEUE_NUM_MAX 2

/*
 * VirtIO GPU device
 */
#define VGD_START 0x40000000

#define VGD_QUEUE_NUM_MAX 8

#define VGA_WIDTH 320
#define VGA_HEIGHT 240

/*
 * Boot memory
 */
#define BMEMSZ PAGESZ
#define BMEM_START 0x50000000

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
 * Flash
 */
#define FL_OPENSBI_START 0xf0000000
#define FL_DTB_START 0xf0020000
#define FL_KERNEL_START 0xf0021000
#define FL_INITRD_START 0xf0421000

/*
 * Main memory
 */
#define MMEM_START 0x80000000

#define MMEM_OPENSBI_START 0x81000000
#define MMEM_DTB_START 0x81100000
#define MMEM_KERNEL_START 0x80000000
#define MMEM_INITRD_START 0x82000000

/*
 * Images
 */
#define OPENSBI_SIZE 0x20000
#define DTB_SIZE 0x1000
#define KERNEL_SIZE 0x400000
#define INITRD_SIZE 0x700000

#endif /* !__SOC_H__ */
