// Two 16-pixel x 128-channel INT8 tiles, 16 independent byte-wide RAM banks.
// bank=(pixel+channel)%16. Thus a 128-bit channel-contiguous DMA beat writes
// one byte per bank, while a pointwise MAC reads one channel for all16 pixels.
// Explicit fill masks reject uninitialized/stale data. Same-block read/write
// collisions report errors, rather than depending on device RAM write mode.
// This is the pointwise tile cache, NOT a depthwise 3x3 window generator.
module p2_feature_tile_cache(input clk,rst_n,
 input invalidate,input invalidate_page,
 input wr_valid,wr_page,input[3:0]wr_pixel,input[2:0]wr_block,input[127:0]wr_data,
 input s_valid,output s_ready,input s_page,input[6:0]s_channel,
 output reg m_valid,input m_ready,output reg m_error,output[127:0]m_pixels,
 input wr_transpose);
 // Transposed DMA beat:16 pixels for one channel; wr_pixel is channel[3:0].
 // A page must not change packing mode between invalidations.
 reg[15:0]filled[0:15];reg[3:0]channel_low;reg[1:0]packing,started,poisoned;
 wire accept=s_valid&&s_ready;
 wire missing=packing[s_page]?!filled[{s_page,s_channel[6:4]}][s_channel[3:0]]:
  filled[{s_page,s_channel[6:4]}]!=16'hffff;
 wire bad=missing || poisoned[s_page] ||
  (wr_valid&&wr_page==s_page&&wr_block==s_channel[6:4]) ||
  (invalidate&&invalidate_page==s_page);
 assign s_ready=!m_valid||m_ready;
 wire[127:0]banks;
 genvar b,p;
 generate for(b=0;b<16;b=b+1)begin:bank
  reg[7:0]mem[0:255];reg[7:0]data;
  wire[3:0]write_lane=b-wr_pixel;
  wire[3:0]write_pixel=wr_transpose?write_lane:wr_pixel;
  wire[3:0]read_pixel=b-s_channel[3:0];
  always @(posedge clk)begin
   if(wr_valid)mem[{wr_page,wr_block,write_pixel}]<=wr_data[write_lane*8+:8];
   if(accept)data<=mem[{s_page,s_channel[6:4],read_pixel}];
  end
  assign banks[b*8+:8]=data;
 end
 for(p=0;p<16;p=p+1)begin:pixel
  wire[3:0]read_bank=p+channel_low;
  assign m_pixels[p*8+:8]=m_error?8'd0:banks[read_bank*8+:8];
 end endgenerate
 integer k;
 always @(posedge clk)begin
 if(!rst_n)begin for(k=0;k<16;k=k+1)filled[k]<=0;m_valid<=0;m_error<=0;channel_low<=0;packing<=0;started<=0;poisoned<=0;end
 else begin
  if(invalidate)begin
   for(k=0;k<8;k=k+1)filled[{invalidate_page,3'b000}+k]<=0;
   started[invalidate_page]<=0;poisoned[invalidate_page]<=0;
  end
  if(wr_valid&&!(invalidate&&invalidate_page==wr_page))begin
   filled[{wr_page,wr_block}][wr_pixel]<=1;packing[wr_page]<=wr_transpose;started[wr_page]<=1;
   if(started[wr_page]&&packing[wr_page]!=wr_transpose)poisoned[wr_page]<=1;
  end
  if(s_ready)begin m_valid<=s_valid;if(s_valid)begin channel_low<=s_channel[3:0];m_error<=bad;end end
 end end
endmodule
