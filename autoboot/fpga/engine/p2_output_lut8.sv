// Exact model-specific final INT8 -> output-byte map, eight pixels per clock.
// Configure only while the network is idle; table is replicated for independent reads.
module p2_output_lut8(input clk,rst_n,input cfg_we,input[9:0]cfg_address,input[7:0]cfg_data,
 input bypass,input s_valid,output s_ready,input[1:0]s_channel,input[63:0]s_data,input[9:0]s_tag,
 output reg m_valid,input m_ready,output[63:0]m_data,output reg[9:0]m_tag);
 reg bp;reg[63:0]raw_hold;
 assign s_ready=!m_valid||m_ready;
 genvar i;generate for(i=0;i<4;i=i+1)begin:pair
 // The simulator Verilator5.020 crashes on the vendor model's zero-delay coroutine.
 // The synthesis primitive is validated with the unmodified vendor model in Icarus.
`ifdef VERILATOR
 reg[7:0]mem[0:1023],q0,q1;
 always @(posedge clk)begin
  if(cfg_we)mem[cfg_address]<=cfg_data;
  else if(s_valid&&s_ready)q0<=mem[{s_channel,s_data[(i*2)*8+:8]}];
  if(s_valid&&s_ready)q1<=mem[{s_channel,s_data[(i*2+1)*8+:8]}];
 end
`else
 wire[7:0]q0,q1;
 EFX_DPRAM10 #(.READ_WIDTH_A(8),.WRITE_WIDTH_A(8),.READ_WIDTH_B(8),.WRITE_WIDTH_B(8),.OUTPUT_REG_A(0),.OUTPUT_REG_B(0)) ram(
 .CLKA(clk),.WEA(cfg_we),.CLKEA(cfg_we||(s_valid&&s_ready)),.RSTA(1'b0),.ADDRENA(1'b1),.WDATAA(cfg_data),.ADDRA(cfg_we?cfg_address:{s_channel,s_data[(i*2)*8+:8]}),.RDATAA(q0),
 .CLKB(clk),.WEB(1'b0),.CLKEB(s_valid&&s_ready),.RSTB(1'b0),.ADDRENB(1'b1),.WDATAB(8'd0),.ADDRB({s_channel,s_data[(i*2+1)*8+:8]}),.RDATAB(q1));
`endif
 assign m_data[(i*2)*8+:8]=bp?raw_hold[(i*2)*8+:8]:q0;
 assign m_data[(i*2+1)*8+:8]=bp?raw_hold[(i*2+1)*8+:8]:q1;
 end endgenerate
 always @(posedge clk)begin
  if(!rst_n)begin m_valid<=0;m_tag<=0;bp<=0;raw_hold<=0;end
  else if(s_ready)begin m_valid<=s_valid;if(s_valid)begin m_tag<=s_tag;bp<=bypass;raw_hold<=s_data;end end
 end
endmodule


