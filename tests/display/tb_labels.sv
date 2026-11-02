`timescale 1ns/1ps
module tb_labels;
reg clk=0;always #5 clk=~clk;
reg rst=0,start=0,de=0;reg[11:0]x=0,y=0;reg[2:0]style=0;
wire od,oh,ov;wire[23:0]rgb;
reg[127:0]gold[0:95];integer checked=0;
fps_osd dut(.clk(clk),.rst_n(rst),.frame_start(start),.x(x),.y(y),.de(de),.hs(1'b0),.vs(1'b0),
 .rgb(24'h808080),.fps_bcd(12'h027),.fps_valid(1'b1),.style_id(style),.out_de(od),.out_hs(oh),.out_vs(ov),.out_rgb(rgb));
task pixel(input integer xx,input integer yy,input [23:0]expected);
 begin @(negedge clk);x=xx;y=yy;de=1;@(posedge clk);@(posedge clk);#1;
 if(rgb!==expected || !od)$fatal(1,"x%0d y%0d got%h expected%h",xx,yy,rgb,expected);checked++;
 end
endtask
task check_label(input integer id);
 reg ink;begin
 for(integer yy=0;yy<32;yy++)for(integer xx=0;xx<256;xx++)begin
  ink=gold[id*16+yy/2][127-xx/2];pixel(656+xx,16+yy,ink?24'hffffff:24'h202020);
 end
 end
endtask
initial begin
 $readmemh("../tests/display/title-rows.hex",gold);
 repeat(3)@(negedge clk);rst=1;start=1;@(negedge clk);start=0;
 for(integer k=1;k<=5;k++)begin
  style=k;pixel(0,0,24'h808080);check_label(k);
  // A request arriving mid-frame must NOT change the currently shown name.
  style=k==5?1:k+1;check_label(k);
 end
 for(integer yy=0;yy<32;yy++)for(integer xx=0;xx<64;xx++)
  pixel(16+xx,48+yy,gold[yy/2][127-xx/2]?24'hffffff:24'h202020);
 pixel(640,200,24'h808080);pixel(1279,719,24'h808080);
 style=0;pixel(0,0,24'h808080);pixel(656,16,24'h808080);
 $display("LABEL_PASS %0d pixels; five names, original label, frame-atomic changes, invalid style blank",checked);$finish;
end
endmodule
