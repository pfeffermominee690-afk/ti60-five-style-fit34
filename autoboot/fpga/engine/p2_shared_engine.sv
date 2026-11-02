// Unified PW/DW/final datapath: one 128-DSP MAC array, one 8-lane normalizer, one banked SRAM.
module p2_shared_engine(input clk,rst_n,
 input invalidate,input load_start,load_page,load_tile,load_final,load_scratch,load_residual,skip_exp_m4,input[1:0]param_bank,input[9:0]load_row,input[31:0]source_base,plane_pixels,tile_pixel,
 input[7:0]channels,input[10:0]pixel_count,input relu,input signed[3:0]next_exp,
 input cfg_we,input[1:0]cfg_bank,input[6:0]cfg_channel,input signed[18:0]cfg_coef,input signed[31:0]cfg_offset,input[3:0]cfg_adjust,
 output load_ready,load_done,load_error,
 input weight_valid,weight_page,output weight_ready,input[6:0]weight_channel,input[127:0]weight_data,
 input compute_start,compute_page,start_weight_page,compute_spatial,compute_final,stride2,upsample2,input[5:0]spatial_block,input[2:0]channel_shift,
 input[95:0]raw_shifts,output compute_ready,compute_busy,compute_done,compute_error,
 output m_valid,input m_ready,output[63:0]m_data,output[3:0]m_channel,output m_half,m_last,output[1:0]m_spatial_group,
 input[9:0]input_width,input_height,tile_x,tile_y,input[6:0]lane_count,channel_base,input[2:0]channel_groups,
 input spatial_weight_valid,input[8:0]spatial_weight_address,input[31:0]spatial_weight_data,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready);
 wire[63:0]we;wire[575:0]wa,sra,pra,cra,wra;wire[511:0]wd,srd;
 wire sr,smv,smr,pv,pr,pmr,cv,cr,cmr,wv,wr,wmr,lr,core_ready,ext_ready,win_ready,win_done,win_error,core_done,core_error;
 reg loading_page,active_page,load_was_tile,load_was_scratch,spatial_active;reg[9:0]loading_row;reg[1:0]valid_pages;
 reg[39:0]row_tags;reg[3:0]row_valid;reg response_owner,turn;
 wire load_fire=load_start&&load_ready;
 wire compute_fire=compute_start&&compute_ready;
 reg[3:0]active_rows,requested_rows;integer ry,ey;
 always @*begin
  requested_rows=0;ey=input_height<<upsample2;
  for(integer k=0;k<3;k=k+1)begin
   ry=(tile_y<<stride2)+k-1;if(ry<0)ry=-ry-1;else if(ry>=ey)ry=2*ey-1-ry;ry=ry>>upsample2;requested_rows[ry&3]=1;
  end
 end
 always @(posedge clk)if(!rst_n)active_rows<=0;else if(compute_fire&&compute_spatial)active_rows<=requested_rows;
 assign compute_ready=compute_spatial?(ext_ready&&win_ready&&(lr||(!load_was_tile&&!requested_rows[loading_row[1:0]]))):(core_ready&&valid_pages[compute_page]&&(lr||loading_page!=compute_page));
 assign load_ready=lr&&(load_tile?(!compute_busy||(!spatial_active&&active_page!=load_page)):(!compute_busy||(spatial_active&&!active_rows[load_row[1:0]])))&&!(compute_fire&&(compute_spatial?requested_rows[load_row[1:0]]:compute_page==load_page));
 assign compute_done=core_done||(win_done&&win_error);
 assign compute_error=core_error||win_error;
 wire compute_cv=spatial_active?wv:cv;wire[575:0]compute_ra=spatial_active?wra:cra;
 wire compute_mr=spatial_active?wmr:cmr;
 wire grant_pref=pv&&(!compute_cv||turn);
 wire request_valid=grant_pref?pv:compute_cv;
 // Select common addresses before the 64 bank-local binary selectors.
 wire[8:0]read_base=grant_pref?pra[8:0]:(spatial_active?wra[8:0]:cra[8:0]);
 wire[8:0]read_next=grant_pref?pra[8:0]:(spatial_active?wra[17:9]:cra[8:0]);
 assign sra={494'd0,wra[81:18],read_next,read_base};
 assign pr=sr&&grant_pref;assign cr=sr&&!grant_pref&&!spatial_active;assign wr=sr&&!grant_pref&&spatial_active;
 assign smr=response_owner?pmr:compute_mr;
 always @(posedge clk)begin
  if(!rst_n)begin valid_pages<=0;row_tags<=0;row_valid<=0;loading_page<=0;active_page<=0;load_was_tile<=0;load_was_scratch<=0;loading_row<=0;spatial_active<=0;response_owner<=0;turn<=0;end
  else begin
   if(invalidate)begin valid_pages<=0;row_valid<=0;end
   if(request_valid&&sr)begin response_owner<=grant_pref;turn<=!grant_pref;end
   if(load_done&&!load_error)begin
    if(load_was_tile)valid_pages[loading_page]<=1;
    else if(!load_was_scratch)begin row_valid[loading_row[1:0]]<=1;row_tags[loading_row[1:0]*10+:10]<=loading_row;end
   end
   if(load_fire)begin
    loading_page<=load_page;loading_row<=load_row;load_was_tile<=load_tile;load_was_scratch<=load_scratch;
    if(load_tile)valid_pages[load_page]<=0;else if(!load_scratch)row_valid[load_row[1:0]]<=0;
   end
   if(compute_fire)begin active_page<=compute_page;spatial_active<=compute_spatial;end
  end
 end
 p2_feature_prefetch loader(clk,rst_n,load_fire,load_row[1:0],load_tile,load_page,load_final,load_scratch,load_residual,skip_exp_m4,param_bank,
 source_base,plane_pixels,tile_pixel,channels,pixel_count,relu,next_exp,cfg_we,cfg_bank,cfg_channel,cfg_coef,cfg_offset,cfg_adjust,lr,load_done,load_error,
 we,wa,wd,pv,pr,pra,smv&&response_owner,pmr,srd,araddr,arlen,arvalid,arready,rdata,rresp,rvalid,rlast,rready);
 p2_operand_sram #(.WRITE_FORWARD(0),.COMPACT_ADDRESS(1)) cache(clk,rst_n,we,wa,wd,request_valid,sr,sra,smv,smr,srd);
 wire ev,er,el;wire[511:0]ep;wire[31:0]ew;wire[1:0]eg;
 p2_spatial_window #(.COMPACT_ADDRESS(1)) window(clk,rst_n,compute_fire&&compute_spatial,compute_final,stride2,upsample2,input_width,input_height,tile_x,tile_y,lane_count,channel_base,channel_groups,row_tags,row_valid,
 spatial_weight_valid,spatial_weight_address,spatial_weight_data,win_ready,win_done,win_error,
 wv,wr,wra,smv&&!response_owner&&spatial_active,wmr,srd,ev,er,ep,ew,eg,el);
 p2_shared_banked core(clk,rst_n,weight_valid,weight_page,weight_ready,weight_channel,weight_data,
 compute_fire&&!compute_spatial,compute_page,start_weight_page,spatial_block,channel_shift,channels,raw_shifts,core_ready,compute_busy,core_done,core_error,
 cv,cr,cra,smv&&!response_owner&&!spatial_active,cmr,srd,m_valid,m_ready,m_data,m_channel,m_half,m_last,m_spatial_group,
 compute_fire&&compute_spatial,ext_ready,compute_final,raw_shifts,ev,er,el,eg,ep,ew);
endmodule
