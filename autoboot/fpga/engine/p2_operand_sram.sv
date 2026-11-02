// 64 independently addressed byte banks, 512 words each (32KiB logical).
// PW: bank={pixel_lane[3:0],channel[1:0]}, address={page,spatial_block,channel[6:2]}.
// DW: same banks hold four channels of a three-row rolling window.
// One 64-byte synchronous read per accepted cycle; no byte request FSM.
// Read responses are elastic. Write-first bypass makes same-address collision
// deterministic; integration still must protect active tile/page ownership.
module p2_operand_sram #(parameter WRITE_FORWARD=1, COMPACT_ADDRESS=0)(input clk,rst_n,
 input[63:0]write_enable,input[575:0]write_address,input[511:0]write_data,
 input s_valid,output s_ready,input[575:0]read_address,
 output reg m_valid,input m_ready,output[511:0]read_data);
 wire advance=!m_valid||m_ready;wire[63:0]collisions;
 wire blocked=!WRITE_FORWARD&&(|collisions);assign s_ready=advance&&!blocked;
 wire same_base=write_address[8:0]==read_address[8:0];
 wire same_next=write_address[8:0]==read_address[17:9];
 genvar b;
 generate for(b=0;b<64;b=b+1)begin:bank
  reg[7:0]mem[0:511];reg[7:0]q;
  wire[8:0]wa=write_address[b*9+:9],ra=COMPACT_ADDRESS?(read_address[18+b]?read_address[17:9]:read_address[8:0]):read_address[b*9+:9];
  assign collisions[b]=write_enable[b]&&(COMPACT_ADDRESS?(read_address[18+b]?same_next:same_base):(wa==ra));
  // synthesis translate_off
  always @(posedge clk)if(rst_n&&COMPACT_ADDRESS&&write_enable[b]&&wa!=write_address[8:0])$fatal(1,"compact SRAM requires common write address");
  // synthesis translate_on
  always @(posedge clk)begin
   if(write_enable[b])mem[wa]<=write_data[b*8+:8];
   if(s_valid&&s_ready)begin
    q<=mem[ra];
   end
  end
  if(WRITE_FORWARD)begin:forwarding
   reg[7:0]forward_data;reg forward;
   always @(posedge clk)if(s_valid&&s_ready)begin forward<=write_enable[b]&&wa==ra;forward_data<=write_data[b*8+:8];end
   assign read_data[b*8+:8]=forward?forward_data:q;
  end else begin:protected_ownership
   assign read_data[b*8+:8]=q;
   // A coincident write delays the read by one cycle; no forwarding data registers.
   // Verify that ownership contract on every accepted read in simulation.
   // synthesis translate_off
   always @(posedge clk)if(rst_n&&s_valid&&s_ready&&write_enable[b]&&wa==ra)$fatal(1,"operand SRAM ownership collision bank%0d address%0d",b,ra);
   // synthesis translate_on
  end
 end endgenerate
 always @(posedge clk)begin
  if(!rst_n)m_valid<=0;
  else if(advance)m_valid<=s_valid&&!blocked;
 end
endmodule
