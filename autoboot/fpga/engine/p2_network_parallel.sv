// APB launches layers; all convolution, normalization coefficients, residuals and DDR traversal are hardware.
// RAW encoder outputs stay in caller-selected DDR regions; saved coefficient banks reconstruct skips.
module p2_network_parallel(input clk,rst_n,input[15:0]paddr,input psel,penable,pwrite,input[31:0]pwdata,
 output reg[31:0]prdata,output pready,pslverror,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,input[1:0]bresp,input bvalid,output bready,
 output reg[31:0]completed_frames);
 localparam IDLE=0,INIT=1,LAUNCH=2,RUN=3,READ=4,WAITREAD=5,KSTART=6,KRUN=7,KSAVE=8,ADVANCE=9,FINISH=10,PRESTART=11,PRERUN=12;
 reg[3:0]state,error;reg done;reg[31:0]ib,sb,ob,wb,idim,odim,channels,flags,exponents,layer_id;
 reg[31:0]param_channel,shift_value,gamma_value,beta_value,epslo,epshi,lut_address;
 reg[31:0]elapsed,layer_elapsed;reg[3:0]expected_layer;reg[6:0]channel;
 reg[31:0]params[0:511],param_q;reg[127:0]param_read;reg[7:0]filled;reg[1:0]param_word;
 wire access=psel&&penable;wire[9:0]index=paddr[11:2];wire busy=state!=IDLE;
 assign pready=1;assign pslverror=access&&(paddr[1:0]!=0||(pwrite&&busy));
 wire wr=access&&pwrite&&!pslverror,commit=wr&&index==23,launch=wr&&index==2&&pwdata[0];
 wire missing=filled<channels[15:8];
 wire pre_mode=state==PRESTART||state==PRERUN;
 wire pre_ready,pre_done,pre_error,iv,ir,ip,ic,ps,pp,psr,psd,pse;wire[3:0]ich,ig;wire[63:0]idata;wire[31:0]pb,ppx;wire[7:0]pc;
 wire[31:0]na,pa;wire[7:0]nl,pl;wire nv,pv,nr,pr;
 assign araddr=pre_mode?pa:na;assign arlen=pre_mode?pl:nl;assign arvalid=pre_mode?pv:nv;assign rready=pre_mode?pr:nr;
 p2_camera_input preprocessor(clk,rst_n,state==PRESTART,flags[12],ib,ob,pre_ready,pre_done,pre_error,iv,ir,ip,ic,ich,ig,idata,ps,pp,pb,ppx,pc,psr,psd,pse,
 pa,pl,pv,arready&&pre_mode,rdata,rresp,rvalid&&pre_mode,rlast,pr);
 wire lr,ld;wire[3:0]le;wire[31:0]lc;wire signed[26:0]sum;wire[32:0]square;
 wire kb,kd,ke;wire signed[18:0]kc;wire signed[31:0]ko;wire[5:0]ka;
 wire norm_write=state==INIT||(state==KRUN&&kd&&!ke&&ka<=10)||state==KSAVE;
 wire[1:0]norm_bank=state==KSAVE?flags[10:9]:2'd0;
 wire[31:0]pixels=(odim[25:16]<<5)+(odim[25:16]<<3);
 wire[31:0]np=odim[9:0]==40?pixels:odim[9:0]==80?pixels<<1:odim[9:0]==160?pixels<<2:odim[9:0]==320?pixels<<3:0;
 always @(posedge clk)begin
  if(wr&&index>=18&&index<=21)params[{param_channel[6:0],2'(index-18)}]<=pwdata;
  if(state==READ)param_q<=params[{channel,param_word}];
 end
 p2_norm_coeff coeff(clk,rst_n,state==KSTART,np[18:0],sum,square,param_read[31:0],param_read[63:32],param_read[127:64],kb,kd,ke,kc,ko,ka,);
 p2_layer_parallel layer(clk,rst_n,state==LAUNCH,pre_mode,iv,ir,ip,ic,ich,ig,idata,ps,pp,pb,ppx,pc,psr,psd,pse,flags[1:0],flags[2],flags[3],ib,sb,wb,ob,
 idim[9:0],idim[25:16],odim[9:0],odim[25:16],channels[7:0],channels[15:8],flags[4],flags[8:7],flags[5],flags[6],exponents[3:0],exponents[7:4],
 norm_write,norm_bank,channel,state==INIT?19'sd8192:kc,state==INIT?32'sd0:ko,state==INIT?4'd0:ka[3:0],
 commit,param_channel[6:0],shift_value[5:0],wr&&index==34,lut_address[9:0],pwdata[7:0],channel,sum,square,lr,ld,le,lc,
 na,nl,nv,arready&&!pre_mode,rdata,rresp,rvalid&&!pre_mode,rlast,nr,awaddr,awlen,awvalid,awready,wdata,wstrb,wvalid,wlast,wready,bresp,bvalid,bready);
 always @*begin
  prdata=0;case(index)
   0:prdata=32'h50324e38;
   1:prdata={20'd0,error,state,2'd0,done,busy};
   4:prdata=ib;5:prdata=sb;6:prdata=ob;7:prdata=wb;8:prdata=idim;9:prdata=odim;10:prdata=channels;11:prdata=flags;12:prdata=exponents;13:prdata=layer_id;
   24:prdata=elapsed;25:prdata=layer_elapsed;26:prdata={25'd0,channel};27:prdata=completed_frames;28:prdata={28'd0,expected_layer};
  endcase
 end
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;param_word<=0;param_read<=0;error<=0;done<=0;ib<=0;sb<=0;ob<=0;wb<=0;idim<=0;odim<=0;channels<=0;flags<=0;exponents<=0;layer_id<=0;param_channel<=0;shift_value<=0;gamma_value<=0;beta_value<=0;epslo<=0;epshi<=0;lut_address<=0;elapsed<=0;layer_elapsed<=0;expected_layer<=0;channel<=0;filled<=0;completed_frames<=0;end
  else begin
   if(busy)elapsed<=elapsed+1'b1;
   if(wr)case(index)
    2:if(pwdata[2])done<=0;
    // Reserved register bits read as zero; retain only the actual ABI fields.
    4:ib<=pwdata;5:sb<=pwdata;6:ob<=pwdata;7:wb<=pwdata;8:idim<=pwdata&32'h03ff03ff;9:odim<=pwdata&32'h03ff03ff;10:channels<=pwdata&32'h0000ffff;
    11:begin flags<=pwdata&32'h00001fff;filled<=0;end
    12:exponents<=pwdata&32'h000000ff;13:layer_id<=pwdata&32'h0000000f;
    16:param_channel<=pwdata&32'h0000007f;17:shift_value<=pwdata&32'h0000003f;18:gamma_value<=pwdata;19:beta_value<=pwdata;20:epslo<=pwdata;21:epshi<=pwdata;
    23:if(param_channel==filled)filled<=filled+1'b1;
    33:lut_address<=pwdata;34:lut_address<=lut_address+1'b1;
   endcase
   case(state)
    IDLE:if(launch)begin
     error<=0;done<=0;elapsed<=0;channel<=0;
     if(pwdata[1])begin expected_layer<=0;state<=PRESTART;end
     else if(missing||layer_id!=expected_layer||channels[15:8]==0||channels[15:8]>128||((flags[1:0]==2)!=(layer_id==14)))begin error<=1;done<=1;end
     else state<=layer_id==0?INIT:LAUNCH;
    end
    PRESTART:if(pre_ready)state<=PRERUN;
    PRERUN:if(pre_done)begin done<=1;state<=IDLE;if(pre_error)error<=7;end
    INIT:if(channel==2)begin channel<=0;state<=LAUNCH;end else channel<=channel+1'b1;
    LAUNCH:if(lr)state<=RUN;
    RUN:if(ld)begin layer_elapsed<=lc;if(le)begin error<=le;done<=1;state<=IDLE;end else begin param_word<=0;state<=layer_id==14?FINISH:READ;end end
    READ:state<=WAITREAD;
    WAITREAD:begin param_read[param_word*32+:32]<=param_q;if(param_word==3)state<=KSTART;else begin param_word<=param_word+1'b1;state<=READ;end end
    KSTART:state<=KRUN;
    KRUN:if(kd)begin
     if(ke||ka>10)begin error<=6;done<=1;state<=IDLE;end
     else state<=flags[10:9]!=0?KSAVE:ADVANCE;
    end
    KSAVE:state<=ADVANCE;
    ADVANCE:if(channel+1==channels[15:8])state<=FINISH;else begin channel<=channel+1'b1;param_word<=0;state<=READ;end
    FINISH:begin done<=1;state<=IDLE;if(layer_id==14)begin completed_frames<=completed_frames+1'b1;expected_layer<=0;end else expected_layer<=expected_layer+1'b1;end
   endcase
  end
 end
endmodule

