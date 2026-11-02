module norm_affine(input clk,input ce,input signed[7:0] q,input signed[18:0] coefficient,input signed[31:0] offset,output reg signed[31:0] result);
 // Coefficients and offsets are channel-specific; scalar statistics engine supplies them.
 wire signed[26:0] product=q*coefficient;
 always @(posedge clk) if(ce) result <= product + offset;
endmodule
module stat_lane(input clk,input rst,input ce,input signed[7:0] q,output reg signed[26:0] sum,output reg[32:0] sumsq);
 wire signed[15:0] square=q*q;
 always @(posedge clk) begin
 if(rst)begin sum<=0;sumsq<=0;end
 else if(ce)begin sum<=sum+q;sumsq<=sumsq+{17'd0,square};end
 end
endmodule
module p2_arithmetic(input clk,input rst,input ce,input[2047:0] a,b,input[127:0] q,input[303:0] coefficient,input[511:0] offset,output[6143:0] mac,output[511:0] norm,output[431:0] sum,output[527:0] sumsq);
 p2_mac_bank bank(clk,rst,ce,a,b,mac);
 genvar g;generate for(g=0;g<16;g=g+1)begin:lanes
 norm_affine n(clk,ce,q[g*8+:8],coefficient[g*19+:19],offset[g*32+:32],norm[g*32+:32]);
 stat_lane s(clk,rst,ce,q[g*8+:8],sum[g*27+:27],sumsq[g*33+:33]);
 end endgenerate
endmodule

