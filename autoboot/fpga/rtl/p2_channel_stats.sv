// 16 pixels from one channel per beat. Packed synchronous RAM statistics.
// Read/modify/write bypass supports consecutive beats of the same channel.
// Idle reads use read_channel; allow two idle clocks before coefficient use.
// Reset/clear walks 128 entries rather than resetting all RAM bits.
module p2_channel_stats(input clk,rst_n,clear,input valid,input[6:0]channel,
 input[127:0]pixels,input[6:0]read_channel,
 output signed[26:0]sum,output[32:0]sumsq,output ready);
 reg[59:0]mem[0:127],read_data,last_data;
 reg clearing;reg[6:0]clear_index,pc,last_channel;reg pv,last_valid;
 reg signed[12:0]part_sum,saved_sum;reg[18:0]part_square,saved_square;
 reg signed[7:0]v;reg signed[15:0]product;integer i;
 always @*begin
  part_sum=0;part_square=0;v=0;product=0;
  for(i=0;i<16;i=i+1)begin
   v=$signed(pixels[i*8+:8]);product=v*v;
   part_sum=part_sum+v;part_square=part_square+{3'b0,product};
  end
 end
 wire[59:0]base=last_valid&&last_channel==pc?last_data:read_data;
 wire signed[26:0]new_sum=$signed(base[26:0])+saved_sum;
 wire[32:0]new_square=base[59:27]+saved_square;
 wire[59:0]updated={new_square,new_sum};
 assign ready=!clearing&&!clear;
 assign sum=read_data[26:0];assign sumsq=read_data[59:27];
 wire write_enable=clearing||(pv&&!clear);
 wire[6:0]write_address=clearing?clear_index:pc;
 wire[59:0]write_data=clearing?60'd0:updated;
 wire[6:0]read_address=valid&&ready?channel:read_channel;
 always @(posedge clk)begin
  if(write_enable)mem[write_address]<=write_data;
  read_data<=mem[read_address];
 end
 always @(posedge clk)begin
  if(!rst_n)begin clearing<=1;clear_index<=0;pv<=0;last_valid<=0;pc<=0;last_channel<=0;saved_sum<=0;saved_square<=0;last_data<=0;end
  else if(clear)begin clearing<=1;clear_index<=0;pv<=0;last_valid<=0;end
  else if(clearing)begin
   if(clear_index==127)clearing<=0;else clear_index<=clear_index+1'b1;
   pv<=0;last_valid<=0;
  end else begin
   pv<=valid;
   if(valid)begin pc<=channel;saved_sum<=part_sum;saved_square<=part_square;end
   last_valid<=pv;
   if(pv)begin last_channel<=pc;last_data<=updated;end
  end
 end
endmodule
