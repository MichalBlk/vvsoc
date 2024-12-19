#include <asm.h>
#include <soc.h>

  .section .text

ENTRY(_start)
  li  sp, EMU_END - 32 * 4
  call  init
  li  a0, 0
  li  a1, DTB_START
  mret
END(_start)
