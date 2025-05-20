ENTRY(_start)

SECTIONS
{
  .text 0x50000000:
  {
    *(.text .text.*)
  }

  .rodata ALIGN(0x4):
  {
    *(.rodata .rodata.*)
  }

  .data ALIGN(0x4):
  {
    *(.data .data.*)
  }

  .bss ALIGN(0x4):
  {
    *(COMMON)
    *(.bss .bss.*)
  }
}
