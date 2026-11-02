// RISC-V/APB high-level command interface. All convolution/statistics/IN/
// residual/tanh arithmetic and tensor transfers run in FPGA hardware.
module p2_network_control(input clk,rst_n,input[15:0]paddr,input psel,penable,pwrite,input[31:0]pwdata,
 output reg[31:0]prdata,output pready,pslverror,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,
 input[1:0]bresp,input bvalid,output bready,output reg[31:0]completed_frames);
 localparam IDLE=0,SCLEAR=1,SREADY=2,CSTART=3,CRUN=4,PLOAD=5,PWAIT=6,KSTART=7,KRUN=8,PSTART=9,PRUN=10,FAIL=11;
 reg[3:0]state,error;reg done;reg[31:0]ib,rb,ob,sb,vb,wb,idim,odim,channels,flags,exponents;
 reg[31:0]ci_reg,shift_reg,gamma_reg,beta_reg,epslo,ephi,rawexp,layer_id;
 reg[31:0]elapsed,completed_layers;reg[3:0]expected_layer;reg pre;
 reg[7:0]coef_channel;reg[127:0]filled;
 wire access=psel&&penable;wire[9:0]idx=paddr[11:2];wire busy=state!=IDLE;
 assign pready=1;assign pslverror=access&&(paddr[1:0]!=0||(pwrite&&busy));
 wire write_ok=access&&pwrite&&!pslverror;
 wire commit=write_ok&&idx==23;
 wire launch=write_ok&&idx==2&&pwdata[0];
 wire[7:0]cin=channels[7:0],cout=channels[15:8];
 wire[31:0]pixels=odim[9:0]*odim[25:16];wire[31:0]bytes=pixels*cout;
 reg missing;integer q;
 always @*begin missing=0;for(q=0;q<128;q=q+1)if(q<cout&&!filled[q])missing=1;end
 wire engine_rst=rst_n&&state!=FAIL;
 wire conv_ready,conv_done,conv_error,tv;wire[6:0]tc;wire[127:0]td;
 wire post_ready,post_done,post_error,stats_ready;
 wire signed[26:0]sum;wire[32:0]squares;
 wire kb,kd,ke;wire signed[18:0]kc;wire signed[31:0]ko;wire[5:0]ka;
 reg[127:0]params[0:127],param_read;
 always @(posedge clk)begin
  if(commit)params[ci_reg[6:0]]<={ephi,epslo,beta_reg,gamma_reg};
  if(state==PLOAD)param_read<=params[coef_channel[6:0]];
 end
 p2_channel_stats stats(clk,engine_rst,state==SCLEAR,tv,tc,td,coef_channel[6:0],sum,squares,stats_ready);
 p2_norm_coeff coeff(clk,engine_rst,state==KSTART,pixels[18:0],sum,squares,param_read[31:0],param_read[63:32],param_read[127:64],kb,kd,ke,kc,ko,ka,);
 wire ncwe=(commit&&flags[7])||(state==KRUN&&kd&&!ke&&ka<32);
 wire[6:0]nca=commit?ci_reg[6:0]:coef_channel[6:0];
 wire[18:0]ncv=commit?19'd0:kc;wire[31:0]nco=commit?beta_reg:ko;
 wire[4:0]ncs=commit?5'd0:ka[4:0];wire[5:0]nce=commit?rawexp[5:0]:6'd0;
 wire[31:0]ca,pa,cwa,pwa;wire[7:0]cal,pal,cwal,pwal;wire cav,pav,crr,prr,cwav,pwav,cwv,pwv,cwl,pwl,cbr,pbr;
 wire[127:0]cwd,pwd;wire[15:0]cws,pws;
 wire cs=state==CSTART||state==CRUN;
 assign araddr=cs?ca:pa;assign arlen=cs?cal:pal;assign arvalid=cs?cav:pav;assign rready=cs?crr:prr;
 assign awaddr=cs?cwa:pwa;assign awlen=cs?cwal:pwal;assign awvalid=cs?cwav:pwav;
 assign wdata=cs?cwd:pwd;assign wstrb=cs?cws:pws;assign wvalid=cs?cwv:pwv;assign wlast=cs?cwl:pwl;assign bready=cs?cbr:pbr;
 p2_conv_layer conv(clk,engine_rst,state==CSTART,ib,wb,rb,idim[9:0],idim[25:16],odim[9:0],odim[25:16],cin,cout,
 flags[0],flags[1],flags[2],flags[3],commit,ci_reg[6:0],shift_reg[5:0],conv_ready,conv_done,conv_error,
 ca,cal,cav,arready&&cs,rdata,rresp,rvalid&&cs,rlast,crr,
 cwa,cwal,cwav,awready&&cs,cwd,cws,cwv,cwl,wready&&cs,bresp,bvalid&&cs,cbr,,,tv,tc,td);
 p2_post_dma post(clk,engine_rst,state==PSTART,pre?2'd2:flags[7]?2'd1:2'd0,
 pre?ib:rb,ob,sb,vb,bytes,cout,pre?flags[8]:flags[4],flags[5]&&!pre,flags[6],exponents[5:0],exponents[13:8],
 ncwe,nca,ncv,nco,ncs,nce,post_ready,post_done,post_error,
 pa,pal,pav,arready&&!cs,rdata,rresp,rvalid&&!cs,rlast,prr,
 pwa,pwal,pwav,awready&&!cs,pwd,pws,pwv,pwl,wready&&!cs,bresp,bvalid&&!cs,pbr);
 always @*begin
  prdata=0;
  case(idx)
   0:prdata=32'h50324e37;
   1:prdata={20'd0,error,state,2'd0,done,busy};
   4:prdata=ib;5:prdata=rb;6:prdata=ob;7:prdata=sb;8:prdata=vb;9:prdata=wb;
   10:prdata=idim;11:prdata=odim;12:prdata=channels;13:prdata=flags;14:prdata=exponents;
   24:prdata=elapsed;25:prdata=completed_layers;26:prdata={24'd0,coef_channel};27:prdata=completed_frames;28:prdata=layer_id;29:prdata={28'd0,expected_layer};
  endcase
 end
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;error<=0;done<=0;ib<=0;rb<=0;ob<=0;sb<=0;vb<=0;wb<=0;idim<=0;odim<=0;channels<=0;flags<=0;exponents<=0;ci_reg<=0;shift_reg<=0;gamma_reg<=0;beta_reg<=0;epslo<=0;ephi<=0;rawexp<=0;layer_id<=0;elapsed<=0;completed_layers<=0;completed_frames<=0;expected_layer<=0;pre<=0;coef_channel<=0;filled<=0;end
  else begin
   if(busy)elapsed<=elapsed+1'b1;
   if(write_ok)case(idx)
    2:if(pwdata[2])done<=0;
    4:ib<=pwdata;5:rb<=pwdata;6:ob<=pwdata;7:sb<=pwdata;8:vb<=pwdata;9:wb<=pwdata;
    10:idim<=pwdata;11:odim<=pwdata;12:channels<=pwdata;
    13:begin flags<=pwdata;filled<=0;end
    14:exponents<=pwdata;
    16:ci_reg<=pwdata;17:shift_reg<=pwdata;18:gamma_reg<=pwdata;19:beta_reg<=pwdata;20:epslo<=pwdata;21:ephi<=pwdata;22:rawexp<=pwdata;
    23:filled[ci_reg[6:0]]<=1;
    28:layer_id<=pwdata;
   endcase
   case(state)
    IDLE:if(launch)begin
     error<=0;done<=0;elapsed<=0;pre<=pwdata[1];coef_channel<=0;
     if((!pwdata[1]&&(missing||layer_id!=expected_layer||flags[7]!=(layer_id==14)))||cout==0||pixels==0||pixels>153600||bytes[3:0]!=0)begin error<=1;done<=1;end
     else if(pwdata[1])begin expected_layer<=0;state<=PSTART;end
     else state<=SCLEAR;
    end
    SCLEAR:state<=SREADY;
    SREADY:if(stats_ready&&conv_ready)state<=CSTART;
    CSTART:state<=CRUN;
    CRUN:if(conv_done)begin
     if(conv_error)begin error<=2;state<=FAIL;end
     else state<=flags[7]?PSTART:PLOAD;
    end
    PLOAD:state<=PWAIT;
    PWAIT:state<=KSTART;
    KSTART:state<=KRUN;
    KRUN:if(kd)begin
     if(ke||ka>=32)begin error<=3;state<=FAIL;end
     else if(coef_channel+1==cout)state<=PSTART;
     else begin coef_channel<=coef_channel+1'b1;state<=PLOAD;end
    end
    PSTART:state<=PRUN;
    PRUN:if(post_done)begin
     if(post_error)begin error<=4;state<=FAIL;end
     else begin
      state<=IDLE;done<=1;
      if(!pre)begin completed_layers<=completed_layers+1'b1;
       if(flags[7])begin completed_frames<=completed_frames+1'b1;expected_layer<=0;end else expected_layer<=expected_layer+1'b1;
      end
     end
    end
    FAIL:begin state<=IDLE;done<=1;end
   endcase
  end
 end
endmodule
