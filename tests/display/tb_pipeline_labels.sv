`timescale 1ns/1ps
module tb_pipeline_labels;
reg clk=0,pclk=0,rst=0;always #5 clk=~clk;always #6.734 pclk=~pclk;
reg[11:0]pa=0;reg ps=0,pe=0,pw=0;reg[31:0]pd=0;
wire ready,err,av,rr,ode;wire[31:0]aa;wire[7:0]al;wire[23:0]rgb;
reg ar=0,rv=0,rl=0;reg[127:0]rd=0;wire[31:0]uf,re,front;
video_pipeline dut(.clk(clk),.pclk(pclk),.capture_pclk(pclk),.mipi_clk(pclk),.rst_n(rst),.mipi_vs(1'b0),
 .paddr(pa),.psel(ps),.penable(pe),.pwrite(pw),.pwdata(pd),.pready(ready),.pslverror(err),.cnn_frames(32'd10),
 .i_de(1'b0),.i_hs(1'b0),.i_vs(1'b0),.i_rgb(24'b0),.o_de(ode),.o_rgb(rgb),
 .awready(1'b0),.wready(1'b0),.bresp(2'b0),.bvalid(1'b0),.araddr(aa),.arlen(al),.arvalid(av),.arready(ar),
 .rdata(rd),.rresp(2'b0),.rvalid(rv),.rlast(rl),.rready(rr),.underflows(uf),.read_errors(re),.front_job(front));
function automatic[7:0] byte_at(input integer a);byte_at=(a*37+(a>>5))&255;endfunction
reg active=0;integer addr,n,beat,delay;
always @(negedge clk) ar=$urandom_range(0,3)!=0;
always @(posedge clk)if(rst)begin
 if(av&&ar)begin if(active||rv||(aa&4095)+(al+1)*16>4096)$fatal;active<=1;addr<=aa;n<=al+1;beat<=0;delay<=2;end
 if(active&&!rv)begin if(delay)delay<=delay-1;else begin for(integer z=0;z<16;z++)rd[z*8+:8]<=byte_at(addr+beat*16+z);rv<=1;rl<=beat==n-1;end end
 if(rv&&rr)begin rv<=0;if(rl)active<=0;else begin beat<=beat+1;delay<=$urandom_range(0,3);end end
end
task write_reg(input[11:0]a,input[31:0]v);begin
 @(negedge clk);pa=a;pd=v;ps=1;pe=1;pw=1;
 @(posedge clk);if(err||!ready)$fatal(1,"APB invalid %h",a);
 @(negedge clk);ps=0;pe=0;pw=0;
end endtask
reg[11:0]x=0,y=0;
reg[11:0]x1=0,y1=0;
always @(posedge pclk)begin x1<=dut.pair_x;y1<=dut.pair_y;x<=x1;y<=y1;end
reg[127:0]gold[0:95];integer frame=0,shown=0,seen=0,checked=0,offset,py,px;reg[23:0]expected;reg ink;
always @(negedge pclk)if(rst&&ode&&dut.display.front_valid)begin
 if(x==0 && y==0)begin frame=frame+1;shown=front>>29;if(shown>=1&&shown<=5)seen=seen|(1<<(shown-1));end
 if(shown>=1&&shown<=5)begin
  py=y*2/3;px=x<640?x/2:(x-640)/2;
  offset=x<640?32'h01000000+py*1920+px*3:32'h03100000+py*960+px*3;
  expected={byte_at(offset+2),byte_at(offset+1),byte_at(offset)};
  if(x>=656&&x<912&&y>=16&&y<48)begin
   ink=gold[shown*16+(y-16)/2][127-(x-656)/2];expected=ink?24'hffffff:{2'b0,expected[23:18],2'b0,expected[15:10],2'b0,expected[7:2]};
  end else if(x>=16&&x<80&&y>=48&&y<80)begin
   ink=gold[(y-48)/2][127-(x-16)/2];expected=ink?24'hffffff:{2'b0,expected[23:18],2'b0,expected[15:10],2'b0,expected[7:2]};
  end
  if(!(x>=16&&x<100&&y>=16&&y<30))begin
   if(rgb!==expected)$fatal(1,"frame%0d style%0d x%0d y%0d actual%h expected%h",frame,shown,x,y,rgb,expected);checked++;
  end
 end
end
initial begin
 $readmemh("../tests/display/title-rows.hex",gold);
 repeat(5)@(negedge clk);rst=1;
 write_reg('h020,'h01000000);write_reg('h024,'h03100000);write_reg('h028,'h20000001);write_reg('h02c,1);
 for(integer k=1;k<5;k++)begin
  wait(frame==k && x==640 && y==200 && ode);
  write_reg('h028,((k+1)<<29)|(k+1));write_reg('h02c,1);
 end
 wait(frame>=6 && x==1279 && y==719 && ode);@(negedge pclk);
 if(uf||re||seen!=31)$fatal(1,"errors %d underflows %d seen%h",re,uf,seen);
 $display("PIPELINE_LABELS_PASS pixels=%0d all-five-style-tags, mid-frame publications, clocks/AXI stalls, edge-to-edge pixels, zero underflow",checked);$finish;
end
initial begin #200000000;$fatal(1,"timeout");end
endmodule
