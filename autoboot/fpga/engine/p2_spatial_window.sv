// Banked four-row circular cache window source. SYMMETRIC padding matches model.
// DW: 16 spatial lanes x 4 channels; final: 64 spatial lanes x 1 channel.
// Stride-2 DW uses two reads to resolve spatial bank conflicts; others use one.
module p2_spatial_window #(parameter COMPACT_ADDRESS=0)(input clk,rst_n,start,input final_mode,stride2,upsample2,
 input[9:0]input_width,input_height,tile_x,tile_y,input[6:0]lane_count,
 input[6:0]channel_base,input[2:0]channel_groups,input[39:0]row_tags,input[3:0]row_valid,
 input weight_valid,input[8:0]weight_address,input[31:0]weight_data,
 output ready,output reg done,error,
 output cache_valid,input cache_ready,output reg[575:0]cache_address,
 input cache_mvalid,output cache_mready,input[511:0]cache_data,
 output m_valid,input m_ready,output[511:0]m_pixels,output[31:0]m_weights,
 output[1:0]m_group,output m_last);
 reg running,all_issued,fin,s2,u2;reg[9:0]iw,ih,tx,ty;reg[6:0]lanes,cb;reg[2:0]groups;
 reg[1:0]kx,ky,group;reg[3:0]channel;reg phase;
 reg[31:0]weights[0:511],read_weight;
 reg[63:0]byte_mask,saved_mask;
 reg[8:0]saved_shift;reg saved_left,saved_right,saved_odd;reg[6:0]saved_lanes;
 reg[1:0]saved_kx;reg saved_up_phase;
 reg first_left,right_edge;
 reg saved_phase,saved_two,saved_last;reg[1:0]saved_group;
 reg[255:0]low;
 wire two=s2&&!fin&&lanes>8;
 wire last_address=kx==2&&ky==2&&(fin?channel==15:group==groups-1)&&(!two||phase);
 reg signed[11:0]sy,sx,ex,ey;reg[9:0]ix,iy;reg[8:0]addr;reg[4:0]word_width;reg[6:0]logical_ch;reg missing_row;
 wire[8:0]addr_next=addr+9'd1;
 function automatic [8:0] product(input [6:0] a,input [4:0] width);
  case(width)3:product=(a<<1)+a;5:product=(a<<2)+a;10:product=(a<<3)+(a<<1);20:product=(a<<4)+(a<<2);default:product=0;endcase
 endfunction
 always @*begin
  cache_address=0;byte_mask=0;missing_row=0;sy=0;sx=0;ix=0;iy=0;addr=0;logical_ch=0;first_left=0;right_edge=0;
  ex=iw<<u2;ey=ih<<u2;word_width=fin?((iw+63)>>6):((iw+15)>>4);
  sy=(ty<<s2)+ky-1;if(sy<0)sy=-sy-1;else if(sy>=ey)sy=2*ey-1-sy;iy=sy>>u2;
  missing_row=!row_valid[iy&3]||row_tags[(iy&3)*10+:10]!=iy;
  sx=((tx+(two&&phase?8:0))<<s2)+kx-1;first_left=sx<0;
  right_edge=!s2&&tx+lanes==ex&&kx==2;
  if(sx<0)sx=-sx-1;else if(sx>=ex)sx=2*ex-1-sx;ix=sx>>u2;
  logical_ch=fin?channel:(cb>>2)+group;
  addr=product((logical_ch<<2)+(iy&3),word_width)+(fin?(ix>>6):(ix>>4));
  for(integer bank=0;bank<64;bank=bank+1)
   cache_address[bank*9+:9]=((fin?bank:bank/4)<(fin?(ix&63):(ix&15)))?addr_next:addr;
  if(COMPACT_ADDRESS)begin
   cache_address=0;cache_address[8:0]=addr;cache_address[17:9]=addr_next;
   for(integer b=0;b<64;b=b+1)cache_address[18+b]=((fin?b:b/4)<(fin?(ix&63):(ix&15)));
  end
  for(integer p=0;p<64;p=p+1)
   if((fin?p:(p/4))<lanes&&(fin||!two||(p/32)==phase))byte_mask[p]=1;
 end
 assign ready=!running&&!m_valid;
 assign cache_valid=running&&!all_issued&&!missing_row;
 // Local elastic route register separates banked memory wiring from DSP inputs.
 reg out_valid;reg[511:0]out_pixels;reg[31:0]out_weights;reg[1:0]out_group;reg out_last;
 wire out_advance=!out_valid||m_ready;
 assign cache_mready=saved_two&&!saved_phase?1'b1:out_advance;
 wire routed_valid=cache_mvalid&&(!saved_two||saved_phase);
 assign m_valid=out_valid;assign m_pixels=out_pixels;assign m_weights=out_weights;
 assign m_group=out_group;assign m_last=out_last;
 always @(posedge clk)begin
  if(!rst_n)out_valid<=0;
  else if(out_advance)begin
   out_valid<=routed_valid;
   if(routed_valid)begin
    out_pixels<=saved_two?{routed[511:256],low}:routed;
    out_weights<=read_weight;out_group<=saved_group;out_last<=saved_last;
   end
  end
 end
 wire request=cache_valid&&cache_ready;
 wire[8:0]wa=fin?((ky*3+kx)*16+channel):((cb>>4)*36+(ky*3+kx)*4+group);
 always @(posedge clk)begin
  if(weight_valid&&ready)weights[weight_address]<=weight_data;
  if(request)read_weight<=weights[wa];
 end
 wire[511:0]routed;
 wire[14:0]route_select;
 generate for(genvar ri=0;ri<15;ri++)begin:route_decode
  assign route_select[ri]=saved_kx==ri%3 &&
   (ri/3==0?fin:ri/3==1?!fin&&!s2&&!u2:ri/3==2?!fin&&s2:ri/3==3?!fin&&!s2&&u2&&!saved_up_phase:!fin&&!s2&&u2&&saved_up_phase);
 end endgenerate
 genvar op;
 generate for(op=0;op<64;op=op+1)begin:route_byte
  localparam SP=op/4,CH=op%4,PP=SP%8,UM=SP==0?-1:(SP-1)/2;
  wire right=saved_right&&((SP==3&&saved_lanes==4)||(SP==7&&saved_lanes==8)||(SP==15&&saved_lanes==16));
  wire[7:0]choices[0:14];wire[7:0]terms[0:14];reg[7:0]result;
  assign choices[0]=(saved_left&&op==0)?cache_data[7:0]:cache_data[((op+63)%64)*8+:8];
  assign choices[1]=cache_data[op*8+:8];
  assign choices[2]=(saved_right&&op==63)?cache_data[op*8+:8]:cache_data[((op+1)%64)*8+:8];
  assign choices[3]=(saved_left&&SP==0)?cache_data[CH*8+:8]:cache_data[((SP+15)%16)*32+CH*8+:8];
  assign choices[4]=cache_data[SP*32+CH*8+:8];
  assign choices[5]=right?choices[4]:cache_data[((SP+1)%16)*32+CH*8+:8];
  assign choices[6]=(saved_left&&PP==0)?cache_data[CH*8+:8]:cache_data[((PP*2+15)%16)*32+CH*8+:8];
  assign choices[7]=cache_data[PP*2*32+CH*8+:8];
  assign choices[8]=cache_data[(PP*2+1)*32+CH*8+:8];
  assign choices[9]=(saved_left&&SP==0)?cache_data[CH*8+:8]:cache_data[((UM+16)%16)*32+CH*8+:8];
  assign choices[10]=cache_data[(SP/2)*32+CH*8+:8];
  assign choices[11]=right?choices[10]:cache_data[(((SP+1)/2)%16)*32+CH*8+:8];
  assign choices[12]=cache_data[((UM+8)%16)*32+CH*8+:8];
  assign choices[13]=cache_data[((SP/2+8)%16)*32+CH*8+:8];
  assign choices[14]=right?choices[13]:cache_data[(((SP+1)/2+8)%16)*32+CH*8+:8];
  for(genvar ri=0;ri<15;ri++)begin:select_term
   assign terms[ri]=choices[ri]&{8{route_select[ri]}};
  end
  always @*begin result=0;for(integer ri=0;ri<15;ri++)result=result|terms[ri];end
  assign routed[op*8+:8]=saved_mask[op]?result:8'd0;
 end endgenerate
 always @(posedge clk)begin
  if(!rst_n)begin running<=0;all_issued<=0;fin<=0;s2<=0;u2<=0;iw<=0;ih<=0;tx<=0;ty<=0;lanes<=0;cb<=0;groups<=0;kx<=0;ky<=0;group<=0;channel<=0;phase<=0;
   saved_kx<=0;saved_up_phase<=0;saved_shift<=0;saved_left<=0;saved_right<=0;saved_odd<=0;saved_lanes<=0;saved_mask<=0;saved_phase<=0;saved_two<=0;saved_last<=0;saved_group<=0;low<=0;done<=0;error<=0;
  end else begin
   done<=0;
   if(start&&ready)begin
    error<=0;
    if(!(input_width==40||input_width==80||input_width==160||input_width==320)||input_height==0||tile_x[3:0]!=0||(final_mode&&tile_x[5:0]!=0)||(final_mode?lane_count!=64:!(lane_count==4||lane_count==8||lane_count==16))||channel_groups==0||channel_groups>4||channel_base[1:0]!=0||(final_mode&&(stride2||upsample2||input_width!=320)))begin error<=1;done<=1;end
    else begin running<=1;all_issued<=0;fin<=final_mode;s2<=stride2;u2<=upsample2;iw<=input_width;ih<=input_height;tx<=tile_x;ty<=tile_y;lanes<=lane_count;cb<=channel_base;groups<=channel_groups;kx<=0;ky<=0;group<=0;channel<=0;phase<=0;end
   end
   if(running&&!all_issued&&missing_row)begin error<=1;all_issued<=1;end
   if(request)begin
    saved_kx<=kx;saved_up_phase<=tx[4];saved_shift<=fin?(ix&63)*8:(ix&15)*32;saved_left<=first_left;saved_right<=right_edge;saved_odd<=sx[0];saved_lanes<=lanes;saved_mask<=byte_mask;saved_phase<=phase;saved_two<=two;saved_last<=last_address;saved_group<=group;
    if(last_address)all_issued<=1;
    else if(two&&!phase)phase<=1;
    else begin phase<=0;
     if(fin&&channel<15)channel<=channel+1'b1;
     else if(!fin)begin
      if(kx<2)kx<=kx+1'b1;
      else begin kx<=0;if(ky<2)ky<=ky+1'b1;else begin ky<=0;group<=group+1'b1;end end
     end else begin channel<=0;group<=0;if(kx<2)kx<=kx+1'b1;else begin kx<=0;ky<=ky+1'b1;end end
    end
   end
   if(cache_mvalid&&cache_mready&&saved_two&&!saved_phase)low<=routed[255:0];
   if(m_valid&&m_ready&&m_last)begin done<=1;running<=0;end
   if(error&&running&&!cache_mvalid&&!m_valid)begin running<=0;done<=1;end
  end
 end
endmodule
