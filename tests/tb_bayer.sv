`timescale 1ns/1ps
module tb_bayer;
reg clk=0,rst=0,vs=0,hs=0,de=0;always #5 clk=~clk;
reg[15:0]top,mid,bot;wire ov,oh,od,valid;wire[10:0]x,y;wire[15:0]r,g,b;integer checked=0,bad=0;
raw_to_rgb #(.P_DEPTH(8),.LEGACY(1))dut(.i_arstn(rst),.i_pclk(clk),.i_vsync(vs),.i_hsync(hs),.i_de(de),.i_valid(de),
 .i_p_11(top),.i_p_00(mid),.i_p_01(bot),.o_vsync(ov),.o_hsync(oh),.o_de(od),.o_valid(valid),.o_x_cnt(x),.o_y_cnt(y),.o_r(r),.o_g(g),.o_b(b));
always @(negedge clk)if(valid&&od&&y>=2&&x>4&&x<27)begin
 checked++;
 if(r!==16'hf0f0||g!==16'h6464||b!==16'h1414)begin
  if(bad<4)$display("BAYER mismatch row%0d x%0d R%h G%h B%h",y,x,r,g,b);
  bad++;
 end
end
initial begin
 repeat(4)@(negedge clk);rst=1;vs=1;repeat(4)@(negedge clk);vs=0;repeat(4)@(negedge clk);
 for(integer row=0;row<10;row++)begin
  // Even: B,G; odd: G,R. Each sample's channels are multiples of four.
  top=row%2?16'h6414:16'hf064;bot=top;mid=row%2?16'hf064:16'h6414;
  de=1;hs=1;repeat(32)@(negedge clk);de=0;hs=0;repeat(10)@(negedge clk);
 end
 if(bad||checked<160)$fatal(1,"BAYER %0d/%0d interior sites incorrect",bad,checked);
 $display("PASS Bayer four-site color consistency, %0d two-pixel outputs",checked);$finish;
end
endmodule
