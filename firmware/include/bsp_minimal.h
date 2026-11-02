#pragma once
#include "soc.h"
#include "riscv.h"
#include "clint.h"
#define BSP_CLINT SYSTEM_CLINT_CTRL
#define BSP_CLINT_HZ SYSTEM_CLINT_HZ
#define bsp_uDelay(usec) clint_uDelay(usec, SYSTEM_CLINT_HZ, SYSTEM_CLINT_CTRL)
extern void trap_entry(void);
static inline void bsp_init(void){csr_write(mtvec,(uint32_t)trap_entry);}
