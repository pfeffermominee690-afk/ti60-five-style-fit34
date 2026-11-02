// Capacity-only array with static lane decoding. No completed inference frames.
module p2_fabric_probe(input clk,input rst_n,input[15:0]paddr,input psel,penable,pwrite,input[31:0]pwdata,output reg[31:0]prdata,output pready,output pslverror);
 wire[2047:0]a,b;reg run,clear;
 wire[6143:0]mac;wire[511:0]norm;wire[431:0]sum;wire[527:0]sumsq;
 p2_arithmetic core(clk,!rst_n||clear,run,a,b,a[127:0],b[303:0],b[1023:512],mac,norm,sum,sumsq);
 wire access=psel&&penable;wire[9:0]idx=paddr[11:2];
 assign pready=1;assign pslverror=access&&paddr[1:0]!=0;
 genvar g;generate for(g=0;g<128;g=g+1)begin:lanes
 reg[15:0]av,bv;
 always @(posedge clk)begin
 if(!rst_n)begin av<=0;bv<=0;end
 else if(access&&pwrite)begin
 if(idx==g)av<=pwdata[15:0];if(idx==g+128)bv<=pwdata[15:0];
 end end
 assign a[g*16+:16]=av;assign b[g*16+:16]=bv;
 end endgenerate
 always @(posedge clk)begin
 if(!rst_n)begin run<=0;clear<=1;end
 else begin clear<=0;if(access&&pwrite&&idx==511)begin run<=pwdata[0];clear<=pwdata[1];end end
 end
 integer k;
 always @*begin
 prdata=0;
 if(idx==511)prdata={30'd0,clear,run};
 for(k=0;k<128;k=k+1)begin
 if(idx==512+k*2)prdata={8'd0,mac[k*48+:24]};
 if(idx==513+k*2)prdata={8'd0,mac[k*48+24+:24]};
 end
 for(k=0;k<16;k=k+1)begin
 if(idx==832+k)prdata=norm[k*32+:32];
 if(idx==848+k)prdata={{5{sum[k*27+26]}},sum[k*27+:27]};
 if(idx==864+k*2)prdata=sumsq[k*33+:32];
 if(idx==865+k*2)prdata={31'd0,sumsq[k*33+32]};
 end end
endmodule
