#pragma once
// SC431HAI manual pp22-23,28: half-line exposure, N+2 frames to apply,
// 3812=00/30 groups related registers. Frame length and ISP color gains stay fixed.
volatile uint32_t ae_enable=1,ae_exposure=2989,ae_gain_mode=1,ae_mean,ae_clipped;
volatile uint32_t ae_changes,ae_errors,ae_sum,ae_bright,ae_manual;
volatile uint32_t ae_mean_low=116,ae_mean_high=144,ae_settling=12;
static uint32_t ae_count,ae_pending,ae_limit=2989;
static void ae_initialize(void){
 uint8_t h,l;
 if(sensor_read_reg(0x320e,&h)||sensor_read_reg(0x320f,&l)){ae_errors++;ae_enable=0;return;}
 uint32_t limit=2u*(((uint32_t)h<<8)|l);
 if(limit<=15){ae_errors++;ae_enable=0;return;}
 if(limit-11<ae_limit)ae_limit=limit-11;
}
static uint32_t ae_next(uint32_t current,uint32_t mean,uint32_t clipped){
 uint32_t step=current/8;if(!step)step=1;
 // Small sky/lamp regions must not drive the whole scene into darkness.
 if(mean>220||clipped>500)return current/2;
 if(mean>180||(clipped>250&&mean>ae_mean_high))return current-current/4;
 if(mean>ae_mean_high)return current>step?current-step:4;
 if(mean<80)return current+2*step;
 if(mean<ae_mean_low)return current+step;
 return current;
}
static void ae_update(unsigned count){
 if(!ae_enable||++ae_count<6)return;
 ae_count=0;ae_mean=ae_sum/count;ae_clipped=ae_bright*1000/count;
 if(ae_pending){
  uint8_t a,b,c,g,f;
  if(sensor_read_reg(0x3e00,&a)||sensor_read_reg(0x3e01,&b)||sensor_read_reg(0x3e02,&c)||
    ((((uint32_t)a&15)<<12)|((uint32_t)b<<4)|(c>>4))!=ae_exposure||
    sensor_read_reg(0x3e08,&g)||sensor_read_reg(0x3e09,&f)||g!=(ae_gain_mode?0x80:0)||f!=(ae_gain_mode?0x2a:0x20)){ae_errors++;ae_enable=0;return;}
  ae_pending=0;
 }
 uint32_t next=ae_next(ae_exposure,ae_mean,ae_clipped),gain=ae_gain_mode;
 if(gain&&(ae_mean>180||(ae_clipped>250&&ae_mean>ae_mean_high))){gain=0;next=ae_exposure;}
 else if(!gain&&ae_exposure>=ae_limit&&ae_mean<80){gain=1;next=ae_exposure;}
 if(ae_manual){next=ae_manual;gain=ae_gain_mode;}
 if(next<4)next=4;
 if(next>ae_limit)next=ae_limit;
 if(next==ae_exposure&&gain==ae_gain_mode)return;
 int rc=sensor_write_reg(0x3812,0);
 rc|=sensor_write_reg(0x3e00,(uint8_t)(next>>12));
 rc|=sensor_write_reg(0x3e01,(uint8_t)(next>>4));
 rc|=sensor_write_reg(0x3e02,(uint8_t)(next<<4));
 if(gain!=ae_gain_mode){rc|=sensor_write_reg(0x3e08,gain?0x80:0);rc|=sensor_write_reg(0x3e09,gain?0x2a:0x20);}
 rc|=sensor_write_reg(0x3812,0x30);
 if(rc){ae_errors++;ae_enable=0;return;}
 ae_exposure=next;ae_gain_mode=gain;ae_pending=1;ae_changes++;ae_settling=12;
}
