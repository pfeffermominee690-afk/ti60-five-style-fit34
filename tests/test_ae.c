#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <assert.h>
static uint8_t regs[65536];static unsigned writes,held,bad_read,nack;
static int sensor_read_reg(uint16_t r,uint8_t*v){if(bad_read)return -1;*v=regs[r];return 0;}
static int sensor_write_reg(uint16_t r,uint8_t v){
 if(nack)return -1;
 if(r==0x3812){held=v==0;if(v!=0)assert(v==0x30);}
 else if(r>=0x3e00&&r<=0x3e09)assert(held);
 regs[r]=v;writes++;return 0;
}
#include "../firmware/src/auto_exposure.h"
static void reset(void){memset(regs,0,sizeof(regs));writes=held=bad_read=nack=0;ae_enable=1;ae_exposure=2989;ae_gain_mode=1;ae_count=ae_pending=ae_changes=ae_errors=ae_manual=0;ae_limit=2989;regs[0x320e]=5;regs[0x320f]=0xdc;ae_initialize();}
static void tick(unsigned mean,unsigned clip){ae_sum=mean*1000;ae_bright=clip;ae_update(1000);}
static void window(unsigned mean,unsigned clip){for(int j=0;j<6;j++)tick(mean,clip);}
static unsigned scene(unsigned factor){unsigned y=ae_exposure*factor*(ae_gain_mode?2:1)/1000;return y>255?255:y;}
int main(void){
 reset();for(int j=0;j<5;j++)tick(255,1000);assert(writes==0);
 tick(255,1000);assert(ae_gain_mode==0&&ae_exposure==2989&&!held&&ae_changes==1);
 for(int j=0;j<60;j++){unsigned y=scene(800);window(y,y>=235?1000:0);assert(ae_exposure>=4&&ae_exposure<=2989&&ae_enable&&ae_errors==0);}
 unsigned outdoor=ae_exposure;assert(scene(800)>=ae_mean_low&&scene(800)<=ae_mean_high&&outdoor<300);
 assert(ae_next(100,98,15)>100);assert(ae_next(100,125,60)==100);
 unsigned changes=ae_changes;for(int j=0;j<12;j++)window(scene(800),0);assert(ae_changes==changes);
 for(int j=0;j<80;j++){unsigned y=scene(18);window(y,0);assert(ae_enable&&ae_errors==0);}
 assert(ae_exposure==2989&&ae_gain_mode==1&&scene(18)>=104);
 changes=ae_changes;for(int j=0;j<12;j++)window(scene(18),0);assert(ae_changes==changes);
 ae_manual=1;window(120,0);assert(ae_exposure==4);
 ae_manual=999999;window(120,0);assert(ae_exposure==2989);
 bad_read=1;window(120,0);assert(ae_errors==1&&ae_enable==0);
 reset();nack=1;window(255,1000);assert(ae_errors==1&&ae_enable==0);
 reset();regs[0x320e]=0;regs[0x320f]=10;ae_initialize();assert(ae_limit==9);
 puts("PASS AE: frame spacing, group hold, exposure clamps/VTS bound, bright/dark transitions, stable deadband, manual bounds, readback and NACK fail-stop");
}
