#pragma once
#include <stdint.h>
#ifndef SENSOR_TEST
#define SENSOR_WRITE(v) (*(volatile uint32_t*)0xf8104000u=(v))
#define SENSOR_READ() (*(volatile uint32_t*)0xf8104004u)
#define SENSOR_DELAY() bsp_uDelay(5)
#endif
static uint32_t sensor_lines;
volatile uint32_t sensor_nacks,sensor_timeouts,sensor_readback_errors,sensor_writes,sensor_id,sensor_init_done;
static void sensor_pins(uint32_t v){sensor_lines=v;SENSOR_WRITE(v);SENSOR_DELAY();}
static int sensor_scl_high(void){
 sensor_pins(sensor_lines&~1u);
 for(unsigned i=0;i<200;i++){if(SENSOR_READ()&1)return 0;SENSOR_DELAY();}
 sensor_timeouts++;return -1;
}
static int sensor_start(void){
 sensor_pins(sensor_lines|1u);sensor_pins(sensor_lines&~2u);
 if(sensor_scl_high())return -1;
 if(!(SENSOR_READ()&2)){sensor_timeouts++;return -1;}
 sensor_pins(sensor_lines|2u);sensor_pins(sensor_lines|1u);return 0;
}
static int sensor_stop(void){
 sensor_pins(sensor_lines|3u);if(sensor_scl_high())return -1;
 sensor_pins(sensor_lines&~2u);return 0;
}
static int sensor_byte(uint8_t v){
 for(unsigned i=0;i<8;i++){
  sensor_pins(((sensor_lines|1u)&~2u) | ((v&0x80)?0u:2u));
  if(sensor_scl_high())return -1;
  sensor_pins(sensor_lines|1u);v<<=1;
 }
 sensor_pins(sensor_lines&~2u);if(sensor_scl_high())return -1;
 int nack=(SENSOR_READ()&2)!=0;sensor_pins(sensor_lines|1u);
 if(nack)sensor_nacks++;
 return nack?-1:0;
}
static int sensor_read_byte(uint8_t *v){
 uint8_t n=0;sensor_pins(sensor_lines&~2u);
 for(unsigned i=0;i<8;i++){
  if(sensor_scl_high())return -1;
  n=(n<<1)|((SENSOR_READ()>>1)&1);sensor_pins(sensor_lines|1u);
 }
 // Single-byte read terminates with NACK, then STOP.
 if(sensor_scl_high())return -1;
 sensor_pins(sensor_lines|1u);*v=n;return 0;
}
static int sensor_write_reg(uint16_t reg,uint8_t value){
 int rc=sensor_start()||sensor_byte(0x60)||sensor_byte(reg>>8)||sensor_byte(reg)||sensor_byte(value);
 int stop=sensor_stop();if(!rc&&!stop)sensor_writes++;return rc||stop?-1:0;
}
static int sensor_read_reg(uint16_t reg,uint8_t *value){
 int rc=sensor_start()||sensor_byte(0x60)||sensor_byte(reg>>8)||sensor_byte(reg)||sensor_start()||sensor_byte(0x61)||sensor_read_byte(value);
 int stop=sensor_stop();return rc||stop?-1:0;
}
#ifndef SENSOR_TEST
#include "sensor_table.h"
static int sensor_initialize(void){
 sensor_pins(4);bsp_uDelay(10000);sensor_pins(0);bsp_uDelay(20000);
 // Bus recovery is also C-controlled; no hardware auto-initialization remains.
 for(unsigned i=0;i<9;i++){sensor_pins(1);if(sensor_scl_high())return -1;}
 if(sensor_stop())return -1;
 uint8_t hi,lo;
 if(sensor_read_reg(0x3107,&hi)||sensor_read_reg(0x3108,&lo))return -1;
 sensor_id=((uint32_t)hi<<8)|lo;if(sensor_id==0||sensor_id==65535)return -1;
 for(unsigned i=0;i<sizeof(sensor_table)/sizeof(sensor_table[0]);i++){
  if(sensor_write_reg(sensor_table[i].reg,sensor_table[i].value))return -1;
 }
 const uint16_t regs[]={0x3208,0x3209,0x320a,0x320b,0x3e00,0x3e01,0x3e02,0x3221};
 const uint8_t expected[]={7,0x80,4,0x38,0,0xba,0xd0,0x66};
 for(unsigned i=0;i<sizeof(expected);i++){
  uint8_t value;if(sensor_read_reg(regs[i],&value))return -1;
  if(value!=expected[i]){sensor_readback_errors++;return -1;}
 }
 if(sensor_write_reg(0x0100,1))return -1;
 uint8_t value;if(sensor_read_reg(0x0100,&value)||value!=1){sensor_readback_errors++;return -1;}
 sensor_init_done=1;return 0;
}
#endif
