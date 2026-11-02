// Autonomous convolution layer traversal and committed RAW-feature writeback.
// Normalization/residual and whole-network control are separate stages.
module p2_conv_layer(input clk,rst_n,start,
 input[31:0]input_base,weight_base,output_base,
 input[9:0]input_width,input_height,output_width,output_height,
 input[7:0]cin,cout,input depthwise,kernel3,stride2,upsample2,
 input cfg_we,input[6:0]cfg_channel,input signed[5:0]cfg_shift,
 output ready,output reg done,error,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,
 input[1:0]bresp,input bvalid,output bready,
 output[31:0]cache_hits,cache_misses,
 output tap_valid,output[6:0]tap_channel,output[127:0]tap_data);
 localparam IDLE=0,INVALIDATE=1,LAUNCH=2,RUN=3,ABORT=4;
 reg[2:0]state;reg[31:0]ib,wb,ob,pixel,total;reg[9:0]iw,ih,ow,tx,ty;
 reg[7:0]ci,co,oc;reg dw,k3,s2,u2;
 reg[5:0]shift_mem[0:127];reg[95:0]sh;
 wire tr,td,te,sr,sd,se,mv,mr,ml;wire[127:0]md;wire[3:0]mc;
 wire fire=state==LAUNCH&&tr&&sr;
 wire engines_reset_n=rst_n&&state!=ABORT;
 assign ready=state==IDLE;
 assign tap_valid=mv&&mr&&(oc+mc<co);
 assign tap_channel=oc+mc;
 assign tap_data=md;
 integer c;
 always @*begin sh=0;for(c=0;c<16;c=c+1)if(oc+c<co)sh[c*6+:6]=shift_mem[oc+c];end
 always @(posedge clk)if(cfg_we&&ready)shift_mem[cfg_channel]<=cfg_shift;
 p2_conv_tile tile(clk,engines_reset_n,fire,state==INVALIDATE,ib,wb,iw,ih,ow,tx,ty,ci,co,oc,dw,k3,s2,u2,sh,tr,td,te,
 mv,mr,md,mc,ml,araddr,arlen,arvalid,arready,rdata,rresp,rvalid,rlast,rready,cache_hits,cache_misses);
 p2_tile_store store(clk,engines_reset_n,fire,ob+pixel*co+oc,co,sr,sd,se,mv,mr,md,mc,ml,
 awaddr,awlen,awvalid,awready,wdata,wstrb,wvalid,wlast,wready,bresp,bvalid,bready);
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;done<=0;error<=0;ib<=0;wb<=0;ob<=0;pixel<=0;total<=0;iw<=0;ih<=0;ow<=0;tx<=0;ty<=0;ci<=0;co<=0;oc<=0;dw<=0;k3<=0;s2<=0;u2<=0;end
  else begin
   done<=0;
   case(state)
    IDLE:if(start)begin
     error<=0;
     if(output_width<16||output_width[2:0]!=0||output_height==0||((output_width*output_height)&15)!=0||output_base[3:0]!=0||cin==0||cin>128||!(cout==3||(cout!=0&&cout<=128&&cout[3:0]==0))||(depthwise&&(!kernel3||cin!=cout)))begin error<=1;done<=1;end
     else begin state<=INVALIDATE;ib<=input_base;wb<=weight_base;ob<=output_base;pixel<=0;total<=output_width*output_height;
      iw<=input_width;ih<=input_height;ow<=output_width;tx<=0;ty<=0;ci<=cin;co<=cout;oc<=0;dw<=depthwise;k3<=kernel3;s2<=stride2;u2<=upsample2;
     end
    end
    INVALIDATE:state<=LAUNCH;
    LAUNCH:if(fire)state<=RUN;
    RUN:if((td&&te)||(sd&&se))begin state<=ABORT;error<=1;end
     else if(sd)begin
      if(oc+16<co)begin oc<=oc+16;state<=LAUNCH;end
      else if(pixel+16==total)begin state<=IDLE;done<=1;end
      else begin
       pixel<=pixel+16;oc<=0;state<=LAUNCH;
       if(tx+16>=ow)begin tx<=tx+16-ow;ty<=ty+1'b1;end else tx<=tx+16;
      end
     end
    ABORT:begin state<=IDLE;done<=1;end
   endcase
  end
 end
endmodule
