// Dual-clock queue with Gray pointers and registered read prefetch.
// Depth is a power of two. Reset must assert both domains; each domain releases
// reset through its own two-flop synchronizer. No independently reset endpoints.
module async_fifo #(parameter WIDTH=128,DEPTH=512,AW=$clog2(DEPTH))(
 input wire wr_clk,rd_clk,arst_n,
 input wire s_valid,output wire s_ready,input wire [WIDTH-1:0] s_data,
 output reg m_valid,input wire m_ready,output reg [WIDTH-1:0] m_data,
 output wire [AW:0] wr_level,rd_level
);
 reg [1:0] wr_rst,rd_rst;
 always @(posedge wr_clk or negedge arst_n)
  if(!arst_n)wr_rst<=0;else wr_rst<={wr_rst[0],1'b1};
 always @(posedge rd_clk or negedge arst_n)
  if(!arst_n)rd_rst<=0;else rd_rst<={rd_rst[0],1'b1};
 reg [WIDTH-1:0] mem[0:DEPTH-1];
 reg [AW:0] wb,wg,rb,rg;
 (* async_reg="true" *) reg [AW:0] rg1,rg2,wg1,wg2;
 reg full;
 wire push=s_valid && s_ready;
 wire [AW:0] wb_next=wb+push,wg_next=(wb_next>>1)^wb_next;
 wire empty=rg==wg2;
 wire fetch=rd_rst[1] && (!m_valid || m_ready) && !empty;
 wire [AW:0] rb_next=rb+1'b1;
 assign s_ready=wr_rst[1] && !full;
 function automatic [AW:0] gray_to_bin(input [AW:0] g);
  integer k;begin gray_to_bin[AW]=g[AW];for(k=AW-1;k>=0;k=k-1)gray_to_bin[k]=gray_to_bin[k+1]^g[k];end
 endfunction
 assign wr_level=wb-gray_to_bin(rg2);
 assign rd_level=gray_to_bin(wg2)-rb+m_valid;
 always @(posedge wr_clk) begin
  if(push)mem[wb[AW-1:0]]<=s_data;
  if(!wr_rst[1])begin wb<=0;wg<=0;rg1<=0;rg2<=0;full<=0;end
  else begin
   rg1<=rg;rg2<=rg1;wb<=wb_next;wg<=wg_next;
   full<=wg_next=={~rg2[AW:AW-1],rg2[AW-2:0]};
  end
 end
 always @(posedge rd_clk) begin
  if(!rd_rst[1])begin rb<=0;rg<=0;wg1<=0;wg2<=0;m_valid<=0;m_data<=0;end
  else begin
   wg1<=wg;wg2<=wg1;
   if(fetch)begin
    m_data<=mem[rb[AW-1:0]];m_valid<=1;rb<=rb_next;rg<=(rb_next>>1)^rb_next;
   end else if(m_ready)m_valid<=0;
  end
 end
endmodule
