// Signed24 dot product -> symmetric INT8 raw feature. Exact round-to-even.
// Dynamic shift = input_exp + weight_exp - raw_exp, supported [-32,31].
// One elastic register: no output or configuration may change while stalled.
module p2_raw_requant(input clk,rst_n,
 input s_valid,output s_ready,input signed[23:0]s_dot,input signed[5:0]s_shift,
 output reg m_valid,input m_ready,output reg signed[7:0]m_q);
 wire[23:0]mag=s_dot[23]?-s_dot:s_dot;
 reg[31:0]scaled,q,remn,half;
 reg[5:0]right_shift;
 reg signed[7:0]next_q;
 always @*begin
 scaled=0;q=0;remn=0;half=0;right_shift=0;
 if(s_shift>=0)begin
  // Any nonzero integer shifted seven or more bits saturates INT8.
  if(s_shift>=7)scaled=mag==0?0:128;
  else scaled={8'd0,mag}<<s_shift;
 end else begin
  right_shift=-s_shift;
  if(right_shift>=25)scaled=0; // magnitude <= 2^23, including INT24_MIN
  else begin
   q={8'd0,mag}>>right_shift;
   remn={8'd0,mag}&((32'd1<<right_shift)-1'b1);
   half=32'd1<<(right_shift-1'b1);
   scaled=q+((remn>half)||((remn==half)&&q[0]));
  end
 end
 if(scaled>127)next_q=s_dot[23]?-8'sd127:8'sd127;
 else next_q=s_dot[23]?-$signed(scaled[7:0]):$signed(scaled[7:0]);
 end
 assign s_ready=!m_valid||m_ready;
 always @(posedge clk)begin
 if(!rst_n)begin m_valid<=0;m_q<=0;end
 else if(s_ready)begin m_valid<=s_valid;if(s_valid)m_q<=next_q;end
 end
endmodule
