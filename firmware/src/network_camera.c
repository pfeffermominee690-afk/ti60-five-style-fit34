#include "bsp_minimal.h"
#include <stdint.h>
#include "gesture_motion_fullwidth.h"
#include "boot_flash.h"
#include "sensor_driver.h"
#include "auto_exposure.h"
#define N ((volatile uint32_t*)0xf8100000u)
#define V ((volatile uint32_t*)0xf8101000u)
#define MODEL 0xf8200000u
#define MODEL_DDR 0x02f00000u
#define A 0x01400000u
#define B 0x01900000u
volatile uint32_t stage,layer_index,board_error,ready_marker,frames,style_select=0,diagnostic=0,run_command=1;
volatile uint32_t active_style;
volatile uint32_t layer_cycles[15],last_status[8],preprocess_cycles;
volatile uint64_t frame_ticks;volatile uint32_t timer_hz=BSP_CLINT_HZ;
volatile uint32_t benchmark_target,benchmark_samples,benchmark_slow_frames;
volatile uint64_t benchmark_ticks,benchmark_min_ticks,benchmark_max_ticks;
static uint64_t benchmark_previous;
volatile uint32_t gesture_enable=1,gesture_ticks,gesture_max_ticks,gesture_switches;
volatile int32_t gesture_direction;
GestureMotion gesture;
volatile uint32_t gesture_history[8][4],gesture_history_index;
/* The APB window is only CPU-facing; DMA engines use physical addresses.
 * Restore its model bank before dereferencing any descriptor/LUT/parameter. */
static void sample_gesture(uint32_t cap){
 uint32_t start=(uint32_t)clint_getTime(BSP_CLINT);
 volatile uint32_t *bank=(volatile uint32_t*)0xf8102000u;
 *bank=cap;__asm__ volatile("fence iorw,iorw":::"memory");
 ae_sum=0;ae_bright=0;
 gesture_begin(&gesture);
 unsigned i=0;uint32_t row=MODEL+96u*1920u+64u*3u;
 for(unsigned y=0;y<GH;y++,row+=8u*1920u){
  volatile uint32_t *p=(volatile uint32_t*)row;
  for(unsigned x=0;x<GW;x++,p+=6){
   uint32_t bgr=*p;
   unsigned yy=((bgr&255)+2*((bgr>>8)&255)+((bgr>>16)&255))>>2;
   ae_sum+=yy;ae_bright+=(yy>=235);
   gesture_pixel(&gesture,i++,x,y,bgr);
  }
 }
 *bank=MODEL_DDR;__asm__ volatile("fence iorw,iorw":::"memory");
 uint32_t now=(uint32_t)clint_getTime(BSP_CLINT);
 /* Coordinates are camera-image coordinates. Rightward -> next, leftward -> previous. */
 int direction=gesture_end(&gesture,now,BSP_CLINT_HZ);
 unsigned history=gesture_history_index++ & 7u;
 gesture_history[history][0]=gesture.count;
 gesture_history[history][1]=gesture.count?gesture.sum_x/gesture.count:0;
 gesture_history[history][2]=gesture.armed | (gesture.tracking<<1) | (gesture.rejected<<8);
 gesture_history[history][3]=gesture.events;
 if(direction && gesture_enable && !ae_settling){
  unsigned s=style_select;
  style_select=direction>0?(s==4?0:s+1):(s==0?4:s-1);
  gesture_direction=direction;gesture_switches++;
 }
 gesture_ticks=(uint32_t)clint_getTime(BSP_CLINT)-start;
 if(gesture_ticks>gesture_max_ticks)gesture_max_ticks=gesture_ticks;
 ae_update(GN);
 if(ae_settling){ae_settling--;gesture.seeded=0;}
}
static void fence(void){__asm__ volatile("fence iorw, iorw":::"memory");}
static void nw(unsigned i,uint32_t x){N[i]=x;fence();}
static void vw(unsigned i,uint32_t x){V[i]=x;fence();}
__attribute__((noinline)) void board_failed(void){__asm__ volatile("nop":::"memory");}
static void fail(uint32_t e){board_error=e;board_failed();for(;;)__asm__ volatile("nop");}
void trap(void){fail(0xe0000000u|csr_read(mcause));}
__attribute__((noinline)) void diagnostic_done(void){__asm__ volatile("nop":::"memory");}
__attribute__((noinline)) void live_published(void){__asm__ volatile("nop":::"memory");}
__attribute__((noinline)) void benchmark_done(void){__asm__ volatile("nop":::"memory");}
static void record_live_interval(void){
 if(!benchmark_target){benchmark_previous=0;return;}
 uint64_t now=clint_getTime(BSP_CLINT);
 if(!benchmark_previous){benchmark_previous=now;benchmark_samples=0;benchmark_ticks=0;benchmark_min_ticks=~(uint64_t)0;benchmark_max_ticks=0;benchmark_slow_frames=0;return;}
 uint64_t dt=now-benchmark_previous;benchmark_previous=now;
 benchmark_ticks+=dt;if(dt<benchmark_min_ticks)benchmark_min_ticks=dt;if(dt>benchmark_max_ticks)benchmark_max_ticks=dt;
 if(dt>BSP_CLINT_HZ/15)benchmark_slow_frames++;
 if(++benchmark_samples>=benchmark_target){benchmark_target=0;benchmark_previous=0;benchmark_done();}
}
__attribute__((noinline)) void firmware_ready(void){__asm__ volatile("nop":::"memory");}
static void wait_net(void){unsigned ticks=0;while(!(N[1]&2)){bsp_uDelay(10);if(++ticks>100000)fail(0x10000000|layer_index);}if(N[1]&0xf01)fail(0x20000000|N[1]);}
static void wait_capture(void){unsigned ticks=0;while(!(V[2]&2)){bsp_uDelay(10);if(++ticks>200000)fail(4);}if(V[4])fail(0x30000000|V[4]);vw(1,2);}
static void arm_capture(unsigned slot){vw(3,0x01000000u+slot*0x00100000u);vw(1,3);}
void main(void){
 bsp_init();bsp_uDelay(1500000);stage=1;board_error=0;frames=0;ready_marker=0;
 if(N[0]!=0x50324e38u||V[0]!=0x56494431u)fail(1);
 if(sensor_initialize())fail(0xc001);
 ae_initialize();
 boot_load_models();
 const uint32_t *header=(const uint32_t*)MODEL;if(header[0]!=0x50324739u||header[1]!=5||header[12]!=12||header[13]!=1)fail(2);
 firmware_ready();
 // Also safe for firmware-only reload: do not overwrite the currently shown pair.
 unsigned camera_slot=V[8]>=0x01000000u && V[8]<=0x01200000u?((V[8]-0x01000000u)>>20):2;
 camera_slot=camera_slot==2?0:camera_slot+1;
 unsigned output_slot=V[9]==0x03100000u?1:0,capture_armed=0,loaded_style=0xffffffffu;
 const uint32_t saved[3]={0x02500000u,0x02700000u,0x02800000u};
 for(;;){
  while(!run_command){__asm__ volatile("nop");}
  unsigned frame_style=style_select;
  if(frame_style>=5)fail(3);
  active_style=frame_style;
  if(loaded_style!=frame_style){const uint8_t *lut=(const uint8_t*)(MODEL+header[7+frame_style]);nw(33,0);for(unsigned j=0;j<1024;j++)nw(34,lut[j]);loaded_style=frame_style;}
  uint32_t cap=0x01000000u+camera_slot*0x00100000u,dst=0x03100000u+output_slot*0x00100000u;
  uint64_t t=clint_getTime(BSP_CLINT);stage=2;ready_marker=0;
  if(!diagnostic){if(!capture_armed)arm_capture(camera_slot);wait_capture();capture_armed=0;}
  stage=3;layer_index=0xffffffffu;
  nw(4,diagnostic?0x01300000u:cap);nw(6,A);nw(11,diagnostic?0:4096);nw(2,3);if(!diagnostic && (gesture_enable||ae_enable))sample_gesture(cap);wait_net();preprocess_cycles=N[24];
  uint32_t input=A;const uint32_t *desc=(const uint32_t*)(MODEL+header[2+frame_style]);
  for(unsigned l=0;l<15;l++){
   layer_index=l;stage=4;const uint32_t *d=desc+12*l;const uint32_t *p=(const uint32_t*)(MODEL+d[9]);
   uint32_t output=l==14?dst:l==1?saved[0]:l==3?saved[1]:l==5?saved[2]:input==A?B:A;
   nw(4,input);nw(5,d[11]<3?saved[d[11]]:0);nw(6,output);nw(7,MODEL_DDR+d[8]);nw(8,(d[1]<<16)|d[0]);nw(9,(d[3]<<16)|d[2]);nw(10,(d[5]<<8)|d[4]);nw(11,d[6]);nw(12,d[7]);nw(13,l);
   for(unsigned c=0;c<d[5];c++,p+=6){nw(16,c);nw(17,p[0]);nw(18,p[2]);nw(19,p[3]);nw(20,p[4]);nw(21,p[5]);nw(23,1);}
   nw(2,1);wait_net();layer_cycles[l]=N[24];input=output;
   // Triple camera buffers: once the previous publication crossed vertical
   // blank, the next slot is free. Arm early without waiting on every layer;
   // keep the bounded publication check before the last part of inference.
   if(!diagnostic&&!capture_armed){
    if(l>=8){unsigned ticks=0;while(V[2]&8){bsp_uDelay(10);if(++ticks>10000)fail(7);}}
    if(!(V[2]&8)){arm_capture((camera_slot==2?0:camera_slot+1));capture_armed=1;}
   }
  }
  frame_ticks=clint_getTime(BSP_CLINT)-t;stage=5;frames++;ready_marker=0x50415353;
  if(diagnostic){run_command=0;diagnostic_done();}
  else{vw(8,cap);vw(9,dst);vw(10,((frame_style+1u)<<29)|(frames&0x1fffffffu));vw(11,1);last_status[0]=V[13];last_status[1]=V[14];last_status[2]=V[15];last_status[3]=V[16];if(V[13])fail(6);record_live_interval();live_published();camera_slot=(camera_slot==2?0:camera_slot+1);output_slot^=1;}
 }
}
