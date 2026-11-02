#pragma once
// Read-only boot path. Flash erasure/programming is performed by the host tool.
#include "boot_payload.h"
volatile uint32_t boot_stage,boot_flash_id,boot_crc,boot_bytes;
static void fail(uint32_t e);
#define BOOT_SPI ((volatile uint32_t*)0xf8103000u)
static void boot_cs(unsigned value){BOOT_SPI[0]=value;__asm__ volatile("fence iorw,iorw":::"memory");}
static unsigned boot_byte(unsigned value){
 BOOT_SPI[1]=value; __asm__ volatile("fence iorw,iorw":::"memory");
 uint32_t start=(uint32_t)clint_getTime(BSP_CLINT);
 while(BOOT_SPI[2]&1u)if((uint32_t)clint_getTime(BSP_CLINT)-start>BSP_CLINT_HZ/10)fail(0xb001);
 return BOOT_SPI[1]&255u;
}
static uint32_t boot_word(void){uint32_t x=0;for(unsigned i=0;i<4;i++)x|=boot_byte(0xff)<<(8*i);return x;}
static uint32_t boot_crc_word(uint32_t crc,uint32_t word){
 for(unsigned i=0;i<4;i++){crc^=word&255;word>>=8;for(unsigned b=0;b<8;b++)crc=(crc>>1)^((0u-(crc&1u))&0xedb88320u);}return crc;
}
static void boot_read_start(uint32_t addr){boot_cs(0);boot_byte(3);boot_byte(addr>>16);boot_byte(addr>>8);boot_byte(addr);}
static void boot_load_models(void){
 boot_stage=1;boot_cs(1);bsp_uDelay(10);boot_cs(0);boot_byte(0xab);boot_cs(1);bsp_uDelay(100);
 boot_cs(0);boot_byte(0xe9);boot_cs(1);bsp_uDelay(10);
 boot_cs(0);boot_byte(0x9f);uint32_t id=boot_byte(0xff)<<16;id|=boot_byte(0xff)<<8;id|=boot_byte(0xff);boot_cs(1);boot_flash_id=id;
 if(id==0 || id==0xffffffu)fail(0xb002);
 boot_read_start(BOOT_FLASH_ADDRESS);
 uint32_t magic=boot_word(),length=boot_word(),crc_expected=boot_word(),version=boot_word();boot_cs(1);
 if(magic!=0x50324254u||length!=BOOT_MODEL_SIZE||crc_expected!=BOOT_MODEL_CRC||version!=1)fail(0xb003);
 boot_stage=2;
 *(volatile uint32_t*)0xf8102000u=0x02f00000u;__asm__ volatile("fence iorw,iorw":::"memory");
 volatile uint32_t *dest=(volatile uint32_t*)0xf8200000u;
 boot_read_start(BOOT_FLASH_ADDRESS+256);
 uint32_t crc=0xffffffffu;
 for(unsigned i=0;i<BOOT_MODEL_SIZE/4;i++){uint32_t v=boot_word();dest[i]=v;crc=boot_crc_word(crc,v);boot_bytes=(i+1)*4;}
 boot_cs(1);boot_crc=~crc;if(boot_crc!=BOOT_MODEL_CRC)fail(0xb004);
 boot_stage=3;__asm__ volatile("fence iorw,iorw":::"memory");crc=0xffffffffu;
 for(unsigned i=0;i<BOOT_MODEL_SIZE/4;i++)crc=boot_crc_word(crc,dest[i]);
 boot_crc=~crc;if(boot_crc!=BOOT_MODEL_CRC)fail(0xb005);
 boot_stage=4;
}
