`timescale 1ns/1ps
module tb_osd;
reg clk=0,pclk=0,rst=0,ps=0,pe=0,pw=0,de=0,hs=0,vs=0;always #5 clk=~clk;always #6.734 pclk=~pclk;
reg[11:0]a,x=0,y=0;reg[31:0]data;wire[31:0]q;wire err,ode,oh,ov;wire[23:0]rgb;
capture_osd dut(clk,pclk,rst,ps,pe,pw,a,data,q,err,x,y,de,hs,vs,24'h80a0c0,ode,oh,ov,rgb);
reg[7:0]font[0:2047];initial $readmemh("capture-font.hex",font);
reg[11:0]xx[0:2],yy[0:2];integer checked=0,inkcount=0;reg checking=0,full_panel;
always @(posedge pclk)begin xx[0]<=x;yy[0]<=y;for(integer z=1;z<3;z++)begin xx[z]<=xx[z-1];yy[z]<=yy[z-1];end end
integer pos,ch,row,col;reg ink;reg[23:0]expected;
always @(negedge pclk)if(checking&&ode)begin
 expected=24'h80a0c0;
 if(xx[2]>=16&&xx[2]<(full_panel?1040:528)&&yy[2]>=16&&yy[2]<(full_panel?272:48))begin
  pos=((yy[2]-16)/32)*64+(xx[2]-16)/16;ch=32+pos%95;row=((yy[2]-16)/2)%16;col=((xx[2]-16)/2)%8;
  ink=font[ch*16+row][7-col];expected=ink?24'hffffff:24'h202830;if(ink)inkcount++;
 end
 if(rgb!==expected)$fatal(1,"OSD pixel %0d %0d got%h expected%h",xx[2],yy[2],rgb,expected);
 checked++;
end
task wr(input[11:0]addr,input[31:0]v);
 @(negedge clk);a=addr;data=v;ps=1;pw=1;pe=0;@(negedge clk);pe=1;#1;if(err)$fatal;
 @(negedge clk);ps=0;pw=0;pe=0;
endtask
reg[31:0]word;
initial begin
 full_panel=$test$plusargs("FULL");
 repeat(10)@(negedge clk);rst=1;
 for(integer k=0;k<128;k++)begin for(integer j=0;j<4;j++)word[j*8+:8]=32+(k*4+j)%95;wr('h400+k*4,word);end
 wr('h3fc,full_panel?3:1);repeat(10)@(negedge pclk);vs=1;repeat(10)@(negedge pclk);vs=0;
 checking=1;
 for(integer iy=0;iy<300;iy++)begin
  for(integer ix=0;ix<1280;ix++)begin @(negedge pclk);x=ix;y=iy;de=1;end
  @(negedge pclk);de=0;repeat(10)@(negedge pclk);
 end
 repeat(5)@(negedge pclk);
 if(checked!=384000||inkcount<500)$fatal(1,"OSD coverage %0d %0d",checked,inkcount);
 $display("PASS OSD %0d exact pixels, %0d font pixels, inactive text bank committed at VS",checked,inkcount);$finish;
end
endmodule
