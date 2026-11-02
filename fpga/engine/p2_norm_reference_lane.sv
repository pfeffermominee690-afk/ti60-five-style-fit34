// Alternate exact lane: full-width affine arithmetic, logic multiplier.
// Same three-cycle elastic latency as compact lanes; no numerical approximation.
// Exact normalization for the two approved models. Contract: adjust<=10,
// next exponent in [-5,-1]; ReLU exponent equals next exponent whenever used.
// Residual INT8 values use original encoder exponent -3 or -4, NOT next_exp.
// Five fixed rounding positions replace unrestricted 64-bit shift networks.
module p2_norm_reference_lane(input clk,rst_n,input s_valid,output s_ready,
 input signed[7:0]raw,input signed[18:0]coefficient,input signed[31:0]offset,
 input[3:0]adjust,input signed[7:0]skip_q,input skip_exp_m4,has_skip,relu,
 input signed[3:0]next_exp,output m_valid,input m_ready,output reg signed[7:0]q);
 reg[2:0]valids;wire advance=!m_valid||m_ready;
 assign s_ready=advance;assign m_valid=valids[2];
 (* syn_use_dsp="no" *) wire signed[26:0]product=raw*coefficient;
 reg signed[32:0]aff;reg[3:0]adj;reg signed[7:0]sk;
 reg sk4,hs,rel1,rel2;reg signed[3:0]ex1,ex2;
 reg signed[41:0]act;
 reg[32:0]mag,rounded;reg signed[41:0]normalized,residual;
 always @*begin
  mag=aff[32]?-aff:aff;rounded=mag;
  if(adj==0)rounded=(mag>>2)+((mag[1:0]>2)||((mag[1:0]==2)&&mag[2]));
  else if(adj==1)rounded=(mag>>1)+(mag[0]&&mag[1]);
  normalized=$signed({9'd0,rounded});
  if(adj>=2)normalized=normalized<<(adj-4'd2);
  if(aff[32])normalized=-normalized;
  residual=sk4?$signed({{22{sk[7]}},sk,12'd0}):$signed({{21{sk[7]}},sk,13'd0});
 end
 reg[41:0]am;reg[10:0]integer_part;reg guard,sticky;reg[11:0]rounded_q;reg[7:0]clipped;
 always @*begin
  am=act[41]?-act:act;integer_part=0;guard=0;sticky=0;
  case(ex2)
   -5:begin integer_part=am[21:11];guard=am[10];sticky=|am[9:0];end
   -4:begin integer_part={1'd0,am[21:12]};guard=am[11];sticky=|am[10:0];end
   -3:begin integer_part={2'd0,am[21:13]};guard=am[12];sticky=|am[11:0];end
   -2:begin integer_part={3'd0,am[21:14]};guard=am[13];sticky=|am[12:0];end
   -1:begin integer_part={4'd0,am[21:15]};guard=am[14];sticky=|am[13:0];end
   default:begin integer_part=0;guard=0;sticky=0;end
  endcase
  rounded_q={1'd0,integer_part}+(guard&&(sticky||integer_part[0]));
  clipped=(|am[41:22])||rounded_q>127?8'd127:rounded_q[7:0];
 end
 always @(posedge clk)begin
  if(!rst_n)begin valids<=0;q<=0;end
  else if(advance)begin
   valids<={valids[1:0],s_valid};
   if(s_valid)begin aff<={{6{product[26]}},product}+{offset[31],offset};adj<=adjust;sk<=skip_q;sk4<=skip_exp_m4;hs<=has_skip;rel1<=relu;ex1<=next_exp;end
   if(valids[0])begin act<=normalized+(hs?residual:42'sd0);rel2<=rel1;ex2<=ex1;end
   if(valids[1])q<=rel2&&act[41]?8'sd0:act[41]?-$signed(clipped):$signed(clipped);
  end
 end
endmodule
