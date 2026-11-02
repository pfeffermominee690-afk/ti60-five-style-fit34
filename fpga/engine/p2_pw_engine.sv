// Parallel PW datapath: DDR -> eight IN lanes -> two-page SRAM -> 256 MACs.
// Commands accepted only on ready. Full-network scheduling is external.
module p2_pw_engine(input clk,rst_n,
 input load_start,load_page,input[31:0]source_base,plane_pixels,tile_pixel,
 input[7:0]channels,input[10:0]pixel_count,input relu,input signed[3:0]next_exp,
 input cfg_we,input[6:0]cfg_channel,input signed[18:0]cfg_coef,input signed[31:0]cfg_offset,input[3:0]cfg_adjust,
 output load_ready,load_done,load_error,
 input weight_valid,weight_page,output weight_ready,input[6:0]weight_channel,input[127:0]weight_data,
 input compute_start,compute_page,start_weight_page,input[5:0]spatial_block,input[2:0]channel_shift,
 input[95:0]raw_shifts,output compute_ready,compute_busy,compute_done,compute_error,
 output m_valid,input m_ready,output[63:0]m_data,output[3:0]m_channel,output m_half,m_last,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready);
 wire[63:0]we;wire[575:0]wa,ra;wire[511:0]wd,rd;
 wire sv,sr,mv,mr,lr,cr;reg loading_page,active_page;reg[1:0]valid_pages;
 wire load_fire=load_start&&load_ready;
 wire compute_fire=compute_start&&compute_ready;
 // Compute has priority if both commands target the same available page.
 assign compute_ready=cr&&valid_pages[compute_page]&&(lr||loading_page!=compute_page);
 assign load_ready=lr&&(!compute_busy||active_page!=load_page)&&!(compute_fire&&compute_page==load_page);
 always @(posedge clk)begin
  if(!rst_n)begin valid_pages<=0;loading_page<=0;active_page<=0;end
  else begin
   if(load_done)valid_pages[loading_page]<=!load_error;
   if(load_fire)begin loading_page<=load_page;valid_pages[load_page]<=0;end
   if(compute_fire)active_page<=compute_page;
  end
 end
 p2_pw_prefetch loader(clk,rst_n,load_fire,load_page,source_base,plane_pixels,tile_pixel,channels,pixel_count,relu,next_exp,cfg_we,cfg_channel,cfg_coef,cfg_offset,cfg_adjust,lr,load_done,load_error,we,wa,wd,araddr,arlen,arvalid,arready,rdata,rresp,rvalid,rlast,rready);
 p2_operand_sram cache(clk,rst_n,we,wa,wd,sv,sr,ra,mv,mr,rd);
 p2_pw_banked core(clk,rst_n,weight_valid,weight_page,weight_ready,weight_channel,weight_data,compute_fire,compute_page,start_weight_page,spatial_block,channel_shift,channels,raw_shifts,cr,compute_busy,compute_done,compute_error,sv,sr,ra,mv,mr,rd,m_valid,m_ready,m_data,m_channel,m_half,m_last);
endmodule
