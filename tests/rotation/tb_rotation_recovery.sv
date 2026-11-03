`timescale 1ns/1ps
module tb;
 reg clk=0,pclk=0;always #5 clk=~clk;always #6.734 pclk=~pclk;
 reg rst_n=0,publish=0;
 reg[31:0] input_address=32'h1ff0,result_address=32'h101ff0,job_id=1;
 wire pending,front_valid,ack;wire[31:0]front_job,read_errors,read_frames,underflows;
 reg i_de=0,i_hs=0,i_vs=0;
 wire o_de,o_hs,o_vs;wire[23:0]o_rgb;wire[11:0]o_x,o_y;
 wire[31:0]araddr;wire[7:0]arlen;wire arvalid;wire arready;
 wire[127:0]rdata;wire[1:0]rresp;wire rlast,rvalid,rready;
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
 integer fault_kind=0,fault_id=0,fault_seen=0,burst_fault=0;
 integer abort_rr=0,abort_cp=0;
 assign rresp=(burst_fault==1&&index==3)?2'b10:2'b00;
 assign rlast=burst_fault==2?(index==3):burst_fault==3?(index==len+2):(index==len);
 always @(posedge clk)if(rst_n&&dut.rot180.frame_sync[1]!=dut.rot180.frame_seen)begin
  if(dut.rot180.rs==2)abort_rr<=abort_rr+1;
  if(dut.rot180.rs==4)abort_cp<=abort_cp+1;
 end
 assign rdata=word128(addr+index*16);
 always @(posedge clk)begin
  clock_count<=clock_count+1;
  if(arvalid&&arready)begin
   if(araddr[3:0]!=0 || arlen>31 || (araddr[11:0]+(arlen+1)*16)>4096)$fatal(1,"AXI boundary invalid %h %d",araddr,arlen);
   if((araddr[11:0]+(arlen+1)*16)==4096)boundary_count<=boundary_count+1;
   if(fault_id!=fault_seen&&arlen>20)begin burst_fault<=fault_kind;fault_seen<=fault_id;end
   else burst_fault<=0;
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
 task automatic pulse_vs;
  begin
   @(negedge pclk);checking=0;i_de=0;i_vs=1;
   repeat(5)@(negedge pclk);i_vs=0;
  end
 endtask
 task automatic interrupt_frame(input integer state);
  integer xx,yy;reg found;
  begin
   pulse_vs();repeat(3000)@(negedge pclk);found=0;
   for(yy=0;yy<350&&!found;yy=yy+1)begin
    for(xx=0;xx<1280&&!found;xx=xx+1)begin
     i_de=1;@(negedge pclk);
     if(yy>=200&&dut.rot180.rs==state&&
        ((state==2&&dut.rot180.burst>=24&&dut.rot180.beat==2)||
         (state==4&&!dut.rot180.fq_ready)))found=1;
    end
    i_de=0;if(!found)repeat(370)@(negedge pclk);
   end
   if(!found)$fatal(1,"Could not interrupt state %d",state);
   pulse_vs();repeat(3000)@(negedge pclk);
   frame(1);
  end
 endtask
 task automatic inject_fault(input integer kind,errors);
  begin
   fault_kind=kind;fault_id=fault_id+1;
   pulse_vs();
   wait(read_errors==errors);
   wait(!active);repeat(100)@(negedge clk);
   if(dut.rot180.rs!=0)$fatal(1,"Did not drain faulty transaction kind%0d",kind);
   frame(1);
   if(read_errors!=errors)$fatal(1,"Wrong error count kind%0d: %0d",kind,read_errors);
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
  interrupt_frame(4);interrupt_frame(2);
  if(abort_rr<1||abort_cp<1)$fatal(1,"Abort coverage RR%0d CP%0d",abort_rr,abort_cp);
  if(read_errors!=0)$fatal(1,"False errors after clean frame interrupts");
  inject_fault(1,1);inject_fault(2,2);inject_fault(3,3);
  repeat(100)@(negedge clk);
  if(read_errors!=3||underflows!=0)$fatal(1,"Errors=%0d underflows=%0d",read_errors,underflows);
  if(pixels!=4608000)$fatal(1,"Accounting pixels%0d",pixels);
  $display("PASS RECOVERY: %0d exact recovered pixels; mid-frame VS abort RR=%0d CP=%0d; SLVERR, early RLAST, late RLAST each counted once; no hang or underflow",pixels,abort_rr,abort_cp);
  $finish;
 end
 initial begin #200000000;$fatal(1,"Timeout");end
endmodule
