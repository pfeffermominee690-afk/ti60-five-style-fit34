// CHW burst prefetch for a128..1024-spatial PW tile. Previous-layer IN is fused
// into load; no normalized full tensor is written back to DDR.
// Eight exact norm lanes, double-page bank mapping, per-channel params.
module p2_pw_prefetch(input clk,rst_n,start,input page,
 input[31:0]source_base,plane_pixels,tile_pixel,input[7:0]channels,input[10:0]pixel_count,
 input relu,input signed[3:0]next_exp,
 input cfg_we,input[6:0]cfg_channel,input signed[18:0]cfg_coef,
 input signed[31:0]cfg_offset,input[3:0]cfg_adjust,
 output ready,output reg done,error,
 output[63:0]bank_we,output[575:0]bank_wa,output[511:0]bank_wd,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready);
 localparam IDLE=0,LOOK=1,COMMAND=2,RUN=3,ABORT=4;
 reg[2:0]state;reg[31:0]address,stride;reg[7:0]co,ch;reg[10:0]count,outpixel;reg[2:0]channel_shift;
 reg pg,rel;reg signed[3:0]ex;reg[54:0]params[0:127],p;
 reg[127:0]filled;reg bv,half,read_finished;reg[127:0]bufdata;
 wire[7:0]ns,nv;wire[63:0]nq;wire nr=&ns;
 wire dv,dr,rr,rdone,rerr;wire[127:0]data;
 wire param_valid=filled[ch[6:0]]&&p[54:51]<=10;
 wire reset_engine=rst_n&&state!=ABORT;
 assign ready=state==IDLE;
 assign dr=state==RUN&&(!bv||(nr&&half));
 always @(posedge clk)begin
  if(cfg_we&&ready)params[cfg_channel]<={cfg_adjust,cfg_offset,cfg_coef};
  if(state==LOOK)p<=params[ch[6:0]];
 end
 p2_tensor_dma dma(.clk(clk),.rst_n(reset_engine),.rd_start(state==COMMAND&&rr&&param_valid),.rd_address(address),.rd_beats({25'd0,count[10:4]}),.rd_ready(rr),.rd_done(rdone),.rd_error(rerr),
 .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rlast(rlast),.rready(rready),.m_data(data),.m_valid(dv),.m_ready(dr),
 .wr_start(1'b0),.wr_address(32'd0),.wr_beats(32'd0),.wr_ready(),.wr_done(),.wr_error(),.awaddr(),.awlen(),.awvalid(),.awready(1'b0),.s_data(128'd0),.s_valid(1'b0),.s_ready(),.wdata(),.wstrb(),.wvalid(),.wlast(),.wready(1'b0),.bresp(2'd0),.bvalid(1'b0),.bready());
 genvar g,b;
 generate for(g=0;g<8;g=g+1)begin:lanes
 p2_norm_compact norm(clk,reset_engine,bv&&state==RUN,ns[g],bufdata[(g+half*8)*8+:8],p[18:0],p[50:19],p[54:51],8'sd0,1'b0,1'b0,rel,ex,nv[g],1'b1,nq[g*8+:8]);
 end
 for(b=0;b<64;b=b+1)begin:bank
 assign bank_we[b]=state==RUN&&nv[0]&&ch[1:0]==b%4&&outpixel[3]==(b/4)/8;
 assign bank_wa[b*9+:9]={pg,8'd0}|((outpixel>>4)<<channel_shift)|(ch>>2);
 assign bank_wd[b*8+:8]=nq[((b/4)%8)*8+:8];
 end endgenerate
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;filled<=0;done<=0;error<=0;address<=0;stride<=0;co<=0;channel_shift<=0;count<=0;ch<=0;outpixel<=0;pg<=0;rel<=0;ex<=0;bv<=0;half<=0;read_finished<=0;bufdata<=0;end
  else begin done<=0;
   if(cfg_we&&ready)filled[cfg_channel]<=1;
   if(state==RUN)begin
    if(bv&&nr)begin if(half)begin bv<=0;half<=0;end else half<=1;end
    if(dv&&dr)begin bufdata<=data;bv<=1;half<=0;end
    if(rdone)read_finished<=1;
    if(nv[0])outpixel<=outpixel+8;
   end
   case(state)
    IDLE:if(start)begin
     error<=0;
     if(source_base[3:0]!=0||plane_pixels[3:0]!=0||tile_pixel[3:0]!=0||pixel_count==0||pixel_count>1024||pixel_count[3:0]!=0||!(channels==3||channels==16||channels==32||channels==64||channels==128)||(channels==128&&pixel_count>128)||(channels==64&&pixel_count>256)||(channels==32&&pixel_count>512)||tile_pixel+pixel_count>plane_pixels||next_exp< -5||next_exp> -1)begin error<=1;done<=1;end
     else begin address<=source_base+tile_pixel;stride<=plane_pixels;co<=channels;channel_shift<=channels==3?0:channels==16?2:channels==32?3:channels==64?4:5;count<=pixel_count;ch<=0;pg<=page;rel<=relu;ex<=next_exp;state<=LOOK;end
    end
    LOOK:state<=COMMAND;
    COMMAND:if(!param_valid)begin error<=1;state<=ABORT;end else if(rr)begin state<=RUN;outpixel<=0;bv<=0;half<=0;read_finished<=0;end
    RUN:if(rdone&&rerr)begin state<=ABORT;error<=1;end
     else if(read_finished&&outpixel==count&&!bv&&!nv[0])begin
      if(ch+1==co)begin done<=1;state<=IDLE;end
      else begin ch<=ch+1'b1;address<=address+stride;state<=LOOK;end
     end
    ABORT:begin state<=IDLE;done<=1;bv<=0;end
   endcase
  end
 end
endmodule
