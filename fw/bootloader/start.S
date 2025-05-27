#include <asm.h>
#include <soc.h>

#define SP (BMEM_START + BMEMSZ)

  .section .text

ENTRY(_start)
  li  sp, SP
  tail  main
END(_start)
