`timescale 1ns/1ps
module tb_capture;
 reg clk=0,capclk=0,pclk=0,rst=0;
 always #5 clk=~clk;always #3.367 capclk=~capclk;always #6.734 pclk=~pclk;
 reg[11:0]pa=0;reg ps=0,pe=0,pw=0;reg[31:0]pd=0;wire[31:0]pr;wire pready,perror;
 wire de,hs,vs;wire[11:0]sx,sy;
 // 148.5MHz / 2200 / 2250 = 30Hz input, independent 720p60 HDMI.
 vga_gen #(.H_SyncPulse(44),.H_BackPorch(148),.H_ActivePix(1920),.H_FrontPorch(88),
 .V_SyncPulse(5),.V_BackPorch(36),.V_ActivePix(1080),.V_FrontPorch(1129)) source(
 .in_pclk(capclk),.in_rstn(rst),.out_x(sx),.out_y(sy),.out_valid(),.out_de(de),.out_hs(hs),.out_vs(vs));
 reg vs_d=0;reg[7:0]fid=0;
 always @(posedge capclk)begin vs_d<=vs;if(vs&&!vs_d)fid<=fid+1;end
 wire[31:0]aa,ra,frames,rf,uf,re,job,fps,markers;wire[7:0]al,rl;
 wire av,wv,wl,br,rv_ar,rr,ode,oh,ov;wire[127:0]wd;wire[15:0]st;wire[23:0]rgb;
 reg awready=0,wready=0,bvalid=0,arready=0,rvalid=0,rlast=0;reg[127:0]rd=0;
 capture_pipeline dut(.clk(clk),.pclk(pclk),.capture_pclk(capclk),.mipi_clk(capclk),.rst_n(rst),.mipi_vs(vs),.mipi_de(de&&sx[1:0]==0),
 .paddr(pa),.psel(ps),.penable(pe),.pwrite(pw),.pwdata(pd),.prdata(pr),.pready(pready),.pslverror(perror),
 .cnn_frames(32'd0),.raw_drops(32'd0),.i_de(de),.i_hs(hs),.i_vs(vs),.i_rgb({fid,sy[7:0],sx[7:0]}),
 .o_de(ode),.o_hs(oh),.o_vs(ov),.o_rgb(rgb),.awaddr(aa),.awlen(al),.awvalid(av),.awready(awready),
 .wdata(wd),.wstrb(st),.wvalid(wv),.wlast(wl),.wready(wready),.bresp(2'd0),.bvalid(bvalid),.bready(br),
 .araddr(ra),.arlen(rl),.arvalid(rv_ar),.arready(arready),.rdata(rd),.rresp(2'd0),.rvalid(rvalid),.rlast(rlast),.rready(rr),
 .capture_frames(frames),.read_frames(rf),.underflows(uf),.read_errors(re),.front_job(job),.measured_fps(fps),.mipi_markers(markers));
 reg[7:0]mem[0:3145727];integer wp=0,wn=0,wi=0,bd=0,rp=0,rn=0,ri=0,delay=0;
 reg writing=0,reading=0;integer totalbytes=0,checked=0,checkedframes=0;
 reg[127:0]expected_hash=0;integer n,px,py,ox,oy,byteidx;reg[7:0]expectbyte;reg line_test;
 function automatic integer gray_at(input integer x,y,input integer frame);
  gray_at=(((240+(x/4)*9+(x%4)*2)&255)+2*(((y/4)*9+(y%4)*2)&255)+frame)/4;
 endfunction
 function automatic [7:0] ink_at(input integer x,y,input integer frame);
  integer gx,gy,m,d,k;
  begin
   gx=gray_at(x,y-2,frame)+2*gray_at(x,y-1,frame)+gray_at(x,y,frame)-gray_at(x-2,y-2,frame)-2*gray_at(x-2,y-1,frame)-gray_at(x-2,y,frame);
   gy=gray_at(x-2,y,frame)+2*gray_at(x-1,y,frame)+gray_at(x,y,frame)-gray_at(x-2,y-2,frame)-2*gray_at(x-1,y-2,frame)-gray_at(x,y-2,frame);
   m=(gx<0?-gx:gx)+(gy<0?-gy:gy);
   d=m>12?m-12:0;k=d<=16?2*d:32+6*(d-16);
   ink_at=(x<2||y<2)?255:k>=255?0:255-k;
  end
 endfunction
 always @(negedge clk)begin awready=!writing&&!bvalid&&!bd&&($urandom_range(0,3)!=0);wready=writing&&($urandom_range(0,3)!=0);arready=!reading&&!rvalid&&($urandom_range(0,3)!=0);end
 always @(posedge clk)if(rst)begin
  if(av&&awready)begin writing<=1;wp<=aa-32'h01000000;wn<=al+1;wi<=0;if((aa&4095)+(al+1)*16>4096)$fatal(1,"write page");end
  if(wv&&wready)begin
   for(integer z=0;z<16;z++)begin
    byteidx=(wp+wi*16+z)%1048576;n=byteidx/3;px=n%640;py=n/640;
    ox=240+(px/4)*9+(px%4)*2;oy=(py/4)*9+(py%4)*2;
    expectbyte=line_test?ink_at(px,py,fid):byteidx%3==0?ox[7:0]:byteidx%3==1?oy[7:0]:fid;
    if(wd[z*8+:8]!==expectbyte)$fatal(1,"resize byte %0d got %h expected %h sx%0d sy%0d",byteidx,wd[z*8+:8],expectbyte,sx,sy);
    mem[wp+wi*16+z]<=wd[z*8+:8];
   end
   expected_hash<={expected_hash[126:0],1'b0}^(expected_hash[127]?128'h87:128'd0)^wd;totalbytes<=totalbytes+16;
   if(wl!=(wi==wn-1)||st!=65535)$fatal(1,"write protocol");
   if(wl)begin writing<=0;bd<=5;end else wi<=wi+1;
  end
  if(bd>0)begin bd<=bd-1;if(bd==1)bvalid<=1;end
  if(bvalid&&br)bvalid<=0;
  if(rv_ar&&arready)begin reading<=1;rp<=ra-32'h01000000;rn<=rl+1;ri<=0;delay<=2;end
  if(reading&&!rvalid)begin
   if(delay)delay<=delay-1;
   else begin for(integer z=0;z<16;z++)rd[z*8+:8]<=mem[rp+ri*16+z];rvalid<=1;rlast<=ri==rn-1;end
  end
  if(rvalid&&rr)begin rvalid<=0;if(rlast)reading<=0;else begin ri<=ri+1;delay<=$urandom_range(0,3);end end
 end
 // Check un-overlaid HDMI pixels against the exact immutable source buffer.
 reg[11:0]xx[0:2],yy[0:2];reg[31:0]base_q[0:2];reg valid_q[0:2];
 always @(posedge pclk)begin
  xx[0]<=dut.x;yy[0]<=dut.y;base_q[0]<=dut.display.front_input;valid_q[0]<=dut.front_valid;
  for(integer z=1;z<3;z++)begin xx[z]<=xx[z-1];yy[z]<=yy[z-1];base_q[z]<=base_q[z-1];valid_q[z]<=valid_q[z-1];end
 end
 integer off;
 always @(negedge pclk)if(rst&&ode&&valid_q[2])begin
  off=base_q[2]-32'h01000000+(yy[2]*2/3)*1920+(xx[2]/2)*3;
  if(rgb!=={mem[off+2],mem[off+1],mem[off]})$fatal(1,"HDMI mismatch x%0d y%0d rgb%h",xx[2],yy[2],rgb);
  checked++;
 end
 task write_reg(input[11:0]a,input[31:0]v);
  @(negedge clk);pa=a;pd=v;ps=1;pw=1;pe=0;
  @(negedge clk);pe=1;#1;if(perror)$fatal(1,"APB write %h",a);@(posedge clk);
  @(negedge clk);ps=0;pe=0;pw=0;
 endtask
 initial begin
  repeat(10)@(negedge clk);rst=1;
  line_test=$test$plusargs("LINE");if(line_test)write_reg(12'h0c0,268);
  write_reg(12'h00c,32'h01000000);write_reg(12'h004,3);
  for(integer f=0;f<4;f++)begin
   wait(dut.done);@(negedge clk);
   if(dut.capture_error||dut.hash!==expected_hash||totalbytes!=(f+1)*921600)$fatal(1,"completion/hash");
   checkedframes++;
   write_reg('h00c,32'h01000000+((f+1)%3)*1048576);write_reg('h004,3);expected_hash=0;
   write_reg('h020,32'h01000000+(f%3)*1048576);write_reg('h024,32'h01000000+(f%3)*1048576+960);write_reg('h028,f+1);write_reg('h02c,1);
  end
  if(uf||re||dut.idle_drops||checked<2000000)$fatal(1,"counters uf%0d re%0d drops%0d pixels%0d",uf,re,dut.idle_drops,checked);
  $display("PASS mode=%0d 4 complete 640x480 frames at 30Hz input, %0d exact resize/Sobel bytes, %0d immutable HDMI pixels, delayed DDR responses, no drops",line_test,totalbytes,checked);$finish;
 end
 initial begin #200000000;$fatal(1,"timeout");end
endmodule
