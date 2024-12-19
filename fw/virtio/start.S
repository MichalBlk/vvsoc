#include <asm.h>
#include <soc.h>

#define SP (VMEM_START + VMEMSZ)

  .section .text

ENTRY(_start)
  li  sp, SP
  tail  process
END(_start)
