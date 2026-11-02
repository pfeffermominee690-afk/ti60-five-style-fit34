// PW input normalization, banked MAC, output statistics and ping-pong DDR writeback.
// Two-entry command tags remain aligned when compute overlaps output.
module p2_pw_path(input clk,rst_n,
 input load_start,load_page,input[31:0]source_base,plane_pixels,tile_pixel,
 input[7:0]channels,input[10:0]pixel_count,input relu,input signed[3:0]next_exp,
 input cfg_we,input[6:0]cfg_channel,input signed[18:0]cfg_coef,input signed[31:0]cfg_offset,input[3:0]cfg_adjust,
 output load_ready,load_done,load_error,
 input weight_valid,weight_page,output weight_ready,input[6:0]weight_channel,input[127:0]weight_data,
 input compute_start,compute_page,start_weight_page,input[5:0]spatial_block,input[2:0]channel_shift,
 input[95:0]raw_shifts,output compute_ready,compute_busy,compute_done,compute_error,
 input[6:0]output_channel_base,input result_page,result_commit,
 input stats_clear,input[6:0]stats_read_channel,output signed[26:0]stats_sum,output[32:0]stats_sumsq,output stats_ready,
 input store_start,store_page,input[31:0]store_base,store_plane,store_pixel,input[7:0]store_count,input[4:0]store_channels,
 output store_ready,store_done,store_error,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,input[1:0]bresp,input bvalid,output bready,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready);
 wire engine_ready,mv,mh,ml,store_sr;wire[63:0]md;wire[3:0]mc;
 reg[12:0]metadata[0:1];reg rp,wp;reg[1:0]queued;
 wire[12:0]tag=metadata[rp];
 wire take_ready=store_sr&&stats_ready&&(queued!=0);
 wire pop=mv&&take_ready&&ml;
 assign compute_ready=engine_ready&&(queued<2);
 wire fire=compute_start&&compute_ready;
 always @(posedge clk)begin
  if(!rst_n)begin rp<=0;wp<=0;queued<=0;end
  else begin
   if(fire)begin metadata[wp]<={output_channel_base,result_page,result_commit,spatial_block[2:0],1'b0};wp<=~wp;end
   if(pop)rp<=~rp;
   case({fire,pop})2'b10:queued<=queued+1'b1;2'b01:queued<=queued-1'b1;default:begin end endcase
  end
 end
 p2_pw_engine engine(.clk(clk),.rst_n(rst_n),.load_start(load_start),.load_page(load_page),.source_base(source_base),.plane_pixels(plane_pixels),.tile_pixel(tile_pixel),.channels(channels),.pixel_count(pixel_count),.relu(relu),.next_exp(next_exp),.cfg_we(cfg_we),.cfg_channel(cfg_channel),.cfg_coef(cfg_coef),.cfg_offset(cfg_offset),.cfg_adjust(cfg_adjust),.load_ready(load_ready),.load_done(load_done),.load_error(load_error),.weight_valid(weight_valid),.weight_page(weight_page),.weight_ready(weight_ready),.weight_channel(weight_channel),.weight_data(weight_data),.compute_start(fire),.compute_page(compute_page),.start_weight_page(start_weight_page),.spatial_block(spatial_block),.channel_shift(channel_shift),.raw_shifts(raw_shifts),.compute_ready(engine_ready),.compute_busy(compute_busy),.compute_done(compute_done),.compute_error(compute_error),.m_valid(mv),.m_ready(take_ready),.m_data(md),.m_channel(mc),.m_half(mh),.m_last(ml),.araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rlast(rlast),.rready(rready));
 p2_channel_stats8 stats(clk,rst_n,stats_clear,mv&&take_ready,tag[12:6]+{3'd0,mc},md,stats_read_channel,stats_sum,stats_sumsq,stats_ready);
 p2_burst_store store(clk,rst_n,mv&&stats_ready&&(queued!=0),store_sr,tag[5],mc,{tag[3:1],mh},md,tag[4]&&ml,
 store_start,store_page,store_base,store_plane,store_pixel,store_count,store_channels,store_ready,store_done,store_error,
 awaddr,awlen,awvalid,awready,wdata,wstrb,wvalid,wlast,wready,bresp,bvalid,bready);
endmodule
