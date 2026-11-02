// Same transaction contract as p2_pointwise_overlap, without the6144-bit
// result snapshot. Eight DSP groups start four cycles apart. Each group
// drains its two output channels before its own next clear token arrives.
// A global elastic clock-enable preserves alignment under output stalls.
// External banked SRAM interface; one16-pixel input vector per core clock.
module p2_pw_banked(input clk,rst_n,
 input weight_valid,weight_page,output weight_ready,input[6:0]weight_channel,input[127:0]weight_data,
 input start,input input_page,start_weight_page,input[5:0]spatial_block,input[2:0]channel_shift,
 input[7:0]input_channels,input[95:0]raw_shifts,
 output ready,output busy,output reg done,error,
 output cache_valid,input cache_ready,output[575:0]cache_address,
 input cache_mvalid,output cache_mready,input[511:0]cache_data,
 output m_valid,input m_ready,output[63:0]m_data,output reg[3:0]m_channel,output reg m_half,output reg m_last);
 localparam IDLE=0,CLEAR=1,ISSUE=2,COOL=3,ARM=4;
 reg[2:0]state;reg page,wp;reg[7:0]cin,issued,received;reg[95:0]shifts;reg[5:0]tail;reg[5:0]block_index;reg[2:0]cshift;reg[1:0]read_channel;
 wire active=state!=IDLE;
 wire advance=!m_valid||m_ready;
 assign ready=state==IDLE;
 assign busy=active||tail!=0||m_valid;
 assign weight_ready=!(active&&weight_page==wp)&&!(start&&ready&&weight_page==start_weight_page);
 wire cache_sv=state==ISSUE&&issued<cin&&advance;wire cache_sr=cache_ready,cache_mv=cache_mvalid,cache_error=1'b0;wire[127:0]pixels;
 wire cache_mr=state==ISSUE&&advance;
 assign cache_valid=cache_sv;assign cache_mready=cache_mr;
 genvar bank,pixel;
 generate for(bank=0;bank<64;bank=bank+1)begin:ra
 assign cache_address[bank*9+:9]={page,8'd0}|(block_index<<cshift)|(issued>>2);
 end
 for(pixel=0;pixel<16;pixel=pixel+1)begin:pxread
 assign pixels[pixel*8+:8]=cache_data[(pixel*4+read_channel)*8+:8];
 end endgenerate
 always @(posedge clk)if(cache_sv&&cache_sr)read_channel<=issued[1:0];
 reg[127:0]weights[0:255],weight_read,filled[0:1];
 always @(posedge clk)begin
  if(!rst_n)begin filled[0]<=0;filled[1]<=0;end
  else if(weight_valid&&weight_ready)begin weights[{weight_page,weight_channel}]<=weight_data;filled[weight_page][weight_channel]<=1;end
  if(cache_sv&&cache_sr)weight_read<=weights[{wp,issued[6:0]}];
 end
 wire base_data=cache_mv&&state==ISSUE&&!cache_error;
 wire base_last=base_data&&received==cin-1'b1;
 wire base_clear=state==CLEAR;
 reg[127:0]pixel_pipe[0:27];reg[27:0]data_pipe,last_pipe,clear_pipe;
 integer t;
 always @(posedge clk)begin
  if(!rst_n)begin data_pipe<=0;last_pipe<=0;clear_pipe<=0;end
  else if(advance)begin
   data_pipe<={data_pipe[26:0],base_data};last_pipe<={last_pipe[26:0],base_last};clear_pipe<={clear_pipe[26:0],base_clear};
   pixel_pipe[0]<=pixels;for(t=1;t<28;t=t+1)pixel_pipe[t]<=pixel_pipe[t-1];
  end
 end
 wire[767:0]group_dot[0:7];reg[2:0]phase[0:7];reg[11:0]group_shifts[0:7];
 genvar g,p;
 generate for(g=0;g<8;g=g+1)begin:group
  wire[127:0]px;wire[15:0]wt;wire[11:0]qs;wire valid,last,clear;
  if(g==0)begin
   assign px=pixels;assign wt=weight_read[15:0];assign qs=shifts[11:0];
   assign valid=base_data;assign last=base_last;assign clear=base_clear;
  end else begin
   reg[15:0]wpipe[0:4*g-1];reg[11:0]qpipe[0:4*g-1];integer j;
   always @(posedge clk)if(advance)begin
    wpipe[0]<=weight_read[g*16+:16];qpipe[0]<=shifts[g*12+:12];
    for(j=1;j<4*g;j=j+1)begin wpipe[j]<=wpipe[j-1];qpipe[j]<=qpipe[j-1];end
   end
   assign px=pixel_pipe[4*g-1];assign wt=wpipe[4*g-1];assign qs=qpipe[4*g-1];
   assign valid=data_pipe[4*g-1];assign last=last_pipe[4*g-1];assign clear=clear_pipe[4*g-1];
  end
  for(p=0;p<16;p=p+1)begin:pixel
   dual_mac mac(clk,!rst_n||(clear&&advance),valid&&advance,px[p*8+:8],px[p*8+:8],wt[7:0],wt[15:8],group_dot[g][p*48+:48]);
  end
  always @(posedge clk)begin
   if(!rst_n)begin phase[g]<=0;group_shifts[g]<=0;end
   else if(advance)begin
    if(clear)group_shifts[g]<=qs;
    if(last&&valid)phase[g]<=4;else if(phase[g]!=0)phase[g]<=phase[g]-1'b1;
   end
  end
 end endgenerate
 reg quant_valid;reg[2:0]selected;reg second,upper;integer k;
 always @*begin
  quant_valid=0;selected=0;second=0;upper=0;
  for(k=0;k<8;k=k+1)if(phase[k]!=0)begin quant_valid=1;selected=k;second=phase[k]<=2;upper=phase[k]==3||phase[k]==1;end
 end
 wire[7:0]qr,qv;
 generate for(p=0;p<8;p=p+1)begin:quant
  p2_raw_rshift q(clk,rst_n,quant_valid,qr[p],$signed(group_dot[selected][(p+upper*8)*48+second*24+:24]),
   $signed(group_shifts[selected][second*6+:6]),qv[p],m_ready,m_data[p*8+:8]);
 end endgenerate
 assign m_valid=qv[0];
 reg missing;integer z;
 always @*begin missing=0;for(z=0;z<128;z=z+1)if(z<input_channels&&!filled[start_weight_page][z])missing=1;
 for(z=0;z<16;z=z+1)if($signed(raw_shifts[z*6+:6])> -1||$signed(raw_shifts[z*6+:6])< -9)missing=1;end
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;page<=0;wp<=0;cin<=0;issued<=0;received<=0;shifts<=0;tail<=0;done<=0;error<=0;m_channel<=0;m_half<=0;m_last<=0;block_index<=0;cshift<=0;end
  else begin
   done<=m_valid&&m_ready&&m_last;
   // Accept a command independently of output backpressure. ARM retains it
   // until its short-channel output interval cannot collide with the prior job.
   if(state==IDLE&&start)begin
    error<=0;
    if(input_channels==0||input_channels>128||missing)begin error<=1;done<=1;end
    else begin state<=ARM;page<=input_page;block_index<=spatial_block;cshift<=channel_shift;wp<=start_weight_page;cin<=input_channels;shifts<=raw_shifts;issued<=0;received<=0;end
   end
   if(advance)begin
    if(tail!=0)tail<=tail-1'b1;
    if(base_last)tail<=36;
    if(quant_valid)begin m_channel<={selected,second};m_half<=upper;m_last<=selected==7&&second&&upper;end
    case(state)
     // A command can arrive while output is stalled. Do not clear group0
     // until its last half-vector has reached the quantizer.
     ARM:if(tail<=cin && phase[0]<=2)state<=CLEAR;
     CLEAR:state<=ISSUE;
     ISSUE:begin
      if(cache_sv&&cache_sr)issued<=issued+1'b1;
      if(cache_mv)begin
       if(cache_error)begin state<=IDLE;error<=1;done<=1;end
       else begin received<=received+1'b1;if(base_last)state<=COOL;end
      end
     end
     COOL:state<=IDLE;
    endcase
   end
  end
 end
endmodule
