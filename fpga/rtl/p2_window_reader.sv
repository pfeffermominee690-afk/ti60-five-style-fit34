// Hardware operand gathering for one 16-pixel x 16-channel convolution tile.
// Byte request/response port connects to p2_read_cache, not a host window API.
// Latched descriptors. Symmetric padding and nearest-neighbour upsampling.
// Serial gather baseline: correctness first; NOT a 15fps implementation.
module p2_window_reader(
 input clk,rst_n,start, input[31:0]input_base,weight_base,
 input[9:0]input_width,input_height,output_width,tile_x,tile_y,
 input[7:0]cin,cout,output_channel,
 input depthwise,kernel3,stride2,upsample2,
 output ready, output reg done,error,
 output req_valid,input req_ready,output reg[31:0]req_address,
 input rsp_valid,output rsp_ready,input[7:0]rsp_data,input rsp_error,
 output valid,input take,output last,
 output reg[127:0]pw_pixels,weights,output reg[2047:0]dw_pixels);
 localparam IDLE=0,WREQ=1,WRESP=2,PREQ=3,PRESP=4,EMIT=5;
 reg[2:0]state;
 reg[31:0]ib,wb;reg[9:0]iw,ih,ow,tx,ty,x,y;
 reg[7:0]ci,co,oc,ch;reg dw,k3,s2,u2;
 reg[1:0]ky,kx;reg[4:0]lane,pixel;
 reg signed[12:0]sy,sx,ey,ex;
 reg[31:0]source_channel;
 // Network dimensions are fixed. Shift/add address arithmetic preserves DSPs
 // for convolution instead of synthesizing generic address multipliers.
 function automatic[31:0]width_product(input[31:0]v,input[9:0]width);
  case(width)
   16:width_product=v<<4;
   32:width_product=v<<5;
   64:width_product=v<<6;
   128:width_product=v<<7;
   40:width_product=(v<<5)+(v<<3);
   80:width_product=(v<<6)+(v<<4);
   160:width_product=(v<<7)+(v<<5);
   320:width_product=(v<<8)+(v<<6);
   default:width_product=0;
  endcase
 endfunction
 function automatic[31:0]channel_product(input[31:0]v,input[7:0]channels);
  case(channels)
   3:channel_product=(v<<1)+v;
   16:channel_product=v<<4;
   32:channel_product=v<<5;
   64:channel_product=v<<6;
   128:channel_product=v<<7;
   default:channel_product=0;
  endcase
 endfunction
 assign ready=state==IDLE;
 assign req_valid=(state==WREQ||state==PREQ)&&((state==WREQ||dw)?oc+lane<co:1'b1);
 assign rsp_ready=state==WRESP||state==PRESP;
 assign valid=state==EMIT;
 assign last=(ky==(k3?2:0))&&(kx==(k3?2:0))&&(dw||ch==ci-1);
 always @* begin
  ey=ih << u2;ex=iw << u2;
  sy=(y << s2)+ky-(k3?1:0);sx=(x << s2)+kx-(k3?1:0);
  if(sy<0)sy=-sy-1;else if(sy>=ey)sy=2*ey-1-sy;
  if(sx<0)sx=-sx-1;else if(sx>=ex)sx=2*ex-1-sx;
  source_channel=dw?oc+lane:ch;
  req_address=ib+channel_product(width_product(sy >>> u2,iw)+(sx >>> u2),ci)+source_channel;
  if(state==WREQ||state==WRESP)
   req_address=wb+(dw?(channel_product(ky*3+kx,ci)+oc+lane):(channel_product(channel_product(ky*(k3?3:1)+kx,ci)+ch,co)+oc+lane));
 end
 task advance_pixel;
  begin
   if(pixel==15)begin
    pixel<=0;x<=tx;y<=ty;
    if(dw&&lane!=15)begin lane<=lane+1'b1;state<=PREQ;end
    else state<=EMIT;
   end else begin
    pixel<=pixel+1'b1;
    if(x==ow-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
    state<=PREQ;
   end
  end
 endtask
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;done<=0;error<=0;pw_pixels<=0;dw_pixels<=0;weights<=0;
   ib<=0;wb<=0;iw<=0;ih<=0;ow<=0;tx<=0;ty<=0;x<=0;y<=0;ci<=0;co<=0;oc<=0;ch<=0;dw<=0;k3<=0;s2<=0;u2<=0;ky<=0;kx<=0;lane<=0;pixel<=0;end
  else begin
   done<=0;
   case(state)
    IDLE:if(start)begin
     error<=0;
     if(!(input_width==16||input_width==32||input_width==64||input_width==128||input_width==40||input_width==80||input_width==160||input_width==320)||input_height==0||output_width==0||!(cin==3||cin==16||cin==32||cin==64||cin==128)||!(cout==3||cout==16||cout==32||cout==64||cout==128)||output_channel>=cout||tile_x>=output_width||(depthwise&&(!kernel3||cin!=cout)))begin done<=1;error<=1;end
     else begin
      ib<=input_base;wb<=weight_base;iw<=input_width;ih<=input_height;ow<=output_width;tx<=tile_x;ty<=tile_y;x<=tile_x;y<=tile_y;
      ci<=cin;co<=cout;oc<=output_channel;dw<=depthwise;k3<=kernel3;s2<=stride2;u2<=upsample2;
      ch<=0;ky<=0;kx<=0;lane<=0;pixel<=0;weights<=0;pw_pixels<=0;dw_pixels<=0;state<=WREQ;
     end
    end
    WREQ:if(oc+lane>=co)begin
     weights[lane*8+:8]<=0;
     if(lane==15)begin lane<=0;state<=PREQ;end else lane<=lane+1'b1;
    end else if(req_ready)state<=WRESP;
    WRESP:if(rsp_valid)begin
     if(rsp_error)begin state<=IDLE;error<=1;done<=1;end
     else begin weights[lane*8+:8]<=rsp_data;
      if(lane==15)begin lane<=0;state<=PREQ;end else begin lane<=lane+1'b1;state<=WREQ;end
     end
    end
    PREQ:if(dw&&oc+lane>=co)begin dw_pixels[(lane*16+pixel)*8+:8]<=0;advance_pixel();end
     else if(req_ready)state<=PRESP;
    PRESP:if(rsp_valid)begin
     if(rsp_error)begin state<=IDLE;error<=1;done<=1;end
     else begin
      if(dw)dw_pixels[(lane*16+pixel)*8+:8]<=rsp_data;else pw_pixels[pixel*8+:8]<=rsp_data;
      advance_pixel();
     end
    end
    EMIT:if(take)begin
     if(last)begin state<=IDLE;done<=1;end
     else begin
      if(!dw&&ch!=ci-1)ch<=ch+1'b1;
      else begin ch<=0;if(kx==(k3?2:0))begin kx<=0;ky<=ky+1'b1;end else kx<=kx+1'b1;end
      lane<=0;pixel<=0;x<=tx;y<=ty;state<=WREQ;
     end
    end
    default:begin state<=IDLE;done<=1;error<=1;end
   endcase
  end
 end
endmodule
