module dual_mac(input clk,input rst,input ce,input signed [7:0] a0,a1,b0,b1,output [47:0] result);
 EFX_DSP48 #(.MODE("DUAL"),.SIGNED(1),.N_SEL("W"),.W_REG(1),.O_REG(0),.RST_SYNC(1)) mac(
 .A({{3{a1[7]}},a1,a0}),.B({{2{b1[7]}},b1,b0}),.C(18'd0),.CASCIN(48'd0),.OP(2'b00),.SHIFT_ENA(1'b0),.CLK(clk),.CE(ce),.RST(rst),.O(result),.CASCOUT(),.OVFL());
endmodule
module p2_mac_bank(input clk,input rst,input ce,input [2047:0] a,b,output [6143:0] result);
 genvar g;generate for(g=0;g<128;g=g+1)begin:lanes
 dual_mac u(clk,rst,ce,a[g*16+:8],a[g*16+8+:8],b[g*16+:8],b[g*16+8+:8],result[g*48+:48]);
 end endgenerate
endmodule



