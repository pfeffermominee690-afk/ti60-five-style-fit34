// Exact specialization of prior-layer IN -> INT8 exponent -2 (no ReLU/skip),
// used by layer13 in BOTH approved models. Preserves the two RNE steps when
// adjust is 0 or 1. Affine needs33 bits, not a general64-bit activation path.
module p2_norm_input_qm2(input clk,rst_n,input s_valid,output s_ready,
 input signed[7:0]raw,input signed[18:0]coefficient,input signed[31:0]offset,input[4:0]adjust,
 output m_valid,input m_ready,output reg signed[7:0]q);
 reg[1:0]valids;reg signed[32:0]aff;reg[4:0]adj;
 wire advance=!m_valid||m_ready;assign s_ready=advance;assign m_valid=valids[1];
 wire signed[26:0]product=raw*coefficient;
 // Explicit widths prevent synthesis of unrestricted integer shifters.
 reg[32:0]mag,pre_mag;reg[20:0]base;reg[21:0]rounded;
 reg[13:0]mask,half,remn;reg[3:0]right,left;reg[7:0]clipped;
 reg signed[7:0]result;
 always @*begin
  mag=aff[32]?-aff:aff;pre_mag=mag;
  if(adj==0)pre_mag=(mag>>2)+((mag[1:0]>2)||((mag[1:0]==2)&&mag[2]));
  else if(adj==1)pre_mag=(mag>>1)+(mag[0]&&mag[1]);
  base=0;rounded=0;mask=0;half=0;remn=0;right=0;left=0;clipped=0;
  if(adj<16)begin
   right=adj<2?4'd14:4'd0-adj[3:0];
   if(|pre_mag[32:21])clipped=127;
   else begin
    base=pre_mag[20:0]>>right;
    mask=14'h3fff>>(4'd14-right);half=14'd1<<(right-1'b1);remn=pre_mag[13:0]&mask;
    rounded={1'b0,base}+((remn>half)||((remn==half)&&base[0]));
    clipped=rounded>127?8'd127:{1'b0,rounded[6:0]};
   end
  end else begin
   left=adj[3:0];
   if(left>=7)clipped=pre_mag==0?0:127;
   else if(pre_mag>(33'd127>>left))clipped=127;
   else clipped={1'b0,pre_mag[6:0]}<<left;
  end
  result=aff[32]?-$signed(clipped):$signed(clipped);
 end
 always @(posedge clk)begin
  if(!rst_n)begin valids<=0;q<=0;end
  else if(advance)begin
   valids<={valids[0],s_valid};
   if(s_valid)begin aff<={{6{product[26]}},product}+{offset[31],offset};adj<=adjust;end
   if(valids[0])q<=result;
  end
 end
endmodule
