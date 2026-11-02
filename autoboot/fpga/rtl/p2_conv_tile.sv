// One actual convolution tile: memory requests -> cache -> windows -> DSP.
// Caller invalidates cache after modifying input/weights, only while ready.
module p2_conv_tile(input clk,rst_n,start,invalidate,
 input[31:0]input_base,weight_base,
 input[9:0]input_width,input_height,output_width,tile_x,tile_y,
 input[7:0]cin,cout,output_channel,input depthwise,kernel3,stride2,upsample2,
 input[95:0]shifts,output ready,output reg done,error,
 output m_valid,input m_ready,output[127:0]m_data,output[3:0]m_channel,output m_last,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 output[31:0]cache_hits,cache_misses);
 localparam IDLE=0,CLEAR=1,LAUNCH=2,RUN=3;
 reg[1:0]state;reg dw;reg[95:0]qs;
 // Descriptors remain stable through CLEAR/LAUNCH; window reader then latches.
 reg[31:0]ib,wb;reg[9:0]iw,ih,ow,tx,ty;reg[7:0]ci,co,oc;reg k3,s2,u2;
 wire wr,w_done,w_error,qv,qr,rv,rr,re,v,last,take,cache_ready;
 wire[31:0]address;wire[7:0]byte_data;wire[127:0]pw,weights;wire[2047:0]dp;
 assign ready=state==IDLE&&wr&&cache_ready&&!invalidate;
 p2_window_reader window_reader(clk,rst_n,state==LAUNCH,ib,wb,iw,ih,ow,tx,ty,ci,co,oc,dw,k3,s2,u2,
 wr,w_done,w_error,qv,qr,address,rv,rr,byte_data,re,v,take,last,pw,weights,dp);
 p2_read_cache cache(clk,rst_n,invalidate&&state==IDLE,cache_ready,qv,qr,address,rv,rr,byte_data,re,
 araddr,arlen,arvalid,arready,rdata,rresp,rvalid,rlast,rready,cache_hits,cache_misses);
 p2_vector_conv conv(clk,rst_n,state==CLEAR,v,last,dw,pw,dp,weights,qs,take,m_valid,m_ready,m_data,m_channel,m_last);
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;done<=0;error<=0;dw<=0;qs<=0;ib<=0;wb<=0;iw<=0;ih<=0;ow<=0;tx<=0;ty<=0;ci<=0;co<=0;oc<=0;k3<=0;s2<=0;u2<=0;end
  else begin
   done<=0;
   case(state)
    IDLE:if(start&&ready)begin
     state<=CLEAR;error<=0;dw<=depthwise;qs<=shifts;ib<=input_base;wb<=weight_base;
     iw<=input_width;ih<=input_height;ow<=output_width;tx<=tile_x;ty<=tile_y;
     ci<=cin;co<=cout;oc<=output_channel;k3<=kernel3;s2<=stride2;u2<=upsample2;
    end
    CLEAR:state<=LAUNCH;
    LAUNCH:state<=RUN;
    RUN:if(w_done&&w_error)begin state<=IDLE;done<=1;error<=1;end
     else if(m_valid&&m_ready&&m_last)begin state<=IDLE;done<=1;end
   endcase
  end
 end
endmodule
