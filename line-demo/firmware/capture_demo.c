#include "bsp_minimal.h"
#include <stdint.h>
#include "sensor_driver.h"
#define V ((volatile uint32_t*)0xf8101000u)
#define Q ((volatile uint32_t*)0xf8100000u)
volatile uint32_t stage,board_error,frames,verified_frames,run_command=1;
volatile uint32_t demo_mode=1,line_threshold=12,diagnostic_view=0;
volatile uint32_t sensor_command,sensor_register,sensor_value,sensor_result;
volatile uint32_t stats[24],samples,centifps,min_centifps=0xffffffffu;
volatile uint64_t elapsed_ticks;
volatile uint32_t capture_timeouts,verify_timeouts,publish_timeouts,guard_errors;
static uint32_t input_baseline,ddr_baseline;static uint64_t epoch,last_time;
static uint32_t last_ddr;static char text[512];
static void fence(void){__asm__ volatile("fence iorw,iorw":::"memory");}
__attribute__((noinline)) void capture_failed(void){__asm__ volatile("nop":::"memory");}
__attribute__((noinline)) void capture_live(void){__asm__ volatile("nop":::"memory");}
static void put(unsigned row,unsigned col,const char*s){while(*s&&col<64)text[row*64+col++]=*s++;}
static void num(unsigned row,unsigned col,uint32_t v){char t[11];unsigned n=0;do{t[n++]=(char)('0'+v%10);v/=10;}while(v);while(n&&col<64)text[row*64+col++]=t[--n];}
static void overlay(void){
 if(V[255]&1)return;
 for(unsigned i=0;i<512;i++)text[i]=' ';
 unsigned details=diagnostic_view||board_error;
 if(!details){
  put(0,0,demo_mode?"LINE ART":"ORIGINAL");put(0,11,"640X480");put(0,21,"FPS ");
  num(0,25,centifps/100);text[27]='.';text[28]='0'+centifps/10%10;text[29]='0'+centifps%10;
 }else{
 put(0,0,demo_mode?"SOBEL LINE ART DEMO   640X480 RGB24":"CAPTURE VALIDATION   640X480 RGB24");
 put(1,0,"DDR FPS ");num(1,8,centifps/100);put(1,10,".");text[75]='0'+centifps/10%10;text[76]='0'+centifps%10;
 put(1,18,"CSI FPS ");num(1,26,V[36]);put(1,32,"NO STYLE NETWORK");
 put(2,0,"CSI ");num(2,4,V[18]-input_baseline);put(2,18,"DDR ");num(2,22,V[6]-ddr_baseline);put(2,36,"CHECKED ");num(2,44,Q[8]);
 put(3,0,"RGB DROP ");num(3,9,V[33]+V[35]);put(3,24,"RAW DROP ");num(3,33,V[34]);
 put(4,0,"WRITE ERR ");num(4,10,V[35]);put(4,24,"READ ERR ");num(4,33,V[13]);put(4,44,"HDMI UF ");num(4,52,V[14]);
 put(5,0,"VERIFY ERR ");num(5,11,Q[3]);put(5,24,"I2C ERR ");num(5,32,sensor_nacks+sensor_timeouts+sensor_readback_errors);
 put(6,0,"SECONDS ");num(6,8,(uint32_t)(elapsed_ticks/BSP_CLINT_HZ));put(6,24,"STATUS ");num(6,31,board_error);put(6,40,"CSI SIZE ERR ");num(6,53,V[45]);
 put(7,0,"TARGET >15FPS / AIM 30FPS / NOT NEURAL INFERENCE");
 }
 for(unsigned i=0;i<128;i++)V[256+i]=(uint32_t)(uint8_t)text[4*i]|((uint32_t)(uint8_t)text[4*i+1]<<8)|((uint32_t)(uint8_t)text[4*i+2]<<16)|((uint32_t)(uint8_t)text[4*i+3]<<24);
 fence();V[255]=1|(details<<1);fence();
}
static void fail(uint32_t code){board_error=code;overlay();capture_failed();for(;;)__asm__ volatile("nop");}
void trap(void){fail(0xe0000000u|csr_read(mcause));}
static void arm(unsigned slot){V[48]=(demo_mode?256:0)|(line_threshold&255);V[3]=0x01000000u+slot*0x100000u;V[1]=3;fence();}
static void guards_init(void){
 for(unsigned slot=0;slot<3;slot++){
  *(volatile uint32_t*)0xf8102000u=0x01000000u+slot*0x100000u;fence();
  for(unsigned k=0;k<16;k++)*(volatile uint32_t*)(0xf8200000u+921600u+k*4)=0x6a19de00u+k;
 }fence();
}
static void guards_check(unsigned slot){
 *(volatile uint32_t*)0xf8102000u=0x01000000u+slot*0x100000u;fence();
 for(unsigned k=0;k<16;k++)if(*(volatile uint32_t*)(0xf8200000u+921600u+k*4)!=0x6a19de00u+k){guard_errors++;fail(0x60);}
}
void main(void){
 bsp_init();stage=1;bsp_uDelay(200000);
 if(V[0]!=0x56494431u||Q[0]!=0x56455231u)fail(1);
 // Video reset is released later than the CPU reset. Read back a nonzero
 // writable configuration before starting the sensor or issuing capture.
 uint32_t initial_config=(demo_mode?256:0)|(line_threshold&255);
 uint64_t ready_deadline=clint_getTime(BSP_CLINT)+2*BSP_CLINT_HZ;
 do {V[48]=initial_config;fence();
  if(clint_getTime(BSP_CLINT)>ready_deadline)fail(6);
 } while(V[48]!=initial_config);
 overlay();stage=2;if(sensor_initialize())fail(2);
 guards_init();bsp_uDelay(100000);
 input_baseline=V[18];ddr_baseline=V[6];epoch=last_time=clint_getTime(BSP_CLINT);last_ddr=V[6];
 unsigned slot=0;arm(slot);stage=3;
 for(;;){
  uint64_t deadline=clint_getTime(BSP_CLINT)+BSP_CLINT_HZ/2;
  while(!(V[2]&2))if(clint_getTime(BSP_CLINT)>deadline){capture_timeouts++;fail(3);}
  if(V[4])fail(0x100|V[4]);
  uint32_t hash[4];for(unsigned i=0;i<4;i++)hash[i]=V[40+i];
  uint32_t addr=0x01000000u+slot*0x100000u;
  // Previous publication must have been acknowledged before reusing its predecessor.
  deadline=clint_getTime(BSP_CLINT)+BSP_CLINT_HZ/10;
  while(V[2]&8)if(clint_getTime(BSP_CLINT)>deadline){publish_timeouts++;fail(4);}
  unsigned next=(slot==2?0:slot+1);
  // Arm immediately; verification/UI run concurrently with the next camera frame.
  arm(next);
  Q[2]=addr;for(unsigned i=0;i<4;i++)Q[4+i]=hash[i];fence();Q[1]=1;fence();
  deadline=clint_getTime(BSP_CLINT)+BSP_CLINT_HZ/10;
  while(!(Q[1]&2))if(clint_getTime(BSP_CLINT)>deadline){verify_timeouts++;fail(5);}
  if(Q[3])fail(0x200|Q[3]);
  guards_check(slot);
  frames++;verified_frames=Q[8];V[8]=addr;V[9]=addr+960;V[10]=frames;fence();V[11]=1;fence();
  slot=next;
  uint64_t now=clint_getTime(BSP_CLINT);elapsed_ticks=now-epoch;
  if(now-last_time>=BSP_CLINT_HZ){
   uint32_t count=V[6];centifps=(uint32_t)((uint64_t)(count-last_ddr)*BSP_CLINT_HZ*100/(now-last_time));
   if(samples>1&&centifps<min_centifps)min_centifps=centifps;
   last_ddr=count;last_time=now;samples++;
   stats[0]=V[18];stats[1]=V[6];stats[2]=V[32];stats[3]=V[33];stats[4]=V[34];stats[5]=V[35];
   stats[6]=V[13];stats[7]=V[14];stats[8]=Q[8];stats[9]=Q[3];stats[10]=guard_errors;stats[11]=V[5];stats[12]=V[45];
   overlay();
  }
  // Debug/CLI mailbox still executes through the C driver, never direct RTL writes.
  if(sensor_command){uint8_t value=(uint8_t)sensor_value;int rc=-1;
   if(sensor_command==1)rc=sensor_read_reg((uint16_t)sensor_register,&value);
   if(sensor_command==2)rc=sensor_write_reg((uint16_t)sensor_register,value);
   sensor_result=rc?0xffffffffu:value;sensor_command=0;
  }
  capture_live();while(!run_command)__asm__ volatile("nop");
 }
}
