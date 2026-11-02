// A complete 16-output-channel pointwise layer: RAW-feature DMA -> prior
// layer normalization -> ping-pong tile cache -> reusable weights/MAC ->
// output DMA. Blocked layout [tile16 pixels][channel][pixel].
// Prior-layer IN coefficients must already be calculated; this is not the
// complete network executor. Supports the final PW layer (Cout=16) directly.
module p2_pw16_layer #(parameter COMPACT_NORM=0,parameter HALF_RATE=0)(input clk,rst_n,
 input start,input[31:0]input_base,output_base,tile_count,input[7:0]cin,
 input weight_page,input[95:0]shifts,input prior_relu,input signed[5:0]relu_exp,next_exp,
 input coeff_we,input[6:0]coeff_address,input signed[18:0]coeff_value,
 input signed[31:0]offset_value,input[4:0]adjust_value,
 input weight_we,weight_write_page,input[6:0]weight_address,input[127:0]weight_data,output weight_ready,
 output ready,output reg busy,done,error,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,
 input[1:0]bresp,input bvalid,output bready);
 reg signed[18:0]coefs[0:127];reg signed[31:0]offsets[0:127];reg[4:0]adjusts[0:127];
 reg[127:0]coeff_filled;
 reg[31:0]tiles,read_index,cmd_index,write_index,read_address,write_address;
 reg[7:0]channels;reg job_weight_page,job_relu;reg signed[5:0]job_re,job_ne;reg[95:0]job_shifts;
 reg read_active,write_active;reg[1:0]loaded;
 reg rd_start,wr_start,core_start,inv;
 reg[6:0]input_channel,output_channel;
 reg buf_valid;reg[127:0]buf_data;reg signed[18:0]buf_coef;reg signed[31:0]buf_offset;reg[4:0]buf_adjust;
 wire rd_ready,rd_done,rd_error,wr_ready,wr_done,wr_error;
 wire[127:0]dma_data,core_data,norm_data;wire dma_valid,dma_ready,core_valid,core_mready;
 wire core_ready,core_busy,core_done,core_error,feature_ready,core_weight_ready;
 assign weight_ready=core_weight_ready&&!busy;
 wire[3:0]core_channel;wire core_last;
 wire[15:0]norm_ready,norm_valid;
 reg buf_half,out_half;reg[63:0]norm_first;
 wire feature_valid=norm_valid[0]&&(!HALF_RATE||out_half);
 wire[127:0]feature_data=HALF_RATE?{norm_data[63:0],norm_first}:norm_data;
 wire prefix_ready=!buf_valid||(norm_ready[0]&&(!HALF_RATE||buf_half));
 assign dma_ready=prefix_ready&&read_active;
 genvar g;
 generate for(g=0;g<(HALF_RATE?8:16);g=g+1)begin:normalizer
 wire signed[7:0]raw_pixel=buf_data[(g+(HALF_RATE&&buf_half?8:0))*8+:8];
 if(COMPACT_NORM)begin:compact
  p2_norm_input_qm2 n(clk,rst_n,buf_valid,norm_ready[g],raw_pixel,buf_coef,buf_offset,buf_adjust,
   norm_valid[g],feature_ready,norm_data[g*8+:8]);
 end else begin:general_norm
  p2_norm_residual n(clk,rst_n,buf_valid,norm_ready[g],raw_pixel,buf_coef,buf_offset,buf_adjust,
   32'sd0,1'b0,job_relu,job_re,job_ne,norm_valid[g],feature_ready,norm_data[g*8+:8],);
 end
 end endgenerate
 generate if(HALF_RATE)begin
  assign norm_ready[15:8]=0;assign norm_valid[15:8]=0;assign norm_data[127:64]=0;
 end endgenerate
 p2_pointwise_overlap core(clk,rst_n,inv,read_index[0],feature_valid,read_index[0],output_channel,feature_data,feature_ready,
  weight_we&&!busy,weight_write_page,core_weight_ready,weight_address,weight_data,
  core_start,cmd_index[0],job_weight_page,channels,job_shifts,core_ready,core_busy,core_done,core_error,
  core_valid,core_mready,core_data,core_channel,core_last);
 p2_tensor_dma dma(clk,rst_n,rd_start,read_address,{24'd0,channels},rd_ready,rd_done,rd_error,
  araddr,arlen,arvalid,arready,rdata,rresp,rvalid,rlast,rready,dma_data,dma_valid,dma_ready,
  wr_start,write_address,32'd16,wr_ready,wr_done,wr_error,awaddr,awlen,awvalid,awready,
  core_data,core_valid,core_mready,wdata,wstrb,wvalid,wlast,wready,bresp,bvalid,bready);
 assign ready=!busy&&!error;
 reg missing;integer k;
 always @*begin missing=0;for(k=0;k<128;k=k+1)if(k<cin&&!coeff_filled[k])missing=1;end
 always @(posedge clk)begin
  if(!rst_n)coeff_filled<=0;
  else if(coeff_we&&!busy)begin coefs[coeff_address]<=coeff_value;offsets[coeff_address]<=offset_value;adjusts[coeff_address]<=adjust_value;coeff_filled[coeff_address]<=1;end
  if(dma_valid&&dma_ready)begin
   buf_data<=dma_data;buf_coef<=coefs[input_channel];buf_offset<=offsets[input_channel];buf_adjust<=adjusts[input_channel];
  end
 end
 always @(posedge clk)begin
  if(!rst_n)begin busy<=0;done<=0;error<=0;rd_start<=0;wr_start<=0;core_start<=0;inv<=0;
   read_active<=0;write_active<=0;loaded<=0;read_index<=0;cmd_index<=0;write_index<=0;read_address<=0;write_address<=0;
   channels<=0;tiles<=0;input_channel<=0;output_channel<=0;buf_valid<=0;job_weight_page<=0;job_relu<=0;job_re<=0;job_ne<=0;job_shifts<=0;buf_half<=0;out_half<=0;norm_first<=0;
  end else begin
   done<=0;rd_start<=0;wr_start<=0;core_start<=0;inv<=0;
   if(prefix_ready)buf_valid<=dma_valid&&dma_ready;
   if(HALF_RATE&&buf_valid&&norm_ready[0])buf_half<=!buf_half;
   if(HALF_RATE&&norm_valid[0]&&feature_ready)begin
    out_half<=!out_half;if(!out_half)norm_first<=norm_data[63:0];
   end
   if(dma_valid&&dma_ready)input_channel<=input_channel+1'b1;
   if(start&&ready)begin
    if(tile_count==0||cin==0||cin>128||missing||input_base[3:0]!=0||output_base[3:0]!=0||
       (COMPACT_NORM&&(prior_relu||next_exp!=-6'sd2)))begin error<=1;done<=1;end
    else begin busy<=1;tiles<=tile_count;channels<=cin;read_address<=input_base;write_address<=output_base;
     read_index<=0;cmd_index<=0;write_index<=0;loaded<=0;job_weight_page<=weight_page;job_shifts<=shifts;
     job_relu<=prior_relu;job_re<=relu_exp;job_ne<=next_exp;
    end
   end
   if(busy&&!error)begin
    if(!read_active&&read_index<tiles&&!loaded[read_index[0]]&&feature_ready&&rd_ready&&!rd_start)begin
     rd_start<=1;inv<=1;read_active<=1;input_channel<=0;output_channel<=0;
    end
    if(feature_valid&&feature_ready)begin
     if(output_channel==channels-1'b1)begin loaded[read_index[0]]<=1;read_active<=0;read_index<=read_index+1'b1;read_address<=read_address+{channels,4'b0};end
     else output_channel<=output_channel+1'b1;
    end
    // core_start is a registered pulse. Keep cmd_index stable through its
    // handshake, then release that page for the producer to refill.
    if(!core_start&&cmd_index<tiles&&loaded[cmd_index[0]]&&core_ready)core_start<=1;
    if(core_start&&core_ready)begin loaded[cmd_index[0]]<=0;cmd_index<=cmd_index+1'b1;end
    if(!write_active&&write_index<tiles&&core_valid&&wr_ready)begin wr_start<=1;write_active<=1;end
    if(wr_done)begin
     write_active<=0;write_address<=write_address+256;write_index<=write_index+1'b1;
     if(write_index==tiles-1'b1&&!wr_error)begin busy<=0;done<=1;end
    end
    if(rd_error||wr_error||core_error)begin error<=1;busy<=0;done<=1;end
   end
  end
 end
endmodule

