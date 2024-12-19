#ifndef __ASM_H__
#define __ASM_H__

#define ENTRY(x)                                                               \
  .globl x;                                                                    \
  .p2align 2;                                                                  \
  .type x, @function;                                                          \
  x :

#define END(x) .size x, .- x

#endif /* !__ASM_H__ */
