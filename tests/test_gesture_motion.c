#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "../firmware/include/gesture_motion_fullwidth.h"
static GestureMotion g;
static unsigned now;
static int frame(int cx,int cy,int flash){
 gesture_begin(&g);
 for(unsigned y=0;y<GH;y++)for(unsigned x=0;x<GW;x++){
  unsigned v=80;
  if(cx>=0 && (int)x>=cx-5 && (int)x<=cx+5 && (int)y>=cy-5 && (int)y<=cy+5)v=180;
  if(flash)v=200;
  gesture_pixel(&g,y*GW+x,x,y,v*0x010101u);
 }
 now+=100;return gesture_end(&g,now,1000);
}
static void reset(void){memset(&g,0,sizeof(g));now=0;for(int i=0;i<8;i++)assert(!frame(-1,15,0));}
static int color_frame(int cx){
 gesture_begin(&g);
 for(unsigned y=0;y<GH;y++)for(unsigned x=0;x<GW;x++){
  /* Equal luma: gray wall (128,128,128), warmer foreground (192,112,96). */
  unsigned bgr=(cx>=0 && (int)x>=cx-5 && (int)x<=cx+5 && y>=10 && y<=20)?0xc07060u:0x808080u;
  gesture_pixel(&g,y*GW+x,x,y,bgr);
 }
 now+=100;return gesture_end(&g,now,1000);
}
int main(void){
 reset();for(int i=0;i<100;i++)assert(!frame(-1,15,0));assert(!g.events);
 reset();int n=0;for(int x=10;x<=54;x+=6)n+=frame(x,15,0);assert(n==1 && g.events==1);
 for(int x=54;x>=10;x-=6)assert(!frame(x,15,0));
 assert(g.events==1);
 for(int i=0;i<16;i++)assert(!frame(-1,15,0));
 n=0;for(int x=54;x>=10;x-=6)n+=frame(x,15,0);assert(n==-1 && g.events==2);
 reset();for(int i=0;i<20;i++)assert(!frame(12,15,0));assert(!g.events);
 reset();for(int y=5;y<25;y++)assert(!frame(12,y,0));assert(!g.events);
 reset();assert(!frame(-1,15,1));for(int i=0;i<12;i++)assert(!frame(-1,15,1));assert(!g.events);
 reset();for(int i=0;i<30;i++)assert(!frame(i%2?16:12,15,0));assert(!g.events);
 reset();now=0xfffffc00u;g.last_tick=now;g.cool_until=now;for(int i=0;i<6;i++)assert(!frame(-1,15,0));
 n=0;for(int x=10;x<=54;x+=6)n+=frame(x,15,0);assert(n==1);
 memset(&g,0,sizeof(g));now=0;for(int i=0;i<8;i++)assert(!color_frame(-1));
 n=0;for(int x=25;x<=49;x+=4)n+=color_frame(x);assert(n==1);
 /* A broad occlusion must not lock out the next swipe in a moving scene. */
 reset();assert(!frame(-1,15,1));assert(!frame(-1,15,0));
 n=0;for(int x=10;x<=54;x+=6)n+=frame(x,15,0);assert(n==1);
 printf("PASS: still, right/left swipe, cooldown, stationary/vertical/jitter/exposure rejection, timer wrap. state=%zu bytes\n",sizeof(g));
}
