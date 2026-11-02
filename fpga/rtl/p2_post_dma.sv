// Actual DDR-backed post-processing. Configurable normalization lanes; INT32 residual
// reads and saved activations are explicit DMA transfers. Mode1: final tanh;
// mode2: BGR8 -> first-layer INT8 (exp=-6). Mode0: IN/residual/activation.
module p2_post_dma #(parameter LANES=1)(input clk,rst_n,start,input[1:0]mode,
 input[31:0]input_base,output_base,skip_base,save_base,byte_count,
 input[7:0]channels,input has_skip,save_skip,relu,input signed[5:0]relu_exp,next_exp,
 input cfg_we,input[6:0]cfg_channel,input signed[18:0]cfg_coef,input signed[31:0]cfg_offset,
 input[4:0]cfg_adjust,input signed[5:0]cfg_exp,
 output ready,output reg done,error,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,
 input[1:0]bresp,input bvalid,output bready);
 localparam IDLE=0,RSTART=1,RWAIT=2,SSTART=3,SWAIT=4,LOOK=5,ISSUE=6,NWAIT=7,
 WSTART=8,WWAIT=9,SAVESTART=10,SAVEWAIT=11,NEXT=12,PRE=13;
 reg[3:0]state;reg[1:0]job_mode,read_word,write_word;reg[3:0]group_index;
 reg[3:0]pixel_index;reg[31:0]ib,ob,sb,vb,total,index,source_extra;reg[5:0]crop_beat;
 reg[7:0]co,channel_base;reg hs,ss,rel;reg signed[5:0]re,ne;
 reg[127:0]raw,qbuf;reg[511:0]skip,acts;
 wire rd_ready,rd_done,rd_error,wr_ready,wr_done,wr_error,dmv,dms;
 wire[127:0]dmdata;wire rd_start=(state==RSTART||state==SSTART)&&rd_ready;
 wire wr_start=(state==WSTART||state==SAVESTART)&&wr_ready;
 wire[31:0]ra=state==SSTART?sb+(index<<2):ib+index+((job_mode==2&&hs)?source_extra:0);
 wire[31:0]wa=state==SAVESTART?vb+(index<<2):ob+index;
 wire saving=state==SAVEWAIT;
 p2_tensor_dma dma(clk,rst_n,rd_start,ra,state==SSTART?32'd4:32'd1,rd_ready,rd_done,rd_error,
 araddr,arlen,arvalid,arready,rdata,rresp,rvalid,rlast,rready,dmdata,dmv,1'b1,
 wr_start,wa,state==SAVESTART?32'd4:32'd1,wr_ready,wr_done,wr_error,
 awaddr,awlen,awvalid,awready,saving?acts[write_word*128+:128]:qbuf,
 state==WWAIT||state==SAVEWAIT,dms,wdata,wstrb,wvalid,wlast,wready,bresp,bvalid,bready);
 wire[LANES-1:0]nr,nv;wire[LANES*8-1:0]nq;wire[LANES*48-1:0]na;wire[LANES*62-1:0]coeff;
 genvar g;
 generate for(g=0;g<LANES;g=g+1)begin:lane
  reg[61:0]params[0:127],p;
  wire[9:0]channel_sum=channel_base+(job_mode==1?pixel_index:group_index*LANES+g);
  wire[6:0]channel_index=co==3?channel_sum%3:channel_sum&(co-1'b1);
  always @(posedge clk)begin
   if(cfg_we&&ready)params[cfg_channel]<={cfg_exp,cfg_adjust,cfg_offset,cfg_coef};
   if(state==LOOK)p<=params[channel_index];
  end
  assign coeff[g*62+:62]=p;
  p2_norm_residual norm(clk,rst_n,state==ISSUE&&job_mode==0,nr[g],raw[(group_index*LANES+g)*8+:8],p[18:0],p[50:19],p[55:51],
   skip[(group_index*LANES+g)*32+:32],hs,rel,re,ne,nv[g],1'b1,nq[g*8+:8],na[g*48+:48]);
 end endgenerate
 wire os,ov;wire[7:0]outpixel;
 p2_output_pixel outunit(clk,rst_n,state==ISSUE&&job_mode==1,os,raw[pixel_index*8+:8],coeff[61:56],coeff[50:19],ov,1'b1,outpixel);
 function automatic[7:0]preprocess(input[7:0]p);
  integer v,a,q;begin v=(p*2-255)*64;a=v<0?-v:v;q=(a+127)/255;preprocess=v<0?-q:q;end
 endfunction
 assign ready=state==IDLE;
 integer z;
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;done<=0;error<=0;job_mode<=0;group_index<=0;read_word<=0;write_word<=0;pixel_index<=0;ib<=0;ob<=0;sb<=0;vb<=0;total<=0;index<=0;source_extra<=0;crop_beat<=0;co<=0;channel_base<=0;hs<=0;ss<=0;rel<=0;re<=0;ne<=0;raw<=0;qbuf<=0;skip<=0;acts<=0;end
  else begin
   done<=0;
   if(dmv)begin
    if(state==RWAIT)raw<=dmdata;
    if(state==SWAIT)begin skip[read_word*128+:128]<=dmdata;read_word<=read_word+1'b1;end
   end
   if(dms&&saving)write_word<=write_word+1'b1;
   case(state)
    IDLE:if(start)begin
     error<=0;
     if(byte_count==0||byte_count[3:0]!=0||(|{input_base[3:0],output_base[3:0],skip_base[3:0],save_base[3:0]})||mode==3||!(channels==3||channels==16||channels==32||channels==64||channels==128)||(mode==1&&(has_skip||save_skip))||(mode==2&&save_skip))begin done<=1;error<=1;end
     else begin state<=RSTART;job_mode<=mode;ib<=input_base;ob<=output_base;sb<=skip_base;vb<=save_base;total<=byte_count;index<=0;source_extra<=0;crop_beat<=0;channel_base<=0;co<=channels;hs<=has_skip;ss<=save_skip;rel<=relu;re<=relu_exp;ne<=next_exp;end
    end
    RSTART:if(rd_ready)begin read_word<=0;state<=RWAIT;end
    RWAIT:if(rd_done)begin
     if(rd_error)begin done<=1;error<=1;state<=IDLE;end
     else begin group_index<=0;pixel_index<=0;state<=job_mode==2?PRE:hs?SSTART:LOOK;end
    end
    SSTART:if(rd_ready)begin read_word<=0;state<=SWAIT;end
    SWAIT:if(rd_done)begin
     if(rd_error)begin done<=1;error<=1;state<=IDLE;end else state<=LOOK;
    end
    LOOK:state<=ISSUE;
    ISSUE:if(job_mode==1?os:&nr)state<=NWAIT;
    NWAIT:if(job_mode==1?ov:nv[0])begin
     if(job_mode==1)begin
      qbuf[pixel_index*8+:8]<=outpixel;
      if(pixel_index==15)state<=WSTART;else begin pixel_index<=pixel_index+1'b1;state<=LOOK;end
     end else begin
      for(z=0;z<LANES;z=z+1)begin
       qbuf[(group_index*LANES+z)*8+:8]<=nq[z*8+:8];acts[(group_index*LANES+z)*32+:32]<=na[z*48+:32];
       if(ss&&na[z*48+32+:16]!={16{na[z*48+31]}})error<=1;
      end
      if(group_index==16/LANES-1)state<=WSTART;else begin group_index<=group_index+1'b1;state<=LOOK;end
     end
    end
    PRE:begin for(z=0;z<16;z=z+1)qbuf[z*8+:8]<=preprocess(raw[z*8+:8]);state<=WSTART;end
    WSTART:if(wr_ready)state<=WWAIT;
    WWAIT:if(wr_done)begin
     if(wr_error||error)begin state<=IDLE;done<=1;error<=1;end
     else state<=ss?SAVESTART:NEXT;
    end
    SAVESTART:if(wr_ready)begin write_word<=0;state<=SAVEWAIT;end
    SAVEWAIT:if(wr_done)begin
     if(wr_error)begin state<=IDLE;done<=1;error<=1;end else state<=NEXT;
    end
    NEXT:if(index+16==total)begin state<=IDLE;done<=1;end
     else begin
      index<=index+16;channel_base<=co==3?(channel_base+16)%3:(channel_base+16)&(co-1'b1);state<=RSTART;
      if(job_mode==2&&hs)begin
       if(crop_beat==59)begin crop_beat<=0;source_extra<=source_extra+960;end else crop_beat<=crop_beat+1'b1;
      end
     end
   endcase
  end
 end
endmodule
