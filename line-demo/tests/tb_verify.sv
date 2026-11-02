`timescale 1ns/1ps
module tb_verify;
 reg clk=0,rst=0,ps=0,pe=0,pw=0;always #5 clk=~clk;
 reg[11:0]pa;reg[31:0]pd;wire[31:0]pr,aa;wire ready,err,av,rr;wire[7:0]al;
 reg ar=0,rv=0,rl=0;reg[127:0]rd;reg[1:0]resp=0;
 capture_verifier #(.BEATS(32))dut(clk,rst,pa,ps,pe,pw,pd,pr,ready,err,aa,al,av,ar,rd,resp,rl,rv,rr);
 reg[127:0]mem[0:31];reg[127:0]hash=0;reg active=0,corrupt=0,badresp=0;
 integer offset,beat,delay;
 always @(negedge clk)ar=!active&&!rv&&$urandom_range(0,3)!=0;
 always @(posedge clk)if(rst)begin
  if(av&&ar)begin active<=1;offset<=(aa-32'h01000000)/16;beat<=0;delay<=3;end
  if(active&&!rv)begin
   if(delay)delay<=delay-1;
   else begin rv<=1;rd<=mem[offset+beat]^((corrupt&&offset+beat==23)?128'd1:128'd0);rl<=beat==15;resp<=badresp?2:0;end
  end
  if(rv&&rr)begin rv<=0;if(rl)active<=0;else begin beat<=beat+1;delay<=$urandom_range(0,4);end end
 end
 task wr(input[11:0]a,input[31:0]v);
  @(negedge clk);ps=1;pw=1;pe=0;pa=a;pd=v;
  @(negedge clk);pe=1;#1;if(err)$fatal;@(negedge clk);ps=0;pe=0;pw=0;
 endtask
 initial begin
  for(integer k=0;k<32;k++)begin mem[k]={$urandom,$urandom,$urandom,$urandom};hash={hash[126:0],1'b0}^(hash[127]?128'h87:128'd0)^mem[k];end
  repeat(4)@(negedge clk);rst=1;
  wr(8,32'h01000000);for(integer k=0;k<4;k++)wr(16+k*4,hash[k*32+:32]);
  wr(4,1);wait(dut.done);if(dut.errors||dut.frames!=1||dut.bytes!=512)$fatal(1,"valid readback rejected");
  corrupt=1;wr(4,1);wait(dut.done);if(!(dut.errors&2)||dut.frames!=1)$fatal(1,"corruption missed");
  corrupt=0;badresp=1;wr(4,1);wait(dut.done);if(!(dut.errors&1)||dut.frames!=1)$fatal(1,"AXI error missed");
  badresp=0;wr(8,32'h01000010);wr(4,1);wait(dut.done);if(dut.errors!=8)$fatal(1,"bad base accepted");
  $display("PASS full-frame readback, exact fingerprint, corrupt byte rejection, AXI error, address guard");$finish;
 end
 initial begin #1000000;$fatal(1,"timeout");end
endmodule
