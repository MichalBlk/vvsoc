# Compiler pre-processor flags
platform-cppflags-y =

# C Compiler and assembler flags.
platform-cflags-y =
platform-asflags-y =

# Linker flags: additional libraries and object files that the platform
# code needs can be added here
platform-ldflags-y =

# Platform RISC-V XLEN, ABI, ISA and Code Model configuration.
PLATFORM_RISCV_XLEN = 32
PLATFORM_RISCV_ABI = ilp32
PLATFORM_RISCV_ISA = rv32ima_zicsr_zifencei
PLATFORM_RISCV_CODE_MODEL = medany

# Space separated list of object file names to be compiled for the platform
platform-objs-y += platform.o

FW_TEXT_START=0x81000000

# Dynamic firmware configuration.
FW_DYNAMIC=n

# Jump firmware configuration.
FW_JUMP=y
# This needs to be 4MB aligned for 32-bit support
FW_JUMP_ADDR=0x80000000
FW_JUMP_FDT_ADDR=0x81100000

# Firmware with payload configuration.
FW_PAYLOAD=n
