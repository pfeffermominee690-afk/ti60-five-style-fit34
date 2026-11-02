// Final raw INT8 dequantization + Q16 bias + Q8-indexed tanh LUT.
module p2_output_pixel #(parameter LUT_FILE="p2_tanh.hex")(
 input clk,rst_n,input s_valid,output s_ready,input signed[7:0]raw,
 input signed[5:0]raw_exp,input signed[31:0]bias_q16,
 output reg m_valid,input m_ready,output reg[7:0]pixel);
 reg[7:0]lut[0:4096];initial $readmemh(LUT_FILE,lut);
 function automatic signed[63:0]rne(input signed[63:0]v,input integer sh);
 reg[63:0]mag,q,remn,half;integer n;
 begin
  mag=v<0?-v:v;n=-sh;
  if(sh>=0)rne=v<<<sh;
  else begin q=mag>>n;remn=mag&((64'd1<<n)-1);half=64'd1<<(n-1);q=q+((remn>half)||((remn==half)&&q[0]));rne=v<0?-$signed(q):$signed(q);end
 end endfunction
 reg signed[63:0]a,index;
 always @*begin a=rne({{56{raw[7]}},raw},$signed(raw_exp)+16)+bias_q16;index=rne(a,-8);end
 assign s_ready=!m_valid||m_ready;
 always @(posedge clk)begin
  if(!rst_n)begin m_valid<=0;pixel<=0;end
  else if(s_ready)begin m_valid<=s_valid;if(s_valid)pixel<=lut[index< -2048?0:index>2048?4096:index+2048];end
 end
endmodule
