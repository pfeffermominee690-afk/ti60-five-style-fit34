// Exact integer-reference normalization -> optional residual -> optional
// ReLU and activation quantization -> next convolution input quantization.
// skip_q16 is reconstructed with its ORIGINAL layer's normalization params.
// All metadata advances with the pixel; stalls freeze the complete pipeline.
module p2_norm_residual(input clk,rst_n,
 input s_valid,output s_ready,input signed[7:0]s_raw,input signed[18:0]s_coef,
 input signed[31:0]s_offset,input[4:0]s_adjust,input signed[31:0]s_skip_q16,
 input s_has_skip,s_relu,input signed[5:0]s_relu_exp,s_next_exp,
 output m_valid,input m_ready,output reg signed[7:0]m_q,
 output reg signed[47:0]m_activation_q16);
 function automatic signed[63:0]shift_rne(input signed[63:0]v,input integer sh);
  reg[63:0]mag,q,remn,half;
  integer n;
  begin
   mag=v[63]?-v:v;q=0;remn=0;half=0;n=-sh;
   if(sh>=0)shift_rne=v<<<sh;
   else begin
    if(n>=64)q=0;
    else begin q=mag>>n;remn=mag&((64'd1<<n)-1'b1);half=64'd1<<(n-1);
     q=q+((remn>half)||((remn==half)&&q[0]));end
    shift_rne=v[63]?-$signed(q):$signed(q);
   end
  end
 endfunction
 function automatic signed[7:0]quant8(input signed[63:0]v,input integer exp);
  reg signed[63:0]q;
  begin q=shift_rne(v,-16-exp);quant8=q>127?8'sd127:q< -127?-8'sd127:q[7:0];end
 endfunction
 wire advance=!m_valid||m_ready;assign s_ready=advance;
 reg[3:0]valids;assign m_valid=valids[3];
 wire signed[26:0]product=s_raw*s_coef;
 reg signed[63:0]aff1,a2,a3;
 reg[4:0]adj1;reg signed[31:0]skip1;reg has1,relu1,relu2;
 reg signed[5:0]re1,re2,ne1,ne2,ne3;
 reg signed[63:0]clamped;reg signed[7:0]rq;
 always @*begin
  clamped=relu2&&a2<0?64'sd0:a2;
  rq=quant8(clamped,$signed(re2));
 end
 always @(posedge clk)begin
  if(!rst_n)begin valids<=0;m_q<=0;m_activation_q16<=0;end
  else if(advance)begin
   valids<={valids[2:0],s_valid};
   if(s_valid)begin
    aff1<={{37{product[26]}},product}+{{32{s_offset[31]}},s_offset};
    adj1<=s_adjust;skip1<=s_skip_q16;has1<=s_has_skip;relu1<=s_relu;re1<=s_relu_exp;ne1<=s_next_exp;
   end
   if(valids[0])begin
    a2<=shift_rne(aff1,$signed({1'b0,adj1})-2)+(has1?{{32{skip1[31]}},skip1}:64'd0);
    relu2<=relu1;re2<=re1;ne2<=ne1;
   end
   if(valids[1])begin
    a3<=relu2?shift_rne({{56{rq[7]}},rq},$signed(re2)+16):a2;ne3<=ne2;
   end
   if(valids[2])begin m_q<=quant8(a3,$signed(ne3));m_activation_q16<=a3[47:0];end
  end
 end
endmodule
