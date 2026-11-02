// Same transaction contract as p2_pointwise_overlap, without the6144-bit
// result snapshot. Eight DSP groups start four cycles apart. Each group
// drains its two output channels before its own next clear token arrives.
// A global elastic clock-enable preserves alignment under output stalls.
// External banked SRAM interface; one16-pixel input vector per core clock.
module p2_shared_banked(input clk,rst_n,
 input weight_valid,weight_page,output weight_ready,input[6:0]weight_channel,input[127:0]weight_data,
 input start,input input_page,start_weight_page,input[5:0]spatial_block,input[2:0]channel_shift,
 input[7:0]input_channels,input[95:0]raw_shifts,
 output ready,output busy,output reg done,error,
 output cache_valid,input cache_ready,output[575:0]cache_address,
 input cache_mvalid,output cache_mready,input[511:0]cache_data,
 output m_valid,input m_ready,output[63:0]m_data,output reg[3:0]m_channel,output reg m_half,output reg m_last,output reg[1:0]m_spatial_group,
 input ext_start,output ext_ready,input ext_final,input[95:0]ext_shifts,
 input ext_valid,output ext_take,input ext_last,input[1:0]ext_group,
 input[511:0]ext_pixels,input[31:0]ext_weights);
 localparam EIDLE=0,ECLEAR=1,EACC=2,EDRAIN=3,EWAIT=4;
 reg[2:0]es;reg ef;reg[95:0]eqs;reg[4:0]eq;
 reg[3:0]ext_complete;reg[3:0]ext_taps[0:3];
 wire external_active=es!=EIDLE;
 localparam IDLE=0,CLEAR=1,ISSUE=2,COOL=3,ARM=4;
 reg[2:0]state;reg page,wp;reg[7:0]cin,issued,received;reg[95:0]shifts;reg[5:0]tail;reg[5:0]block_index;reg[2:0]cshift;reg[1:0]read_channel;
 wire active=state!=IDLE;
 wire advance=!m_valid||m_ready;
 assign ready=state==IDLE&&!external_active;
 assign busy=active||tail!=0||select_valid||m_valid||external_active;
 assign ext_ready=!busy;
 assign ext_take=es==EACC&&advance;
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
 reg[127:0]weights[0:255],weight_read;reg[7:0]filled[0:1];
 always @(posedge clk)begin
  if(!rst_n)begin filled[0]<=0;filled[1]<=0;end
  else if(weight_valid&&weight_ready)begin weights[{weight_page,weight_channel}]<=weight_data;if({1'b0,weight_channel}==filled[weight_page])filled[weight_page]<=filled[weight_page]+1'b1;end
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
   wire[7:0]ea0=ef?ext_pixels[((g/2)*16+p)*8+:8]:ext_pixels[(p*4+(g%2)*2)*8+:8];
   wire[7:0]ea1=ef?ea0:ext_pixels[(p*4+(g%2)*2+1)*8+:8];
   wire ev=ext_valid&&ext_take&&(ef||ext_group==g/2);
   dual_mac mac(clk,!rst_n||(external_active?(es==ECLEAR):(clear&&advance)),
    external_active?ev:(valid&&advance),external_active?ea0:px[p*8+:8],external_active?ea1:px[p*8+:8],
    external_active?ext_weights[(g%2)*16+:8]:wt[7:0],external_active?ext_weights[(g%2)*16+8+:8]:wt[15:8],group_dot[g][p*48+:48]);
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
  if(es==EDRAIN||(es==EACC&&!ef))begin quant_valid=ef||ext_complete[eq[4:3]];selected=eq[4:2];second=eq[1];upper=eq[0];end
 end
 wire signed[5:0]quant_shift=external_active?$signed(eqs[(ef?{2'b00,selected[0],second}:{selected,second})*6+:6]):$signed(group_shifts[selected][second*6+:6]);
 wire[7:0]qr,qv;
 reg select_valid;reg signed[5:0]select_shift;
 reg[3:0]select_channel;reg select_half,select_last;reg[1:0]select_group;
 always @(posedge clk)begin
  if(!rst_n)begin select_valid<=0;select_shift<=0;select_channel<=0;select_half<=0;select_last<=0;select_group<=0;end
  else if(advance)begin
   select_valid<=quant_valid;
   if(quant_valid)begin
    select_shift<=quant_shift;
    select_channel<=external_active&&ef?{2'b00,selected[0],second}:{selected,second};
    select_group<=external_active&&ef?selected[2:1]:2'd0;
    select_half<=upper;select_last<=selected==7&&second&&upper;
   end
  end
 end
 wire[31:0]dot_select;
 generate for(genvar ds=0;ds<32;ds++)begin:dot_decoder
  assign dot_select[ds]=selected==ds/4&&second==((ds/2)%2)&&upper==(ds%2);
 end endgenerate
 generate for(p=0;p<8;p=p+1)begin:quant
  wire[17:0]terms[0:31];wire[17:0]compact_dot;
  reg[17:0]partial[0:7];
  for(genvar section=0;section<8;section++)begin:local_select
   reg[17:0]section_dot;
   always @*begin section_dot=0;for(integer k=0;k<4;k=k+1)section_dot=section_dot|terms[section*4+k];end
   always @(posedge clk)if(advance)partial[section]<=section_dot;
  end
  assign compact_dot=partial[0]|partial[1]|partial[2]|partial[3]|partial[4]|partial[5]|partial[6]|partial[7];
  wire[23:0]dot={compact_dot[16]? (compact_dot[17]?8'hfe:8'hff):(compact_dot[17]?8'h01:8'h00),compact_dot[15:0]};
  for(genvar ds=0;ds<32;ds++)begin:term
   wire[23:0]full_dot=group_dot[ds/4][(p+(ds%2)*8)*48+((ds/2)%2)*24+:24];
   wire overflow=full_dot[23]?(full_dot[23:16]!=8'hff):(full_dot[23:16]!=0);
   assign terms[ds]={overflow,full_dot[23],full_dot[15:0]}&{18{dot_select[ds]}};
  end
  p2_raw_rshift q(clk,rst_n,select_valid,qr[p],$signed(dot),
   select_shift,qv[p],m_ready,m_data[p*8+:8]);
 end endgenerate
 assign m_valid=qv[0];
 reg missing;integer z;
 always @*begin
 case(input_channels)
  3,16,32,64,128:missing=filled[start_weight_page]<input_channels;
  default:missing=1;
 endcase
 for(z=0;z<16;z=z+1)if($signed(raw_shifts[z*6+:6])> -1||$signed(raw_shifts[z*6+:6])< -9)missing=1;end
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;page<=0;wp<=0;cin<=0;issued<=0;received<=0;shifts<=0;tail<=0;done<=0;error<=0;m_channel<=0;m_half<=0;m_last<=0;m_spatial_group<=0;block_index<=0;cshift<=0;end
  else begin
   done<=m_valid&&m_ready&&m_last;
   // Accept a command independently of output backpressure. ARM retains it
   // until its short-channel output interval cannot collide with the prior job.
   if(ready&&start)begin
    error<=0;
    if(input_channels==0||input_channels>128||missing)begin error<=1;done<=1;end
    else begin state<=ARM;page<=input_page;block_index<=spatial_block;cshift<=channel_shift;wp<=start_weight_page;cin<=input_channels;shifts<=raw_shifts;issued<=0;received<=0;end
   end
   if(advance)begin
    if(tail!=0)tail<=tail-1'b1;
    if(base_last)tail<=36;
    if(select_valid)begin m_channel<=select_channel;m_spatial_group<=select_group;m_half<=select_half;m_last<=select_last;end
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
 always @(posedge clk)begin
  if(!rst_n)begin es<=EIDLE;ef<=0;eqs<=0;eq<=0;ext_complete<=0;for(integer j=0;j<4;j++)ext_taps[j]<=0;end
  else begin
   if(es==EACC&&ext_valid&&ext_take&&!ef)begin
    ext_taps[ext_group]<=ext_taps[ext_group]+1'b1;
    if(ext_taps[ext_group]==8)ext_complete[ext_group]<=1;
   end
   if((es==EACC||es==EDRAIN)&&quant_valid&&advance)begin
    if(eq==31)es<=EWAIT;else eq<=eq+1'b1;
   end
   case(es)
   EIDLE:if(ext_start&&ext_ready)begin ef<=ext_final;eqs<=ext_shifts;eq<=0;ext_complete<=0;for(integer j=0;j<4;j++)ext_taps[j]<=0;es<=ECLEAR;end
   ECLEAR:es<=EACC;
   EACC:if(ext_valid&&ext_take&&ext_last)begin es<=EDRAIN;ext_complete<=15;end
   EWAIT:if(m_valid&&m_ready&&m_last)es<=EIDLE;
  endcase
  end
 end
endmodule
