module p2_shared_path(input clk,rst_n,
 input inject_valid,output inject_ready,input inject_page,inject_commit,input[3:0]inject_channel,inject_group,input[63:0]inject_data,
 input invalidate,input load_start,load_page,load_tile,load_final,load_scratch,load_residual,skip_exp_m4,input[1:0]param_bank,input[9:0]load_row,input[31:0]source_base,plane_pixels,tile_pixel,
 input[7:0]channels,input[10:0]pixel_count,input relu,input signed[3:0]next_exp,
 input cfg_we,input[1:0]cfg_bank,input[6:0]cfg_channel,input signed[18:0]cfg_coef,input signed[31:0]cfg_offset,input[3:0]cfg_adjust,
 output load_ready,load_done,load_error,
 input weight_valid,weight_page,output weight_ready,input[6:0]weight_channel,input[127:0]weight_data,
 input compute_start,compute_page,start_weight_page,compute_spatial,compute_final,stride2,upsample2,input[5:0]spatial_block,input[2:0]channel_shift,
 input[95:0]raw_shifts,output compute_ready,compute_busy,compute_done,compute_error,
 input[9:0]input_width,input_height,tile_x,tile_y,input[6:0]lane_count,channel_base,input[2:0]channel_groups,
 input spatial_weight_valid,input[8:0]spatial_weight_address,input[31:0]spatial_weight_data,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 input[6:0]output_channel_base,input[4:0]output_channels,input[3:0]result_group,input result_page,result_commit,
 input output_cfg_we,input[9:0]output_cfg_address,input[7:0]output_cfg_data,
 input stats_clear,input[6:0]stats_read_channel,output signed[26:0]stats_sum,output[32:0]stats_sumsq,output stats_ready,
 input store_start,store_page,store_rgb,input[31:0]store_base,store_plane,store_pixel,input[7:0]store_count,input[4:0]store_channels,
 output store_ready,store_done,store_error,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,input[1:0]bresp,input bvalid,output bready);
 wire engine_ready,mv,mh,ml,ls,lv,store_sr;wire[63:0]md,ld;wire[3:0]mc;wire[1:0]mg;wire[9:0]lt;
 // Tags survive overlap of the next PW command with the preceding output tail.
 reg[29:0]metadata[0:1];reg rp,wp;reg[1:0]queued;
 wire[29:0]tag=metadata[rp];
 wire final_tag=tag[29];wire[6:0]nlanes=tag[28:22];wire[4:0]nchannels=tag[21:17];
 wire[6:0]channel_base_tag=tag[16:10];wire pg=tag[9],commit_tag=tag[8];wire[3:0]first_group=tag[7:4];
 wire[3:0]local_group={1'b0,mg,mh};
 wire wanted=mc<nchannels&&({local_group,3'b0}<nlanes);
 wire take_ready=(queued!=0)&&(!wanted||(ls&&stats_ready));
 wire pop=mv&&take_ready&&ml;
 assign compute_ready=engine_ready&&(queued<2);
 wire fire=compute_start&&compute_ready;
 wire valid_last=(mc+1==nchannels)&&({1'b0,local_group,3'b0}+8>=nlanes);
 wire[9:0]out_tag={pg,commit_tag&&valid_last,mc,4'(first_group+local_group)};
 always @(posedge clk)begin
  if(!rst_n)begin rp<=0;wp<=0;queued<=0;end
  else begin
   if(fire)begin metadata[wp]<={compute_final,compute_spatial?lane_count:7'd16,output_channels,output_channel_base,result_page,result_commit,result_group,4'd0};wp<=~wp;end
   if(pop)rp<=~rp;
   case({fire,pop})2'b10:queued<=queued+1'b1;2'b01:queued<=queued-1'b1;default:begin end endcase
  end
 end
 p2_shared_engine engine(.clk(clk),.rst_n(rst_n),.invalidate(invalidate),.load_start(load_start),.load_page(load_page),.load_tile(load_tile),.load_final(load_final),.load_scratch(load_scratch),.load_residual(load_residual),.skip_exp_m4(skip_exp_m4),.param_bank(param_bank),.load_row(load_row),.source_base(source_base),.plane_pixels(plane_pixels),.tile_pixel(tile_pixel),.channels(channels),.pixel_count(pixel_count),.relu(relu),.next_exp(next_exp),.cfg_we(cfg_we),.cfg_bank(cfg_bank),.cfg_channel(cfg_channel),.cfg_coef(cfg_coef),.cfg_offset(cfg_offset),.cfg_adjust(cfg_adjust),.load_ready(load_ready),.load_done(load_done),.load_error(load_error),.weight_valid(weight_valid),.weight_page(weight_page),.weight_ready(weight_ready),.weight_channel(weight_channel),.weight_data(weight_data),.compute_start(fire),.compute_page(compute_page),.start_weight_page(start_weight_page),.compute_spatial(compute_spatial),.compute_final(compute_final),.stride2(stride2),.upsample2(upsample2),.spatial_block(spatial_block),.channel_shift(channel_shift),.raw_shifts(raw_shifts),.compute_ready(engine_ready),.compute_busy(compute_busy),.compute_done(compute_done),.compute_error(compute_error),.m_valid(mv),.m_ready(take_ready),.m_data(md),.m_channel(mc),.m_half(mh),.m_last(ml),.m_spatial_group(mg),.input_width(input_width),.input_height(input_height),.tile_x(tile_x),.tile_y(tile_y),.lane_count(lane_count),.channel_base(channel_base),.channel_groups(channel_groups),.spatial_weight_valid(spatial_weight_valid),.spatial_weight_address(spatial_weight_address),.spatial_weight_data(spatial_weight_data),.araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rlast(rlast),.rready(rready));
 p2_channel_stats8 stats(clk,rst_n,stats_clear,mv&&take_ready&&wanted&&!final_tag,channel_base_tag+{3'd0,mc},md,stats_read_channel,stats_sum,stats_sumsq,stats_ready);
 p2_output_lut8 output_map(clk,rst_n,output_cfg_we,output_cfg_address,output_cfg_data,!final_tag,mv&&wanted&&stats_ready&&(queued!=0),ls,mc[1:0],md,out_tag,lv,store_sr,ld,lt);
 assign inject_ready=store_sr&&!lv;
 p2_result_store store(clk,rst_n,lv||inject_valid,store_sr,lv?lt[9]:inject_page,lv?lt[7:4]:inject_channel,lv?lt[3:0]:inject_group,lv?ld:inject_data,lv?lt[8]:inject_commit,
 store_start,store_page,store_rgb,store_base,store_plane,store_pixel,store_count,store_channels,store_ready,store_done,store_error,
 awaddr,awlen,awvalid,awready,wdata,wstrb,wvalid,wlast,wready,bresp,bvalid,bready);
endmodule
