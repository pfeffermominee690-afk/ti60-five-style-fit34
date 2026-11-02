// Offline diagnostic adapter for the actual pointwise tile datapath.
// APB loads tiles/weights and reads results. Not the streaming layer executor.
// Separate norm/stat diagnostics reserve the existing16-lane capacity.
module p2_pointwise_probe(input clk,rst_n,input[15:0]paddr,input psel,penable,pwrite,input[31:0]pwdata,
 output reg[31:0]prdata,output pready,pslverror);
 wire access=psel&&penable;wire[9:0]idx=paddr[11:2];
 reg[127:0]feature,weights;reg[95:0]shifts;reg[7:0]cin;reg page,fp,cp;
 reg wpage,start_wpage;reg[6:0]fc,wc;reg fv,wv,inv,start,finished;
 wire feature_ready;wire ready,busy,done,error,mv,last,wr;wire[3:0]channel;wire[127:0]data;
 reg[127:0]results[0:15];
 p2_pointwise_overlap core(clk,rst_n,inv,cp,fv,fp,fc,feature,feature_ready,
  wv,wpage,wr,wc,weights,start,page,start_wpage,cin,shifts,ready,busy,done,error,mv,1'b1,data,channel,last);
 assign pready=1;assign pslverror=access&&(paddr[1:0]!=0||(pwrite&&busy));
 reg norm_run,norm_clear;wire[511:0]norm;wire[431:0]sums;wire[527:0]squares;
 genvar g;
 generate for(g=0;g<16;g=g+1)begin:capacity
  reg signed[18:0]coef;reg signed[31:0]offset;
  always @(posedge clk)begin
   if(!rst_n)begin coef<=0;offset<=0;end
   else if(access&&pwrite&&!pslverror)begin
    if(idx==208+g)coef<=pwdata[18:0];if(idx==224+g)offset<=pwdata;
   end
  end
  norm_affine n(clk,norm_run,feature[g*8+:8],coef,offset,norm[g*32+:32]);
  stat_lane s(clk,!rst_n||norm_clear,norm_run,feature[g*8+:8],sums[g*27+:27],squares[g*33+:33]);
 end endgenerate
 integer k;
 always @(posedge clk)begin
 if(!rst_n)begin wpage<=0;start_wpage<=0;feature<=0;weights<=0;shifts<=0;cin<=0;page<=0;fp<=0;cp<=0;fc<=0;wc<=0;fv<=0;wv<=0;inv<=0;start<=0;finished<=0;norm_run<=0;norm_clear<=0;end
 else begin
  fv<=0;wv<=0;inv<=0;start<=0;norm_clear<=0;
  if(done)finished<=1;
  if(mv)results[channel]<=data;
  if(access&&pwrite&&!pslverror)begin
   for(k=0;k<4;k=k+1)begin
    if(idx==k)feature[k*32+:32]<=pwdata;
    if(idx==k+4)weights[k*32+:32]<=pwdata;
   end
   for(k=0;k<3;k=k+1)if(idx==k+12)shifts[k*32+:32]<=pwdata;
   case(idx)
   8:begin fv<=1;fp<=pwdata[7];fc<=pwdata[6:0];end
   9:begin wv<=1;wc<=pwdata[6:0];wpage<=pwdata[7];end
   10:begin inv<=1;cp<=pwdata[0];end
   11:begin cin<=pwdata[7:0];page<=pwdata[8];start_wpage<=pwdata[9];end
   15:if(pwdata[0])begin start<=1;finished<=0;end
   200:begin norm_run<=pwdata[0];norm_clear<=pwdata[1];end
   endcase
  end
 end end
 always @*begin
 prdata=0;
 if(idx==16)prdata={29'd0,error,finished,busy};
 if(idx==17)prdata=32'h50573136;
 if(idx>=64&&idx<128)prdata=results[(idx-64)>>2][idx[1:0]*32+:32];
 for(integer j=0;j<16;j=j+1)begin
  if(idx==256+j)prdata=norm[j*32+:32];
  if(idx==272+j)prdata={{5{sums[j*27+26]}},sums[j*27+:27]};
  if(idx==288+j*2)prdata=squares[j*33+:32];
  if(idx==289+j*2)prdata={31'd0,squares[j*33+32]};
 end
 end
endmodule
