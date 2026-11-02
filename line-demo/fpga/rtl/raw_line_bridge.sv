// Four complete RAW8 lines cross from the MIPI clock to the ISP clock.
// Producer has no backpressure: overflow discards the rest of that frame.
// A committed line is immutable until its read pointer is returned by CDC.
// Both pointer buses are Gray coded. Metadata is stable before publication.
// Output byte order matches the former little-endian 32 -> 16 DDR FIFO.
module raw_line_bridge #(parameter WORDS=480,AW=9)(
 input s_clk,m_clk,rst_n,input s_sof,s_valid,input[31:0]s_data,
 output reg o_vs,o_hs,o_de,output reg[15:0]o_data,
 output reg[31:0]dropped_frames,committed_lines,output_lines);
 reg[31:0]mem[0:(4*(1<<AW))-1];reg[3:0]sof_bank;
 reg[2:0]wp,rp,wgray,rgray;
 (* async_reg="true" *)reg[2:0]rg1,rg2,wg1,wg2;
 reg[AW-1:0]wa,ra,ri;reg pending_sof,dropping;
 wire full=wgray=={~rg2[2:1],rg2[0]};
 wire empty=rgray==wg2;
 reg[2:0]state;reg phase;reg[31:0]read_word,word_hold;
 wire[2:0]wnext=wp+1'b1,rnext=rp+1'b1;
 always @(posedge s_clk or negedge rst_n)begin
 if(!rst_n)begin wp<=0;wgray<=0;rg1<=0;rg2<=0;wa<=0;pending_sof<=0;dropping<=1;sof_bank<=0;dropped_frames<=0;committed_lines<=0;end
 else begin
 rg1<=rgray;rg2<=rg1;
 if(s_sof)begin wa<=0;pending_sof<=1;dropping<=0;end
 if(s_valid&&(!dropping||s_sof))begin
  if(full)begin dropping<=1;wa<=0;dropped_frames<=dropped_frames+1'b1;end
  else begin
   mem[{wp[1:0],(s_sof?{AW{1'b0}}:wa)}]<=s_data;
   if(s_sof||wa==0)sof_bank[wp[1:0]]<=s_sof||pending_sof;
   pending_sof<=0;
   if(!s_sof&&wa==WORDS-1)begin wa<=0;wp<=wnext;wgray<=(wnext>>1)^wnext;committed_lines<=committed_lines+1'b1;end
   else wa<=s_sof?1:wa+1'b1;
  end
 end
 end end
 // Synchronous read port; addresses are prefetched one word ahead so DE
 // remains continuous for all 960 two-pixel beats in a 1920-pixel line.
 always @(posedge m_clk)read_word<=mem[{rp[1:0],ra}];
 always @(posedge m_clk or negedge rst_n)begin
 if(!rst_n)begin rp<=0;rgray<=0;wg1<=0;wg2<=0;ra<=0;ri<=0;state<=0;phase<=0;word_hold<=0;o_vs<=0;o_hs<=0;o_de<=0;o_data<=0;output_lines<=0;end
 else begin
 wg1<=wgray;wg2<=wg1;o_de<=0;o_hs<=0;o_vs<=0;
 case(state)
 0:if(!empty)begin ra<=0;ri<=0;phase<=0;o_vs<=sof_bank[rp[1:0]];state<=1;end
 1:begin o_vs<=sof_bank[rp[1:0]];state<=2;end
 2:begin word_hold<=read_word;ra<=1;state<=3;end
 3:begin
  o_de<=1;o_hs<=1;phase<=!phase;
  if(!phase)o_data<=word_hold[15:0];
  else begin
   o_data<=word_hold[31:16];word_hold<=read_word;ra<=ra+1'b1;ri<=ri+1'b1;
   if(ri==WORDS-1)begin rp<=rnext;rgray<=(rnext>>1)^rnext;state<=0;ra<=0;output_lines<=output_lines+1'b1;end
  end
 end
 default:state<=0;
 endcase
 end end
endmodule
