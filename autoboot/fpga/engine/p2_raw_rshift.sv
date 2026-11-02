// Exact INT24 -> INT8 RNE for approved models: s_shift in [-9,-1].
// Values above16 magnitude bits saturate at every supported shift.
module p2_raw_rshift(input clk,rst_n,input s_valid,output s_ready,
 input signed[23:0]s_dot,input signed[5:0]s_shift,
 output reg m_valid,input m_ready,output reg signed[7:0]m_q);
 // Magnitudes >=65536 saturate for every allowed right shift. Detect that
 // before taking the absolute value, so the negator needs only 16 bits.
 wire mag_overflow=s_dot[23]?(s_dot[23:16]!=8'hff||s_dot[15:0]==0):(s_dot[23:16]!=0);
 wire[15:0]mag=s_dot[23]?-s_dot[15:0]:s_dot[15:0];
 wire[3:0]shift=-s_shift;reg[14:0]whole;reg guard,sticky;reg[15:0]rounded;reg[7:0]clip;
 always @*begin
  whole=0;guard=0;sticky=0;
  case(shift)
   1:begin whole=mag[15:1];guard=mag[0];end
   2:begin whole={1'd0,mag[15:2]};guard=mag[1];sticky=|mag[0:0];end
   3:begin whole={2'd0,mag[15:3]};guard=mag[2];sticky=|mag[1:0];end
   4:begin whole={3'd0,mag[15:4]};guard=mag[3];sticky=|mag[2:0];end
   5:begin whole={4'd0,mag[15:5]};guard=mag[4];sticky=|mag[3:0];end
   6:begin whole={5'd0,mag[15:6]};guard=mag[5];sticky=|mag[4:0];end
   7:begin whole={6'd0,mag[15:7]};guard=mag[6];sticky=|mag[5:0];end
   8:begin whole={7'd0,mag[15:8]};guard=mag[7];sticky=|mag[6:0];end
   9:begin whole={8'd0,mag[15:9]};guard=mag[8];sticky=|mag[7:0];end
  endcase
  rounded={1'd0,whole}+(guard&&(sticky||whole[0]));clip=mag_overflow||rounded>127?8'd127:rounded[7:0];
 end
 assign s_ready=!m_valid||m_ready;
 always @(posedge clk)begin
  if(!rst_n)begin m_valid<=0;m_q<=0;end
  else if(s_ready)begin m_valid<=s_valid;if(s_valid)m_q<=s_dot[23]?-$signed(clip):$signed(clip);end
 end
endmodule
