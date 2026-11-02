// Shared 256-MAC arithmetic datapath for PW, DW and output 3x3.
// Window gathering / tensor memory / layer scheduling are external.
// One transaction clears the accumulator, streams its dot operands, then
// drains 16 channel beats of 16 pixels. No inference-frame claim.
module p2_vector_conv(input clk,rst_n,clear,input s_valid,s_last,depthwise,
 input[127:0]pw_pixels,input[2047:0]dw_pixels,input[127:0]weights,
 input[95:0]shifts,output s_ready,
 output m_valid,input m_ready,output reg[127:0]m_data,output reg[3:0]m_channel,output m_last);
 localparam ACC=0,ISSUE=1,WAIT=2,OUT=3;
 reg[1:0]state;reg[3:0]pixel;reg[95:0]qs;
 assign s_ready=state==ACC&&!clear;
 wire[6143:0]dot;genvar o,p;
 generate for(o=0;o<8;o=o+1)begin:oc
  for(p=0;p<16;p=p+1)begin:px
   wire[7:0]a0=depthwise?dw_pixels[((2*o)*16+p)*8+:8]:pw_pixels[p*8+:8];
   wire[7:0]a1=depthwise?dw_pixels[((2*o+1)*16+p)*8+:8]:pw_pixels[p*8+:8];
   wire[47:0]d;
   dual_mac mac(clk,!rst_n||clear,s_valid&&s_ready,a0,a1,weights[2*o*8+:8],weights[(2*o+1)*8+:8],d);
   assign dot[((2*o)*16+p)*24+:24]=d[23:0];
   assign dot[((2*o+1)*16+p)*24+:24]=d[47:24];
  end
 end endgenerate
 wire qv,qr;wire[7:0]qdata;
 p2_raw_requant q(clk,rst_n,state==ISSUE,qr,$signed(dot[(m_channel*16+pixel)*24+:24]),
 $signed(qs[m_channel*6+:6]),qv,1'b1,qdata);
 assign m_valid=state==OUT;assign m_last=m_channel==15;
 always @(posedge clk)begin
  if(!rst_n)begin state<=ACC;pixel<=0;qs<=0;m_channel<=0;m_data<=0;end
  else begin
   if(clear)begin qs<=shifts;pixel<=0;m_channel<=0;state<=ACC;end
   else case(state)
    ACC:if(s_valid&&s_ready&&s_last)begin state<=ISSUE;pixel<=0;m_channel<=0;end
    ISSUE:if(qr)state<=WAIT;
    WAIT:if(qv)begin m_data[pixel*8+:8]<=qdata;if(pixel==15)state<=OUT;else begin pixel<=pixel+1'b1;state<=ISSUE;end end
    OUT:if(m_ready)begin pixel<=0;if(m_channel==15)state<=ACC;else begin m_channel<=m_channel+1'b1;state<=ISSUE;end end
   endcase
  end
 end
endmodule
