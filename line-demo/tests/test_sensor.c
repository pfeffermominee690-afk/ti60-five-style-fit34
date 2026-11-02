#include <stdint.h>
#include <stdio.h>
#include <assert.h>
static uint32_t pins;static unsigned phase,nbytes,starts,stops,slave_read,readbit,stuck,nack,stretch;
static uint8_t byte,bytes[100],readvalue=0xa5;
static int active;
static void mock_write(uint32_t v){
 int oscl=!(pins&1),nscl=!(v&1),osda=!(pins&2),nsda=!(v&2);
 if(oscl&&nscl&&osda&&!nsda){active=1;phase=0;byte=0;slave_read=0;starts++;}
 if(oscl&&nscl&&!osda&&nsda){active=0;stops++;}
 if(active&&!oscl&&nscl){
  if(!slave_read&&phase<8)byte=(byte<<1)|nsda;
  phase++;
 }
 if(active&&oscl&&!nscl&&phase==9){
  if(!slave_read){bytes[nbytes++]=byte;if(byte==0x61)slave_read=1;}
  else slave_read=0;
  phase=0;byte=0;
 }
 pins=v;
}
static uint32_t mock_read(void){
 unsigned scl=!(pins&1),sda=!(pins&2);
 if(stuck)scl=0;else if(stretch){stretch--;scl=0;}
 if(active&&scl){
  if(!slave_read&&phase==9)sda=nack?1:0;
  if(slave_read&&phase>=1&&phase<=8)sda=(readvalue>>(8-phase))&1;
 }
 return scl|(sda<<1);
}
#define SENSOR_TEST
#define SENSOR_WRITE(v) mock_write(v)
#define SENSOR_READ() mock_read()
#define SENSOR_DELAY() ((void)0)
#include "../firmware/sensor_driver.h"
int main(void){
 sensor_pins(0);assert(sensor_write_reg(0x3208,7)==0);
 assert(nbytes==4&&bytes[0]==0x60&&bytes[1]==0x32&&bytes[2]==8&&bytes[3]==7&&starts==1&&stops==1);
 uint8_t value=0;nbytes=0;assert(sensor_read_reg(0x3107,&value)==0);assert(value==0xa5);
 assert(nbytes==4&&bytes[0]==0x60&&bytes[1]==0x31&&bytes[2]==7&&bytes[3]==0x61&&starts==3&&stops==2);
 nack=1;assert(sensor_write_reg(1,2)!=0&&sensor_nacks==1);nack=0;
 stuck=1;assert(sensor_write_reg(1,2)!=0&&sensor_timeouts>0);stuck=0;active=0;sensor_pins(0);
 stretch=3;assert(sensor_write_reg(0x3209,0x80)==0);
 puts("PASS C driver write, repeated START read, ACK/NACK, SCL timeout and clock stretching");
}
