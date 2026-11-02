// Offline APB configuration for the actual Cout16 layer executor.
// Completed counts layers, never advertises complete CNN frames.
module p2_layer_control(input clk,rst_n,input[15:0]paddr,input psel,penable,pwrite,input[31:0]pwdata,
 output reg[31:0]prdata,output pready,pslverror,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,
 input[1:0]bresp,input bvalid,output bready);
 wire access=psel&&penable;wire[9:0]idx=paddr[11:2];wire ready,busy,done,error,weight_ready;
 reg[31:0]ib,ob,tiles,completed;reg[7:0]cin;reg wp,relu;
 reg signed[5:0]re,ne;reg[95:0]shifts;reg[127:0]weight;
 reg signed[18:0]coef;reg signed[31:0]offset;reg[4:0]adjust;
 reg start,cwe,wwe,wwp;reg[6:0]ca,wa;
 assign pready=1;assign pslverror=access&&(paddr[1:0]!=0||(pwrite&&busy));
 p2_pw16_layer #(.COMPACT_NORM(1),.HALF_RATE(1)) layer(clk,rst_n,start,ib,ob,tiles,cin,wp,shifts,relu,re,ne,cwe,ca,coef,offset,adjust,
  wwe,wwp,wa,weight,weight_ready,ready,busy,done,error,
  araddr,arlen,arvalid,arready,rdata,rresp,rvalid,rlast,rready,
  awaddr,awlen,awvalid,awready,wdata,wstrb,wvalid,wlast,wready,bresp,bvalid,bready);
 integer k;
 always @(posedge clk)begin
  if(!rst_n)begin ib<=0;ob<=0;tiles<=0;cin<=0;wp<=0;relu<=0;re<=0;ne<=0;shifts<=0;weight<=0;
   coef<=0;offset<=0;adjust<=0;start<=0;cwe<=0;wwe<=0;wwp<=0;ca<=0;wa<=0;completed<=0;end
  else begin
   start<=0;cwe<=0;wwe<=0;
   if(done&&!error)completed<=completed+1'b1;
   if(access&&pwrite&&!pslverror)begin
    for(k=0;k<4;k=k+1)if(idx==16+k)weight[k*32+:32]<=pwdata;
    for(k=0;k<3;k=k+1)if(idx==8+k)shifts[k*32+:32]<=pwdata;
    case(idx)
     0:if(ready)start<=pwdata[0];
     1:ib<=pwdata;2:ob<=pwdata;3:tiles<=pwdata;
     4:begin cin<=pwdata[7:0];wp<=pwdata[8];relu<=pwdata[9];end
     5:begin re<=pwdata[5:0];ne<=pwdata[13:8];end
     20:begin if(weight_ready)begin wwe<=1;wa<=pwdata[6:0];wwp<=pwdata[7];end end
     24:coef<=pwdata[18:0];25:offset<=pwdata;26:adjust<=pwdata[4:0];
     27:begin cwe<=1;ca<=pwdata[6:0];end
    endcase
   end
  end
 end
 always @*begin
  prdata=0;
  case(idx)
   0:prdata={29'd0,error,ready,busy};1:prdata=ib;2:prdata=ob;3:prdata=tiles;
   30:prdata=completed;31:prdata=32'h4c595231;
  endcase
 end
endmodule
