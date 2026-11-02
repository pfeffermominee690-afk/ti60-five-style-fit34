// Autonomous layer traversal. Input/weights/RAW output reside in CHW DDR.
// The next output page is filled while the preceding page is written to DDR.
// Configuration and normalization coefficients must remain stable until done.
module p2_layer_parallel(input clk,rst_n,start,
 input pre_mode,inject_valid,output inject_ready,input inject_page,inject_commit,input[3:0]inject_channel,inject_group,input[63:0]inject_data,
 input pre_store_start,pre_store_page,input[31:0]pre_store_base,pre_store_pixel,input[7:0]pre_store_count,
 output pre_store_ready,pre_store_done,pre_store_error,input[1:0]mode,input stride2,upsample2,
 input[31:0]source_base,skip_base,weight_base,output_base,
 input[9:0]input_width,input_height,output_width,output_height,input[7:0]cin,cout,
 input has_skip,input[1:0]skip_bank,input input_relu,skip_relu,input signed[3:0]input_exp,skip_exp,
 input cfg_we,input[1:0]cfg_bank,input[6:0]cfg_channel,input signed[18:0]cfg_coef,input signed[31:0]cfg_offset,input[3:0]cfg_adjust,
 input shift_we,input[6:0]shift_channel,input signed[5:0]shift_value,
 input output_cfg_we,input[9:0]output_cfg_address,input[7:0]output_cfg_data,
 input[6:0]stats_read_channel,output signed[26:0]stats_sum,output[32:0]stats_sumsq,
 output ready,output reg done,output reg[3:0]error,output reg[31:0]elapsed,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,input[1:0]bresp,input bvalid,output bready);
 localparam IDLE=0,CLEAR=1,WAITSTAT=2,ROW=3,LSTART=4,LWAIT=5,WSTART=6,WRUN=7,COMPUTE=8,STORE=9,NEXT=10,DRAIN=11,FAIL=12;
 reg[3:0]state;reg[31:0]tile;reg[10:0]pos,tile_count;reg[9:0]y;reg[6:0]oc;reg[1:0]ky;reg[9:0]row;
 reg scratch,inpage,resultpage,weightpage,weights_cached;
 reg[39:0]tags;reg[3:0]tags_valid;
 reg[8:0]wi;reg[1:0]word_index;reg word_valid,weight_done;reg[127:0]word_data;
 reg pf_tile_done;reg[31:0]pf_tile;reg[10:0]pf_count;reg pf_page;reg[1:0]pf_state;reg[9:0]pf_row;reg pf_scratch;wire pf_active=pf_state!=0;
 wire[10:0]future_row=(((y<<stride2)+1)>>upsample2)+1;
 wire pf_candidate=!pw&&future_row<input_height&&!((tags_valid[future_row[1:0]])&&tags[future_row[1:0]*10+:10]==future_row);
 wire[9:0]selected_row=pf_active?pf_row:row;wire selected_scratch=pf_active?pf_scratch:scratch;
 reg store_active;reg[31:0]flush_pixel;reg[7:0]flush_count;reg[6:0]flush_oc;reg flush_page;
 function automatic[31:0]row_pixels(input[31:0]y,input[9:0]w);
 reg[31:0]x;begin x=(y<<5)+(y<<3);case(w)40:row_pixels=x;80:row_pixels=x<<1;160:row_pixels=x<<2;320:row_pixels=x<<3;default:row_pixels=0;endcase end
 endfunction
 function automatic[31:0]channel_pixels(input[6:0]c,input[31:0]plane);
 reg[31:0]x;begin x=(c<<11)+(c<<8)+(c<<6)+(c<<5);case(plane)2400:channel_pixels=x;9600:channel_pixels=x<<2;38400:channel_pixels=x<<4;153600:channel_pixels=x<<6;default:channel_pixels=0;endcase end
 endfunction
 wire pw=mode==0,fin=mode==2;wire[31:0]iplane=row_pixels({22'd0,input_height},input_width),oplane=row_pixels({22'd0,output_height},output_width);
 wire[10:0]capacity=cin==128?128:cin==64?256:cin==32?512:1024;
 wire[2:0]cshift=cin==3?0:cin==16?2:cin==32?3:cin==64?4:5;
 wire[4:0]out_channels=fin?3:cout-oc>=16?16:cout-oc;
 wire[10:0]extent=pw?tile_count:{1'b0,output_width};
 wire[6:0]lanes=pw?16:fin?64:extent-pos>=16?16:8;
 wire chunk_end=(pos+lanes==extent)||((pos+lanes)%128==0);
 wire[31:0]linear_pixel=pw?tile+pos:row_pixels({22'd0,y},output_width)+pos;
 wire[31:0]chunk_pixel=linear_pixel-(pos%128);
 wire[7:0]chunk_count=extent-(pos/128)*128>=128?128:extent-(pos/128)*128;
 reg[95:0]shifts;reg signed[5:0]shift_mem[0:127],shift_q;
 reg shift_loading,shift_qvalid;reg[3:0]shift_index,shift_qindex;
 reg shift_tag_valid;reg[6:0]shift_tag;
 wire shifts_ready=shift_tag_valid&&shift_tag==oc&&!shift_loading&&!shift_qvalid;
 wire shift_start=wload||(state==COMPUTE&&!shifts_ready&&!shift_loading&&!shift_qvalid);
 always @(posedge clk)begin
  if(shift_we&&ready)shift_mem[shift_channel]<=shift_value;
  if(shift_loading)shift_q<=shift_mem[oc+shift_index];
  if(!rst_n)begin shift_loading<=0;shift_qvalid<=0;shift_index<=0;shift_qindex<=0;shifts<=0;shift_tag_valid<=0;shift_tag<=0;end
  else begin
   shift_qvalid<=shift_loading;
   if(state==CLEAR)shift_tag_valid<=0;
   if(shift_start)begin shift_loading<=1;shift_index<=0;shift_tag<=oc;shift_tag_valid<=1;end
   if(shift_loading)begin shift_qindex<=shift_index;shift_index<=shift_index+1'b1;if(shift_index==15)shift_loading<=0;end
   if(shift_qvalid)shifts[shift_qindex*6+:6]<=({1'b0,oc}+shift_qindex<cout)?shift_q:-6'sd1;
  end
 end
 reg signed[11:0]sy,ey;reg[9:0]needed;
 always @*begin ey=input_height<<upsample2;sy=(y<<stride2)+ky-1;if(sy<0)sy=-sy-1;else if(sy>=ey)sy=2*ey-1-sy;needed=sy>>upsample2;end
 wire lr,ld,le,cr,cb,cd,ce,sr,sd,se,stats_ready,wr;
 wire[31:0]pa,wa;wire[7:0]pn,wn;wire pv,wv,pr,war,prv,wrv,prt,wrt;
 wire wd_ready,wd_done,wd_error,wd_valid,wd_take;wire[127:0]wd_data;
 wire wload=state==WSTART&&wd_ready&&!cb;
 wire weight_accept=pw?(wd_valid&&wr):(word_valid);
 wire path_weight_valid=state==WRUN&&pw&&wd_valid;
 wire path_spatial_weight=state==WRUN&&!pw&&word_valid;
 assign wd_take=state==WRUN&&(pw?wr:!word_valid);
 wire load_fire=(pf_active?pf_state==1:state==LSTART)&&lr;
 wire compute_fire=state==COMPUTE&&cr&&shifts_ready;
 wire store_fire=state==STORE&&sr;
 assign ready=state==IDLE;
 p2_read_arbiter arb(clk,rst_n,pa,wa,pn,wn,pv,wv,pr,war,prv,wrv,prt,wrt,araddr,arlen,arvalid,arready,rvalid,rlast,rready);
 p2_tensor_dma weights_dma(.clk(clk),.rst_n(rst_n),.rd_start(wload),.rd_address(weight_base+(pw?(cin==3?({25'd0,oc}<<1)+oc:({25'd0,oc}<<(cshift+2))):0)),.rd_beats(pw?{24'd0,cin}:fin?32'd36:((({24'd0,cout}+15)>>4)*9)),.rd_ready(wd_ready),.rd_done(wd_done),.rd_error(wd_error),
 .araddr(wa),.arlen(wn),.arvalid(wv),.arready(war),.rdata(rdata),.rresp(rresp),.rvalid(wrv),.rlast(rlast),.rready(wrt),.m_data(wd_data),.m_valid(wd_valid),.m_ready(wd_take),
 .wr_start(1'b0),.wr_address(32'd0),.wr_beats(32'd0),.wr_ready(),.wr_done(),.wr_error(),.awaddr(),.awlen(),.awvalid(),.awready(1'b0),.s_data(128'd0),.s_valid(1'b0),.s_ready(),.wdata(),.wstrb(),.wvalid(),.wlast(),.wready(1'b0),.bresp(2'd0),.bvalid(1'b0),.bready());
 assign pre_store_ready=sr;assign pre_store_done=sd;assign pre_store_error=se;
 p2_shared_path path(.clk(clk),.rst_n(rst_n),.inject_valid(inject_valid&&pre_mode),.inject_ready(inject_ready),.inject_page(inject_page),.inject_commit(inject_commit),.inject_channel(inject_channel),.inject_group(inject_group),.inject_data(inject_data),.invalidate(state==CLEAR),
 .load_start(load_fire),.load_page(pw&&pf_active?pf_page:inpage),.load_tile(pw),.load_final(fin),.load_scratch(selected_scratch),.load_residual(has_skip&&!selected_scratch),.skip_exp_m4(skip_exp==-4),.param_bank(selected_scratch?skip_bank:2'd0),.load_row(selected_row),
 .source_base(selected_scratch?skip_base:source_base),.plane_pixels(iplane),.tile_pixel(pw?(pf_active?pf_tile:tile):row_pixels({22'd0,selected_row},input_width)),.channels(cin),.pixel_count(pw?(pf_active?pf_count:tile_count):{1'b0,input_width}),.relu(selected_scratch?skip_relu:input_relu),.next_exp(selected_scratch?skip_exp:input_exp),
 .cfg_we(cfg_we&&ready),.cfg_bank(cfg_bank),.cfg_channel(cfg_channel),.cfg_coef(cfg_coef),.cfg_offset(cfg_offset),.cfg_adjust(cfg_adjust),.load_ready(lr),.load_done(ld),.load_error(le),
 .weight_valid(path_weight_valid),.weight_page(weightpage),.weight_ready(wr),.weight_channel(wi[6:0]),.weight_data(wd_data),
 .compute_start(compute_fire),.compute_page(inpage),.start_weight_page(weightpage),.compute_spatial(!pw),.compute_final(fin),.stride2(stride2),.upsample2(upsample2),.spatial_block(pos[9:4]),.channel_shift(cshift),.raw_shifts(shifts),.compute_ready(cr),.compute_busy(cb),.compute_done(cd),.compute_error(ce),
 .input_width(input_width),.input_height(input_height),.tile_x(pos[9:0]),.tile_y(y),.lane_count(lanes),.channel_base(oc),.channel_groups(cin==3?3'd1:3'd4),
 .spatial_weight_valid(path_spatial_weight),.spatial_weight_address(wi),.spatial_weight_data(word_data[word_index*32+:32]),
 .araddr(pa),.arlen(pn),.arvalid(pv),.arready(pr),.rdata(rdata),.rresp(rresp),.rvalid(prv),.rlast(rlast),.rready(prt),
 .output_channel_base(oc),.output_channels(out_channels),.result_group(pos[6:3]),.result_page(resultpage),.result_commit(chunk_end),
 .output_cfg_we(output_cfg_we&&ready),.output_cfg_address(output_cfg_address),.output_cfg_data(output_cfg_data),
 .stats_clear(state==CLEAR),.stats_read_channel(stats_read_channel),.stats_sum(stats_sum),.stats_sumsq(stats_sumsq),.stats_ready(stats_ready),
 .store_start(pre_mode?pre_store_start:store_fire),.store_page(pre_mode?pre_store_page:flush_page),.store_rgb(fin&&!pre_mode),.store_base(pre_mode?pre_store_base:output_base+(fin?0:channel_pixels(flush_oc,oplane))),.store_plane(pre_mode?32'd153600:oplane),.store_pixel(pre_mode?pre_store_pixel:flush_pixel),.store_count(pre_mode?pre_store_count:flush_count),.store_channels(pre_mode||fin?5'd3:cout-flush_oc>=16?5'd16:5'(cout-flush_oc)),.store_ready(sr),.store_done(sd),.store_error(se),
 .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wlast(wlast),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready));
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;pf_tile_done<=0;pf_tile<=0;pf_count<=0;pf_page<=0;pf_state<=0;pf_row<=0;pf_scratch<=0;done<=0;error<=0;elapsed<=0;tile<=0;pos<=0;tile_count<=0;y<=0;oc<=0;ky<=0;row<=0;scratch<=0;inpage<=0;resultpage<=0;weightpage<=0;weights_cached<=0;tags<=0;tags_valid<=0;wi<=0;word_index<=0;word_valid<=0;word_data<=0;weight_done<=0;store_active<=0;flush_pixel<=0;flush_count<=0;flush_oc<=0;flush_page<=0;end
  else begin
   done<=0;if(!ready)elapsed<=elapsed+1'b1;
   if(store_fire)store_active<=1;else if(sd)store_active<=0;
   if(wload)begin wi<=0;word_valid<=0;weight_done<=0;word_index<=0;end
   if(wd_done)weight_done<=1;
   if(wd_valid&&wd_take)begin if(pw)wi<=wi+1'b1;else begin word_data<=wd_data;word_valid<=1;word_index<=0;end end
   if(path_spatial_weight)begin wi<=wi+1'b1;if(word_index==3)word_valid<=0;else word_index<=word_index+1'b1;end
   case(pf_state)
    0:if(pw&&!pf_tile_done&&tile+tile_count<iplane&&(state==COMPUTE||state==WRUN))begin
      pf_tile<=tile+tile_count;pf_count<=iplane-tile-tile_count<capacity?iplane-tile-tile_count:capacity;pf_page<=!inpage;pf_scratch<=0;pf_state<=1;
     end else if(pf_candidate&&(state==COMPUTE||state==STORE||state==WRUN))begin pf_row<=future_row;pf_scratch<=has_skip;pf_state<=1;end
    1:if(lr)pf_state<=2;
    2:if(ld)begin
     if(le)begin error<=2;state<=FAIL;pf_state<=0;end
     else if(pf_scratch)begin pf_scratch<=0;pf_state<=1;end
     else if(pw)begin pf_tile_done<=1;pf_state<=0;end
     else begin tags_valid[pf_row[1:0]]<=1;tags[pf_row[1:0]*10+:10]<=pf_row;pf_state<=0;end
    end
   endcase
   case(state)
    IDLE:if(start)begin
     error<=0;elapsed<=0;tile<=0;pos<=0;y<=0;oc<=0;ky<=0;row<=0;scratch<=0;inpage<=0;resultpage<=0;weightpage<=0;weights_cached<=0;tags_valid<=0;pf_tile_done<=0;
     tile_count<=iplane<capacity?iplane:capacity;
     if(mode==3||cin==0||cout==0||cin>128||cout>128||oplane==0||iplane==0||output_width[2:0]!=0||has_skip&&pw)begin done<=1;error<=1;end
     else state<=CLEAR;
    end
    CLEAR:state<=WAITSTAT;
    WAITSTAT:if(stats_ready)state<=pw?LSTART:ROW;
    ROW:if(pf_active)begin end
     else if(ky==3)begin oc<=0;pos<=0;state<=weights_cached?COMPUTE:WSTART;end
     else if(tags_valid[needed&3]&&tags[(needed&3)*10+:10]==needed)ky<=ky+1'b1;
     else begin row<=needed;scratch<=has_skip;state<=LSTART;end
    LSTART:if(lr)state<=LWAIT;
    LWAIT:if(ld)begin
     if(le)begin error<=2;state<=FAIL;end
     else if(scratch)begin scratch<=0;state<=LSTART;end
     else if(pw)state<=WSTART;
     else begin tags_valid[row[1:0]]<=1;tags[row[1:0]*10+:10]<=row;ky<=ky+1'b1;state<=ROW;end
    end
    WSTART:if(wd_ready&&!cb)state<=WRUN;
    WRUN:if(weight_done&&!word_valid&&!shift_loading&&!shift_qvalid)begin if(wd_error)begin error<=3;state<=FAIL;end else begin weights_cached<=1;state<=COMPUTE;end end
    COMPUTE:if(compute_fire)begin
     if(chunk_end)begin flush_pixel<=chunk_pixel;flush_count<=chunk_count;flush_oc<=oc;flush_page<=resultpage;state<=STORE;end
     else pos<=pos+lanes;
    end
    STORE:if(store_fire)begin resultpage<=!resultpage;state<=NEXT;end
    NEXT:if(pos+lanes<extent)begin pos<=pos+lanes;state<=COMPUTE;end
     else if(!fin&&oc+16<cout)begin pos<=0;oc<=oc+16;weightpage<=!weightpage;state<=pw?WSTART:COMPUTE;end
     else if(pw&&tile+tile_count<iplane)begin if(pf_tile_done)begin tile<=pf_tile;tile_count<=pf_count;pos<=0;oc<=0;inpage<=pf_page;pf_tile_done<=0;state<=WSTART;end end
     else if(!pw&&y+1<output_height)begin y<=y+1'b1;ky<=0;state<=ROW;end
     else state<=DRAIN;
    DRAIN:if(!cb&&!store_active&&!pf_active)begin done<=1;state<=IDLE;end
    FAIL:if(!cb&&!store_active&&lr&&wd_ready&&!pf_active)begin done<=1;state<=IDLE;end
   endcase
   if(!ready&&((cd&&ce)||(sd&&se)))begin error<=cd&&ce?4:5;state<=FAIL;end
  end
 end
endmodule
