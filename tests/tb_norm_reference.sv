`timescale 1ns/1ps
`include "tests/norm_count.vh"
module tb;
reg clk=0,rst=0;always #5 clk=~clk;
reg sv=0,mr=0;wire sr,mv;wire signed[7:0]q;
reg[85:0]v;reg[85:0]mem[0:`COUNT-1];integer sent=0,received=0,cycles=0;
p2_norm_reference_lane dut(clk,rst,sv,sr,v[85:78],v[77:59],v[58:27],v[26:23],v[22:15],v[14],v[13],v[12],v[11:8],mv,mr,q);
reg held=0;reg[7:0]held_q;
always @(posedge clk)if(rst)begin
 cycles=cycles+1;if(cycles>2000000)$fatal(1,"timeout");
 if(held&&(!mv||q!==held_q))$fatal(1,"unstable stalled result");
 held=mv&&!mr;held_q=q;
 if(sv&&sr)sent=sent+1;
 if(mv&&mr)begin if(q!==mem[received][7:0])$fatal(1,"mismatch %0d got%h expected%h vector%h",received,q,mem[received][7:0],mem[received]);received=received+1;end
end
initial begin
 $readmemh("tests/norm.hex",mem);repeat(3)@(negedge clk);rst=1;
 while(received<`COUNT)begin @(negedge clk);mr=$urandom_range(0,3)!=0;sv=sent<`COUNT&&$urandom_range(0,7)!=0;v=sent<`COUNT?mem[sent]:0;end
 $display("PASS compact norm %0d vectors, random source/receiver stalls, exact RNE and INT8 skips",received);$finish;
end
endmodule
