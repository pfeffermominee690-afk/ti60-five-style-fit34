#ifndef GESTURE_MOTION_H
#define GESTURE_MOTION_H
#include <stdint.h>
/* Camera motion gesture, not semantic hand recognition. 64x30 samples cover
 * x=64..568,y=96..328 of the 640x480 capture. No network/model changes. */
#define GW 64
#define GH 30
#define GN (GW*GH)
typedef struct {
 uint16_t background[GN];
 uint32_t seeded,quiet,armed,tracking,age,last_tick,cool_until;
 int32_t start_x,last_x,direction,progress;
 uint32_t count,sum_x,sum_y,abs_sum;
 int32_t signed_sum;
 uint32_t samples,rejected,events;
 int32_t last_event;
} GestureMotion;
static void gesture_begin(GestureMotion *g){
 g->count=0;g->sum_x=0;g->sum_y=0;g->abs_sum=0;g->signed_sum=0;
}
static void gesture_pixel(GestureMotion *g,unsigned i,unsigned x,unsigned y,unsigned bgr){
 unsigned b=bgr&248,gc=(bgr>>8)&252,r=(bgr>>16)&248;
 unsigned packed=(r<<8)|(gc<<3)|(b>>3);
 if(!g->seeded){g->background[i]=packed;return;}
 unsigned old=g->background[i];
 int dr=(int)r-(int)((old>>8)&248),dg=(int)gc-(int)((old>>3)&252),db=(int)b-(int)((old<<3)&248);
 unsigned a=(dr<0?-dr:dr)+(dg<0?-dg:dg)+(db<0?-db:db);
 g->abs_sum+=a;g->signed_sum+=(dr+dg+dg+db)/4;
 if(a>40){g->count++;g->sum_x+=x;g->sum_y+=y;}
 /* Always advance the previous-frame sample. A hand must never become a
  * persistent foreground that permanently prevents re-arming. */
 g->background[i]=packed;
}
static int gesture_end(GestureMotion *g,uint32_t now,uint32_t hz){
 unsigned count=g->count;g->samples++;
 if(!g->seeded){g->seeded=1;g->last_tick=now;g->cool_until=now;g->quiet=0;g->armed=0;g->tracking=0;return 0;}
 if((uint32_t)(now-g->last_tick)>hz/2){g->tracking=0;g->quiet=0;g->armed=0;}
 g->last_tick=now;
 /* Widespread movement / exposure changes invalidate the background. */
 if(count>1300 || g->signed_sum>GN*24 || g->signed_sum < -GN*24){
  g->armed=0;g->tracking=0;g->quiet=0;g->rejected++;return 0;
 }
 if(count<20){if(g->quiet<8)g->quiet++;if(g->quiet>=3)g->armed=1;g->tracking=0;return 0;}
 g->quiet=0;
 if((int32_t)(now-g->cool_until)<0)return 0;
 /* Re-arm after cooldown without demanding a motionless laboratory scene.
  * Direction consistency, travel, duration and broad-motion rejection remain. */
 g->armed=1;
 if(count<35)return 0;
 int x=g->sum_x/count;
 if(!g->tracking){
  g->tracking=1;g->age=now;g->start_x=x;g->last_x=x;
  g->direction=0;g->progress=0;return 0;
 }
 if((uint32_t)(now-g->age)>hz+hz/2){g->tracking=0;g->armed=0;return 0;}
 if(!g->direction){
  if(x-g->start_x>=4)g->direction=1;
  else if(g->start_x-x>=4)g->direction=-1;
  else {g->last_x=x;return 0;}
 }
 int step=x-g->last_x;if(g->direction<0)step=-step;
 if(step < -5){g->tracking=0;g->armed=0;return 0;}
 if(step>1)g->progress++;
 g->last_x=x;
 int distance=x-g->start_x;if(g->direction<0)distance=-distance;
 if(distance>=12 && g->progress>=2 && (uint32_t)(now-g->age)>=hz/5){
  int result=g->direction;g->events++;g->last_event=result;
  g->tracking=0;g->armed=0;g->cool_until=now+hz+hz/4;return result;
 }
 return 0;
}
#endif
