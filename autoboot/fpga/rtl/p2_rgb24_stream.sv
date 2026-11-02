// Byte-exact RGB24 stream packing. Frame pixel count must be divisible by 16.
module p2_rgb24_pack(input clk,rst_n,clear,input[23:0]s_data,input s_valid,output s_ready,
 output[127:0]m_data,output m_valid,input m_ready);
 reg[151:0]bits;reg[7:0]count;reg[151:0]next_bits;reg[7:0]next_count;
 assign m_valid=count>=128;assign m_data=bits[127:0];
 assign s_ready=count<=128||(m_valid&&m_ready);
 always @*begin
 next_bits=bits;next_count=count;
 if(m_valid&&m_ready)begin next_bits=bits>>128;next_count=count-128;end
 if(s_valid&&s_ready)begin next_bits=next_bits|({128'd0,s_data}<<next_count);next_count=next_count+24;end
 end
 always @(posedge clk)if(!rst_n||clear)begin bits<=0;count<=0;end else begin bits<=next_bits;count<=next_count;end
endmodule
module p2_rgb24_unpack(input clk,rst_n,clear,input[127:0]s_data,input s_valid,output s_ready,
 output[23:0]m_data,output m_valid,input m_ready);
 reg[151:0]bits;reg[7:0]count;reg[151:0]next_bits;reg[7:0]next_count;
 assign m_valid=count>=24;assign m_data=bits[23:0];
 assign s_ready=count<24||(m_valid&&m_ready&&count<48);
 always @*begin
 next_bits=bits;next_count=count;
 if(m_valid&&m_ready)begin next_bits=bits>>24;next_count=count-24;end
 if(s_valid&&s_ready)begin next_bits=next_bits|({24'd0,s_data}<<next_count);next_count=next_count+128;end
 end
 always @(posedge clk)if(!rst_n||clear)begin bits<=0;count<=0;end else begin bits<=next_bits;count<=next_count;end
endmodule
