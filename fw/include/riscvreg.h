#ifndef __RISCVREG_H__
#define __RISCVREG_H__

#define SBI_EXT_ID_TIME 0x54494D45
#define SBI_SET_TIMER 0

#define STI (1 << 5)
#define MTI (1 << 7)
#define PD1I (1 << 16)

#define FETCH_PAGE_FAULT (1 << 12)
#define LOAD_PAGE_FAULT (1 << 13)
#define STORE_PAGE_FAULT (1 << 15)
#define USER_ECALL (1 << 8)

#define MSTATUS_MIE (1 << 3)

#define CAUSE_INTR (1 << 31)
#define CAUSE_CODE (~CAUSE_INTR)

#define EXP_ILLEGAL_INSTRUCTION 2
#define EXP_MACHINE_TIMER 7
#define EXP_SCALL 9

#define INTR_MT 7
#define INTR_PD1 16

#define csr_write(csr, val) __asm __volatile("csrw " #csr ", %0" ::"r"(val))

#define csr_set(csr, val) __asm __volatile("csrs " #csr ", %0" ::"r"(val))

#define csr_clear(csr, val) __asm __volatile("csrc " #csr ", %0" ::"r"(val))

#define csr_read(csr)                                                          \
  ({                                                                           \
    int val;                                                                   \
    __asm __volatile("csrr %0, " #csr : "=r"(val));                            \
    val;                                                                       \
  })

#define csr_read64(csr)                                                        \
  ({                                                                           \
    long long val;                                                             \
    int high, low;                                                             \
    __asm __volatile("1: "                                                     \
                     "csrr t0, " #csr "h\n"                                    \
                     "csrr %0, " #csr "\n"                                     \
                     "csrr %1, " #csr "h\n"                                    \
                     "bne t0, %1, 1b"                                          \
                     : "=r"(low), "=r"(high)                                   \
                     :                                                         \
                     : "t0");                                                  \
    val = (low | ((long long)high << 32));                                     \
    val;                                                                       \
  })

#endif /* !__RISCVREG_H__ */
