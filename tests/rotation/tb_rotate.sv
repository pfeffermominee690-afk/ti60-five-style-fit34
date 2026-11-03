`timescale 1ns/1ps
module tb;
 reg clk=0,pclk=0;always #5 clk=~clk;always #6.734 pclk=~pclk;
 reg rst_n=0,publish=0;
 reg[31:0] input_address=32'h1ff0,result_address=32'h101ff0,job_id=1;
 wire pending,front_valid,ack;wire[31:0]front_job,read_errors,read_frames,underflows;
 reg i_de=0,i_hs=0,i_vs=0;
 wire o_de,o_hs,o_vs;wire[23:0]o_rgb;wire[11:0]o_x,o_y;
 wire[31:0]araddr;wire[7:0]arlen;wire arvalid;wire arready;
 wire[127:0]rdata;wire[1:0]rresp=0;wire rlast,rvalid,rready;
 rgb_pair_display #(.ROTATE_180(1),.SOURCE_WIDTH(1280),.PANEL_WIDTH(320),.PANEL_HEIGHT(480),
  .ORIGINAL_PITCH(1920),.LEFT_X(0),.RIGHT_X(640),.TOP_Y(0),.SCALE_3_2(1),.SCALE_X_2(1)) dut(.*);
 reg[7:0]mem[0:4194303];
 function automatic[23:0]rgb(input integer job,pan,xx,yy);
  reg[7:0]r,g,b;
  begin r=(xx*3+yy+job*41+pan*67);g=(xx+yy*7+job*61+pan*13);b=(xx*11+yy*3+job*97+pan*103);rgb={r,g,b};end
 endfunction
 function automatic[127:0]word128(input integer address);
  integer k;begin for(k=0;k<16;k=k+1)word128[k*8+:8]=mem[address+k];end
 endfunction
 integer clock_count=0,burst_count=0,beat_count=0,boundary_count=0;
 reg active=0;reg[31:0]addr;reg[7:0]len,index;
 assign arready=!active&&(clock_count%5!=0);
 assign rvalid=active&&(clock_count%4!=0);
 assign rlast=index==len;
 assign rdata=word128(addr+index*16);
 always @(posedge clk)begin
  clock_count<=clock_count+1;
  if(arvalid&&arready)begin
   if(araddr[3:0]!=0 || arlen>31 || (araddr[11:0]+(arlen+1)*16)>4096)$fatal(1,"AXI boundary invalid %h %d",araddr,arlen);
   if((araddr[11:0]+(arlen+1)*16)==4096)boundary_count<=boundary_count+1;
   addr<=araddr;len<=arlen;index<=0;active<=1;burst_count<=burst_count+1;
  end
  if(rvalid&&rready)begin beat_count<=beat_count+1;if(rlast)active<=0;else index<=index+1'b1;end
 end
 integer pixels=0,expected_job=1;
 reg checking=0;
 reg[23:0] expected;
 integer sx,sy,pan;
 always @(posedge pclk)begin
  #1;
  if(checking&&o_de)begin
   sx=319-((o_x%640)/2);sy=((719-o_y)*2)/3;pan=o_x<640?1:0;
   expected=rgb(expected_job,pan,sx,sy);
   if(o_rgb!==expected)$fatal(1,"Pixel mismatch at %0d,%0d job%0d got%h expected%h source%0d,%0d pan%0d",o_x,o_y,expected_job,o_rgb,expected,sx,sy,pan);
   pixels=pixels+1;
  end
 end
 task automatic frame(input integer job);
  integer xx,yy;
  begin
   @(negedge pclk);checking=0;i_de=0;i_vs=1;
   repeat(5)@(negedge pclk);
   i_vs=0;repeat(3000)@(negedge pclk);
   if(front_job!=job)$fatal(1,"Bad frame publication: got%0d expected%0d",front_job,job);
   expected_job=job;checking=1;
   for(yy=0;yy<720;yy=yy+1)begin
    for(xx=0;xx<1280;xx=xx+1)begin i_de=1;@(negedge pclk);end
    i_de=0;repeat(370)@(negedge pclk);
   end
   checking=0;
  end
 endtask
 integer job,pan_init,xx,yy,base,pitch,offset;reg[23:0]v;
 initial begin
  for(job=1;job<=2;job=job+1)for(pan_init=0;pan_init<2;pan_init=pan_init+1)begin
   base=32'h1ff0+(job-1)*32'h200000+pan_init*32'h100000;pitch=pan_init?960:1920;
   for(yy=0;yy<480;yy=yy+1)for(xx=0;xx<320;xx=xx+1)begin
    v=rgb(job,pan_init,xx,yy);offset=base+yy*pitch+xx*3;
    mem[offset]=v[7:0];mem[offset+1]=v[15:8];mem[offset+2]=v[23:16];
   end
  end
  repeat(20)@(negedge clk);rst_n=1;repeat(10)@(negedge clk);publish=1;
  @(negedge clk);publish=0;
  frame(1);frame(2);frame(2);
  repeat(100)@(negedge clk);
  if(read_errors!=0||underflows!=0)$fatal(1,"Errors=%0d underflows=%0d",read_errors,underflows);
  if(read_frames!=3||pixels!=2764800||beat_count!=172800||boundary_count<1)$fatal(1,"Accounting frames%0d pix%0d beats%0d boundaries%0d",read_frames,pixels,beat_count,boundary_count);
  $display("PASS ROT180: %0d exact pixels, 3 full 1280x720 frames, 320x480 sources, 3:2 vertical + 2x horizontal, %0d AXI beats, %0d 4KB boundaries, backpressure, atomic publish, zero errors/underflows",pixels,beat_count,boundary_count);
  $finish;
 end
 initial begin
  wait(checking&&o_y==200&&o_x==100);
  @(negedge clk);input_address=32'h201ff0;result_address=32'h301ff0;job_id=2;publish=1;
  @(negedge clk);job_id=3;
  @(negedge clk);publish=0;
 end
 initial begin #100000000;$fatal(1,"Timeout");end
endmodule
