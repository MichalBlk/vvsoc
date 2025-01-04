`ifndef __ISA_PKG_SVH__
`define __ISA_PKG_SVH__

package isa_pkg;
  /*
   * Basic parameters
   */
  parameter BLEN     = 8;
  parameter BLEN_LOG = $clog2(BLEN);

  /*
   * Register size
   */
  parameter XLEN      = 32;
  parameter XLENB     = XLEN / BLEN;
  parameter XLEN_LOG  = $clog2(XLEN);
  parameter XLENB_LOG = $clog2(XLENB);

  /*
   * Register count
   */
  parameter REGCNT     = 32;
  parameter REGCNT_LOG = $clog2(REGCNT);

  /*
   * Instruction size
   */
  parameter ILEN      = 32;
  parameter ILENB     = ILEN / BLEN;
  parameter ILEN_LOG  = $clog2(ILEN);
  parameter ILENB_LOG = $clog2(ILENB);

  /*
   * Opcodes
   */
  parameter OPCODELEN       = 7;
  parameter OPCODESH        = 0;

  parameter OPCODE_LOAD     = 'h03;
  parameter OPCODE_MISC_MEM = 'h0f;
  parameter OPCODE_OP_IMM   = 'h13;
  parameter OPCODE_AUIPC    = 'h17;
  parameter OPCODE_STORE    = 'h23;
  parameter OPCODE_AMO      = 'h2f;
  parameter OPCODE_OP       = 'h33;
  parameter OPCODE_LUI      = 'h37;
  parameter OPCODE_BRANCH   = 'h63;
  parameter OPCODE_JALR     = 'h67;
  parameter OPCODE_JAL      = 'h6f;
  parameter OPCODE_SYSTEM   = 'h73;

  /*
   * Funct3
   */
  parameter FUNCT3LEN      = 3;
  parameter FUNCT3SH       = 12;
  parameter FUNCT3_SIZESH  = 0;
  parameter FUNCT3_NSIGNSH = 2;

	parameter FUNCT3_ADD     = 0;
	parameter FUNCT3_SUB     = 0;
	parameter FUNCT3_SLL     = 1;
	parameter FUNCT3_SLT     = 2;
	parameter FUNCT3_SLTU    = 3;
	parameter FUNCT3_XOR     = 4;
	parameter FUNCT3_SRL     = 5;
	parameter FUNCT3_SRA     = 5;
	parameter FUNCT3_OR      = 6;
	parameter FUNCT3_AND     = 7;

	parameter FUNCT3_BEQ     = 0;
	parameter FUNCT3_BNE     = 1;
	parameter FUNCT3_BLT     = 4;
	parameter FUNCT3_BGE     = 5;
	parameter FUNCT3_BLTU    = 6;
	parameter FUNCT3_BGEU    = 7;

	parameter FUNCT3_FENCE   = 0;
	parameter FUNCT3_FENCEI  = 1;

  parameter FUNCT3_MUL     = 0;
  parameter FUNCT3_MULH    = 1;
  parameter FUNCT3_MULHSU  = 2;
  parameter FUNCT3_MULHU   = 3;
  parameter FUNCT3_DIV     = 4;
  parameter FUNCT3_DIVU    = 5;
  parameter FUNCT3_REM     = 6;
  parameter FUNCT3_REMU    = 7;

	parameter FUNCT3_PRIV    = 0;
	parameter FUNCT3_CSRRW   = 1;
	parameter FUNCT3_CSRRS   = 2;
	parameter FUNCT3_CSRRC   = 3;
	parameter FUNCT3_CSRRWI  = 5;
	parameter FUNCT3_CSRRSI  = 6;
	parameter FUNCT3_CSRRCI  = 7;

  /*
   * Funct5
   */
  parameter FUNCT5LEN       = 5;
  parameter FUNCT5SH        = 27;

  parameter FUNCT5_AMO_LR   = 'h02;
  parameter FUNCT5_AMO_SC   = 'h03;
  parameter FUNCT5_AMO_SWAP = 'h01;
  parameter FUNCT5_AMO_ADD  = 'h00;
  parameter FUNCT5_AMO_XOR  = 'h04;
  parameter FUNCT5_AMO_AND  = 'h0c;
  parameter FUNCT5_AMO_OR   = 'h08;
  parameter FUNCT5_AMO_MIN  = 'h10;
  parameter FUNCT5_AMO_MAX  = 'h14;
  parameter FUNCT5_AMO_MINU = 'h18;
  parameter FUNCT5_AMO_MAXU = 'h1c;

  /*
   * Funct7
   */
  parameter FUNCT7LEN         = 7;
  parameter FUNCT7SH          = 25;

  parameter FUNCT7_ADD        = 'h00;
  parameter FUNCT7_SLL        = 'h00;
  parameter FUNCT7_SLT        = 'h00;
  parameter FUNCT7_SLTU       = 'h00;
  parameter FUNCT7_XOR        = 'h00;
  parameter FUNCT7_SRL        = 'h00;
  parameter FUNCT7_OR         = 'h00;
  parameter FUNCT7_AND        = 'h00;
  parameter FUNCT7_SUB        = 'h20;
  parameter FUNCT7_SRA        = 'h20;

  parameter FUNCT7_MULDIV     = 'h01;

  parameter FUNCT7_SFENCE_VMA = 'h09;

  /*
   * Funct12
   */
  parameter FUNCT12LEN         = 12;
  parameter FUNCT12SH          = 20;
  parameter FUNCT12_PRIVSH     = 8;

	parameter FUNCT12_ECALL      = 'h000;
	parameter FUNCT12_EBREAK     = 'h001;
	parameter FUNCT12_MRET       = 'h302;
	parameter FUNCT12_SRET       = 'h102;
	parameter FUNCT12_SFENCE_VMA = 'h120;
	parameter FUNCT12_WFI        = 'h105;

  /*
   * Register encoding
   */
  parameter RS1SH = 15;
  parameter RS2SH = 20;
  parameter RDSH  = 7;

  /*
   * Immediate encoding
   */
  parameter IMM_ISH   = 20;
  parameter IMM_ILEN  = 12;

  parameter IMM_S0SH   = 7;
  parameter IMM_S0LEN  = 5;
  parameter IMM_S5SH   = 25;
  parameter IMM_S5LEN  = 7;

  parameter IMM_B1SH   = 8;
  parameter IMM_B1LEN  = 4;
  parameter IMM_B5SH   = 25;
  parameter IMM_B5LEN  = 6;
  parameter IMM_B11SH  = 7;
  parameter IMM_B12SH  = 31;

  parameter IMM_USH    = 12;
  parameter IMM_ULEN   = 20;

  parameter IMM_J1SH   = 21;
  parameter IMM_J1LEN  = 10;
  parameter IMM_J11SH  = 20;
  parameter IMM_J12SH  = 12;
  parameter IMM_J12LEN = 8;
  parameter IMM_J20SH  = 31;

  /*
   * NOP
   */
  parameter NOP = (FUNCT3_ADD << FUNCT3SH) | (OPCODE_OP_IMM << OPCODESH);

  /*
   * Privilege levels
   */
  parameter PRIVLEN = 2;

  typedef enum logic [PRIVLEN - 1:0] {
    PRIV_U = PRIVLEN'(0),
    PRIV_S = PRIVLEN'(1),
    PRIV_H = PRIVLEN'(2),
    PRIV_M = PRIVLEN'(3)
  } priv_t;

  /*
   * CSRs
   */
  parameter CSRCNT     = 4096;
  parameter CSRCNT_LOG = $clog2(CSRCNT);

  typedef enum logic [CSRCNT_LOG - 1:0] {
    CSR_SSTATUS    = CSRCNT_LOG'('h100),
    CSR_SEDELEG    = CSRCNT_LOG'('h102),
    CSR_SIDELEG    = CSRCNT_LOG'('h103),
    CSR_SIE        = CSRCNT_LOG'('h104),
    CSR_STVEC      = CSRCNT_LOG'('h105),
    CSR_SCOUNTEREN = CSRCNT_LOG'('h106),
    CSR_SSCRATCH   = CSRCNT_LOG'('h140),
    CSR_SEPC       = CSRCNT_LOG'('h141),
    CSR_SCAUSE     = CSRCNT_LOG'('h142),
    CSR_STVAL      = CSRCNT_LOG'('h143),
    CSR_SIP        = CSRCNT_LOG'('h144),
    CSR_SATP       = CSRCNT_LOG'('h180),

    CSR_MSTATUS    = CSRCNT_LOG'('h300),
    CSR_MISA       = CSRCNT_LOG'('h301),
    CSR_MEDELEG    = CSRCNT_LOG'('h302),
    CSR_MIDELEG    = CSRCNT_LOG'('h303),
    CSR_MIE        = CSRCNT_LOG'('h304),
    CSR_MTVEC      = CSRCNT_LOG'('h305),
    CSR_MCOUNTEREN = CSRCNT_LOG'('h306),
    CSR_MSTATUSH   = CSRCNT_LOG'('h310),
    CSR_MSCRATCH   = CSRCNT_LOG'('h340),
    CSR_MEPC       = CSRCNT_LOG'('h341),
    CSR_MCAUSE     = CSRCNT_LOG'('h342),
    CSR_MTVAL      = CSRCNT_LOG'('h343),
    CSR_MIP        = CSRCNT_LOG'('h344),

    CSR_MCYCLE     = CSRCNT_LOG'('hb00),
    CSR_MINSTRET   = CSRCNT_LOG'('hb02),
    CSR_MCYCLEH    = CSRCNT_LOG'('hb80),
    CSR_MINSTRETH  = CSRCNT_LOG'('hb82),

    CSR_CYCLE      = CSRCNT_LOG'('hc00),
    CSR_TIME       = CSRCNT_LOG'('hc01),
    CSR_INSTRET    = CSRCNT_LOG'('hc02),

    CSR_CYCLEH     = CSRCNT_LOG'('hc80),
    CSR_TIMEH      = CSRCNT_LOG'('hc81),
    CSR_INSTRETH   = CSRCNT_LOG'('hc82),

    CSR_MVENDORID  = CSRCNT_LOG'('hf11),
    CSR_MARCHID    = CSRCNT_LOG'('hf12),
    CSR_MIMPID     = CSRCNT_LOG'('hf13),
    CSR_MHARTID    = CSRCNT_LOG'('hf14)
  } csr_addr_t;

  /*
   * Exceptions
   */
  typedef enum logic [XLEN - 2:0] {
    CAUSE_MISALIGNED_FETCH     = (XLEN - 1)'(0),
    CAUSE_FETCH_FAULT          = (XLEN - 1)'(1),
    CAUSE_ILLEGAL_INSTRUCTION  = (XLEN - 1)'(2),
    CAUSE_BREAKPOINT           = (XLEN - 1)'(3),
    CAUSE_MISALIGNED_LOAD      = (XLEN - 1)'(4),
    CAUSE_LOAD_FAULT           = (XLEN - 1)'(5),
    CAUSE_MISALIGNED_STORE_AMO = (XLEN - 1)'(6),
    CAUSE_STORE_AMO_FAULT      = (XLEN - 1)'(7),
    CAUSE_USER_ECALL           = (XLEN - 1)'(8),
    CAUSE_FETCH_PAGE_FAULT     = (XLEN - 1)'(12),
    CAUSE_LOAD_PAGE_FAULT      = (XLEN - 1)'(13),
    CAUSE_STORE_AMO_PAGE_FAULT = (XLEN - 1)'(15)
  } exc_t;

  /*
   * Interrupts
   */
  typedef enum logic [XLEN_LOG - 1:0] {
    STI  = XLEN_LOG'(5),
    MTI  = XLEN_LOG'(7),
    SEI  = XLEN_LOG'(9),
    MEI  = XLEN_LOG'(11),
    PD1I = XLEN_LOG'(16)
  } intr_t;

  /*
   * Counters
   */
  parameter CNTLEN     = 64;
  parameter CNTCNT     = 32;
  parameter CNTCNT_LOG = $clog2(CNTCNT);

  /*
   * TVEC
   */
  parameter TVEC_MODELEN = 2;

  /*
   * COUNTEREN
   */
  parameter COUNTEREN_CYCLESH   = 0;
  parameter COUNTEREN_TIMESH    = 1;
  parameter COUNTEREN_INSTRETSH = 2;

  parameter COUNTEREN_MASK      = (1 << COUNTEREN_INSTRETSH) | (1 << COUNTEREN_TIMESH) |
    (1 << COUNTEREN_CYCLESH);

  /*
   * MSTATUS
   */
  parameter MSTATUS_SIESH  = 1;
  parameter MSTATUS_MIESH  = 3;
  parameter MSTATUS_SPIESH = 5;
  parameter MSTATUS_MPIESH = 7;
  parameter MSTATUS_SPPSH  = 8;
  parameter MSTATUS_MPPSH  = 11;
  parameter MSTATUS_MPRVSH = 17;
  parameter MSTATUS_SUMSH  = 18;
  parameter MSTATUS_MXRSH  = 19;

  parameter MSTATUS_MASK   = (1 << MSTATUS_MXRSH) | (1 << MSTATUS_SUMSH) | (1 << MSTATUS_MPRVSH) |
    (((1 << PRIVLEN) - 1) << MSTATUS_MPPSH) | (1 << MSTATUS_SPPSH) | (1 << MSTATUS_MPIESH) |
    (1 << MSTATUS_SPIESH) | (1 << MSTATUS_MIESH) | (1 << MSTATUS_SIESH);

  parameter MSTATUS_SMASK  = (1 << MSTATUS_MXRSH) | (1 << MSTATUS_SUMSH) | (1 << MSTATUS_SPPSH) |
    (1 << MSTATUS_SPIESH) | (1 << MSTATUS_SIESH);

  /*
   * MEDELEG
   */
  parameter MEDELEG_MASK = (1 << CAUSE_STORE_AMO_PAGE_FAULT) | (1 << CAUSE_LOAD_PAGE_FAULT) |
    (1 << CAUSE_FETCH_PAGE_FAULT) | (1 << (CAUSE_USER_ECALL + PRIV_S)) | (1 << CAUSE_USER_ECALL) |
    (1 << CAUSE_STORE_AMO_FAULT) | (1 << CAUSE_MISALIGNED_STORE_AMO) | (1 << CAUSE_LOAD_FAULT) |
    (1 << CAUSE_MISALIGNED_LOAD) | (1 << CAUSE_BREAKPOINT) | (1 << CAUSE_ILLEGAL_INSTRUCTION) |
    (1 << CAUSE_FETCH_FAULT) | (1 << CAUSE_MISALIGNED_FETCH);

  /*
   * MIDELEG
   */
  parameter MIDELEG_MASK = (1 << PD1I) | (1 << STI);

  /*
   * MIE
   */
  parameter MIE_MASK = (1 << PD1I) | (1 << MTI) | (1 << STI);

  /*
   * MIP
   */
  parameter MIP_MASK = (1 << STI);

  /*
   * SATP
   */
  parameter SATP_PPNSH  = 0;
  parameter SATP_MODESH = 31;

  parameter SATP_MASK   = (1 << SATP_MODESH) | ({PNLEN{1'b1}} << SATP_PPNSH);

  /*
   * Sv32
   */
  parameter ACCLEN          = 3;

  typedef enum logic [ACCLEN - 1:0] {
    ACC_NONE  = ACCLEN'(0),
    ACC_LOAD  = ACCLEN'(1),
    ACC_STORE = ACCLEN'(2),
    ACC_FETCH = ACCLEN'(4)
  } access_t;

  parameter VADDR_VPN0SH    = 12;
  parameter VADDR_VPN1SH    = 22;

  parameter PTELEN          = 32;
  parameter PTELENB         = PTELEN / BLEN;
  parameter PTELEN_LOG      = $clog2(PTELEN);
  parameter PTELENB_LOG     = $clog2(PTELENB);

  parameter PTE_VSH         = 0;
  parameter PTE_RSH         = 1;
  parameter PTE_WSH         = 2;
  parameter PTE_XSH         = 3;
  parameter PTE_USH         = 4;
  parameter PTE_ASH         = 6;
  parameter PTE_DSH         = 7;
  parameter PTE_PPN0SH      = 10;
  parameter PTE_PPN1SH      = 20;

  parameter PTE_XWR_RESV0   = (1 << PTE_WSH);
  parameter PTE_XWR_RESV1   = (1 << PTE_XSH) | (1 << PTE_WSH);

  parameter PAGESZ          = 2**12;
  parameter PAGESZ_LOG      = $clog2(PAGESZ);
  parameter PNLEN           = XLEN - PAGESZ_LOG;

  parameter SUPERPAGESZ     = 2**22;
  parameter SUPERPAGESZ_LOG = $clog2(SUPERPAGESZ);
  parameter SPNLEN          = XLEN - SUPERPAGESZ_LOG;

  parameter PT_ADDRLEN      = 10;

  /*
   * Calling convention
   */
  parameter REG_A0 = 10;
endpackage

`endif /* !__ISA_PKG_SVH__ */
