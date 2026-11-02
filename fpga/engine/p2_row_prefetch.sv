// CHW row DMA with fused normalization and optional cached INT8 residual.
// Skip pass writes reserved bank addresses 384..511; main pass fills circular rows.
module p2_row_prefetch(input clk,rst_n,start,input[1:0]row_slot,
 input final_layout,scratch,has_skip,skip_exp_m4,param_bank,
 input[31:0]source_base,plane_pixels,tile_pixel,input[7:0]channels,input[10:0]pixel_count,
 input relu,input signed[3:0]next_exp,
 input cfg_we,cfg_bank,input[6:0]cfg_channel,input signed[18:0]cfg_coef,
 input signed[31:0]cfg_offset,input[3:0]cfg_adjust,
 output ready,output reg done,error,
 output[63:0]bank_we,output[575:0]bank_wa,output[511:0]bank_wd,
 output cache_valid,input cache_ready,output[575:0]cache_address,
 input cache_mvalid,output cache_mready,input[511:0]cache_data,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready);
 localparam IDLE=0,LOOK=1,COMMAND=2,RUN=3,ABORT=4;
 reg[2:0]state;reg[31:0]address,stride;reg[7:0]co,ch;reg[10:0]count,outpixel;reg[2:0]channel_shift;
 reg[1:0]slot;reg fl,sc,hs,sk4,pbank,offset8,first_beat;reg[10:0]inpixel;reg saved_half;reg[63:0]raw_saved;reg rel;reg signed[3:0]ex;reg[54:0]params[0:255],p;
 reg[127:0]filled[0:1];reg bv,half,read_finished;reg[127:0]bufdata;
 wire[7:0]ns,nv;wire[63:0]nq;wire nr=&ns;
 wire dv,dr,rr,rdone,rerr;wire[127:0]data;
 wire param_valid=filled[pbank][ch[6:0]]&&p[54:51]<=10;
 wire reset_engine=rst_n&&state!=ABORT;
 assign ready=state==IDLE;
 wire consume=hs?(cache_valid&&cache_ready):(bv&&nr&&state==RUN);
 assign dr=state==RUN&&(!bv||(consume&&(half||inpixel+8==count)));
 assign cache_valid=hs&&bv&&state==RUN&&nr;
 assign cache_mready=nr&&state==RUN;
 wire norm_valid=hs?cache_mvalid:(bv&&state==RUN);
 wire[63:0]norm_raw=hs?raw_saved:bufdata[half*64+:64];
 function automatic[8:0]mulwidth(input[8:0]v,input[5:0]w);
 case(w)3:mulwidth=(v<<1)+v;5:mulwidth=(v<<2)+v;10:mulwidth=(v<<3)+(v<<1);20:mulwidth=(v<<4)+(v<<2);default:mulwidth=0;endcase
 endfunction
 wire[5:0]words16=(count+15)>>4,words64=(count+63)>>6;
 wire[8:0]dest=sc?9'd384+mulwidth(ch>>2,words16)+(outpixel>>4):fl?mulwidth((ch<<2)+slot,words64)+(outpixel>>6):mulwidth(((ch>>2)<<2)+slot,words16)+(outpixel>>4);

 always @(posedge clk)begin
  if(cfg_we&&ready)params[{cfg_bank,cfg_channel}]<={cfg_adjust,cfg_offset,cfg_coef};
  if(state==LOOK)p<=params[{pbank,ch[6:0]}];
 end
 p2_tensor_dma dma(.clk(clk),.rst_n(reset_engine),.rd_start(state==COMMAND&&rr&&param_valid),.rd_address({address[31:4],4'd0}),.rd_beats((count+(offset8?8:0)+15)>>4),.rd_ready(rr),.rd_done(rdone),.rd_error(rerr),
 .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rlast(rlast),.rready(rready),.m_data(data),.m_valid(dv),.m_ready(dr),
 .wr_start(1'b0),.wr_address(32'd0),.wr_beats(32'd0),.wr_ready(),.wr_done(),.wr_error(),.awaddr(),.awlen(),.awvalid(),.awready(1'b0),.s_data(128'd0),.s_valid(1'b0),.s_ready(),.wdata(),.wstrb(),.wvalid(),.wlast(),.wready(1'b0),.bresp(2'd0),.bvalid(1'b0),.bready());
 genvar g,b;
 generate for(g=0;g<8;g=g+1)begin:lanes
 wire[7:0]skip=cache_data[((g+saved_half*8)*4+ch[1:0])*8+:8];
 p2_norm_compact norm(clk,reset_engine,norm_valid,ns[g],norm_raw[g*8+:8],p[18:0],p[50:19],p[54:51],skip,sk4,hs,rel,ex,nv[g],1'b1,nq[g*8+:8]);
 end
 for(b=0;b<64;b=b+1)begin:bank
 assign cache_address[b*9+:9]=9'd384+mulwidth(ch>>2,words16)+(inpixel>>4);
 assign bank_we[b]=state==RUN&&nv[0]&&((fl&&!sc)?(b/8==outpixel[5:3]):(ch[1:0]==b%4&&outpixel[3]==(b/4)/8));
 assign bank_wa[b*9+:9]=dest;
 assign bank_wd[b*8+:8]=nq[((fl&&!sc)?b%8:(b/4)%8)*8+:8];
 end endgenerate
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;filled[0]<=0;filled[1]<=0;done<=0;error<=0;address<=0;stride<=0;co<=0;channel_shift<=0;count<=0;ch<=0;outpixel<=0;slot<=0;fl<=0;sc<=0;hs<=0;sk4<=0;pbank<=0;offset8<=0;first_beat<=0;inpixel<=0;saved_half<=0;raw_saved<=0;rel<=0;ex<=0;bv<=0;half<=0;read_finished<=0;bufdata<=0;end
  else begin done<=0;
   if(cfg_we&&ready)filled[cfg_bank][cfg_channel]<=1;
   if(state==RUN)begin
    if(consume)begin
     if(hs)begin raw_saved<=bufdata[half*64+:64];saved_half<=inpixel[3];end
     inpixel<=inpixel+8;
     if(half||inpixel+8==count)begin bv<=0;half<=0;end else half<=1;
    end
    if(dv&&dr)begin bufdata<=data;bv<=1;half<=first_beat&&offset8;first_beat<=0;end
    if(rdone)read_finished<=1;
    if(nv[0])outpixel<=outpixel+8;
   end
   case(state)
    IDLE:if(start)begin
     error<=0;
     if(source_base[3:0]!=0||plane_pixels[3:0]!=0||tile_pixel[2:0]!=0||!(pixel_count==40||pixel_count==80||pixel_count==160||pixel_count==320)||!(channels==3||channels==16||channels==32||channels==64||channels==128)||tile_pixel+pixel_count>plane_pixels||next_exp< -5||next_exp> -1||(final_layout&&(pixel_count!=320||channels!=16||scratch||has_skip))||(scratch&&has_skip))begin error<=1;done<=1;end
     else begin address<=source_base+tile_pixel;stride<=plane_pixels;co<=channels;channel_shift<=channels==3?0:channels==16?2:channels==32?3:channels==64?4:5;count<=pixel_count;ch<=0;slot<=row_slot;fl<=final_layout;sc<=scratch;hs<=has_skip;sk4<=skip_exp_m4;pbank<=param_bank;offset8<=tile_pixel[3];rel<=relu;ex<=next_exp;state<=LOOK;end
    end
    LOOK:state<=COMMAND;
    COMMAND:if(!param_valid)begin error<=1;state<=ABORT;end else if(rr)begin state<=RUN;outpixel<=0;inpixel<=0;first_beat<=1;bv<=0;half<=0;read_finished<=0;end
    RUN:if(rdone&&rerr)begin state<=ABORT;error<=1;end
     else if(read_finished&&outpixel==count&&!bv&&!nv[0]&&!cache_mvalid)begin
      if(ch+1==co)begin done<=1;state<=IDLE;end
      else begin ch<=ch+1'b1;address<=address+stride;state<=LOOK;end
     end
    ABORT:begin state<=IDLE;done<=1;bv<=0;end
   endcase
  end
 end
endmodule
