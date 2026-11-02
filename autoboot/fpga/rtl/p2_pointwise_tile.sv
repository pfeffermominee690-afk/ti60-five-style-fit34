// Actual16-pixel x16-output-channel pointwise convolution tile.
// Native signed8x8 DSP accumulation -> exact raw INT8 requantization.
// Input feature DMA format: each128-bit beat is16 pixels of one channel.
// Result format:16 such channel beats, ready/valid, final beat marks tile done.
// Caller provides already-normalized input features; no layer/DMA engine here.
module p2_pointwise_tile(input clk,rst_n,
 input cache_invalidate,cache_page,input feature_valid,feature_page,
 input[6:0]feature_channel,input[127:0]feature_data,
 input weight_valid,output weight_ready,input[6:0]weight_channel,input[127:0]weight_data,
 input start,input input_page,input[7:0]input_channels,input[95:0]raw_shifts,
 output ready,output reg busy,done,error,
 output m_valid,input m_ready,output[127:0]m_data,output reg[3:0]m_channel,output reg m_last);
 localparam IDLE=0,CLEAR=1,ISSUE=2,FLUSH=3,DRAIN=4,WAIT=5;
 reg[2:0]state;reg page;reg[7:0]cin,issued,received;reg[3:0]drain_channel;reg[95:0]shifts;
 reg[127:0]weight_mem[0:127],weight_read,weight_filled;
 wire cache_sv=state==ISSUE&&issued<cin;wire cache_sr,cache_mv,cache_error;wire[127:0]pixels;
 wire cache_mr=state==ISSUE;
 p2_feature_tile_cache cache(clk,rst_n,cache_invalidate,cache_page,
  feature_valid,feature_page,feature_channel[3:0],feature_channel[6:4],feature_data,
  cache_sv,cache_sr,page,issued[6:0],cache_mv,cache_mr,cache_error,pixels,1'b1);
 assign weight_ready=!busy;
 always @(posedge clk)begin
  if(!rst_n)weight_filled<=0;
  else if(weight_valid&&weight_ready)begin weight_mem[weight_channel]<=weight_data;weight_filled[weight_channel]<=1;end
  if(cache_sv&&cache_sr)weight_read<=weight_mem[issued[6:0]];
 end
 wire[2047:0]a,b;wire[6143:0]dot;
 genvar p,c;
 generate for(p=0;p<16;p=p+1)begin:pixel
  for(c=0;c<16;c=c+1)begin:channel
   assign a[(p*16+c)*8+:8]=pixels[p*8+:8];
   assign b[(p*16+c)*8+:8]=weight_read[c*8+:8];
  end
 end endgenerate
 wire mac_ce=cache_mv&&cache_mr&&!cache_error;
 p2_mac_bank macs(clk,!rst_n||state==CLEAR,mac_ce,a,b,dot);
 wire[15:0]qr,qv;wire take=qr[0]&&state==DRAIN;
 generate for(p=0;p<16;p=p+1)begin:quant
  wire signed[23:0]v=dot[(p*16+drain_channel)*24+:24];
  p2_raw_requant q(clk,rst_n,state==DRAIN,qr[p],v,$signed(shifts[drain_channel*6+:6]),qv[p],m_ready,m_data[p*8+:8]);
 end endgenerate
 assign m_valid=qv[0];assign ready=state==IDLE;
 reg missing;integer k;
 always @*begin missing=0;for(k=0;k<128;k=k+1)if(k<input_channels&&!weight_filled[k])missing=1;end
 always @(posedge clk)begin
 if(!rst_n)begin state<=IDLE;page<=0;cin<=0;issued<=0;received<=0;drain_channel<=0;shifts<=0;busy<=0;done<=0;error<=0;m_channel<=0;m_last<=0;end
 else begin
 done<=0;
 if(take)begin m_channel<=drain_channel;m_last<=drain_channel==15;end
 case(state)
 IDLE:if(start)begin
  error<=0;
  if(input_channels==0||input_channels>128||missing)begin error<=1;done<=1;end
  else begin state<=CLEAR;busy<=1;page<=input_page;cin<=input_channels;shifts<=raw_shifts;issued<=0;received<=0;drain_channel<=0;end
 end
 CLEAR:state<=ISSUE;
 ISSUE:begin
  if(cache_sv&&cache_sr)issued<=issued+1'b1;
  if(cache_mv&&cache_mr)begin
   if(cache_error)begin state<=IDLE;busy<=0;done<=1;error<=1;end
   else begin received<=received+1'b1;if(received==cin-1'b1)state<=FLUSH;end
  end
 end
 FLUSH:state<=DRAIN;
 DRAIN:if(take)begin drain_channel<=drain_channel+1'b1;if(drain_channel==15)state<=WAIT;end
 WAIT:if(m_valid&&m_ready&&m_last)begin state<=IDLE;busy<=0;done<=1;end
 endcase
 end end
endmodule
