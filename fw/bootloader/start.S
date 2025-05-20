#include <asm.h>
#include <soc.h>

  .section .text

ENTRY(_start)
  li  sp, BMEM_START + 4 * PAGESZ
  tail  main
END(_start)
