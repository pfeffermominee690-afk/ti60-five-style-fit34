// Offline bandwidth exerciser. Copies descriptors through a 128-bit FIFO.
// No neural inference, no inference frame counter, and no video publication.
// On an AXI error the probe halts until reset; no recovery is represented as success.
module p2_transport_probe(
 input wire clk,rst_n,input wire[11:0]paddr,input wire psel,penable,pwrite,input wire[31:0]pwdata,
 output reg[31:0]prdata,output wire pready,pslverror,
 output wire[31:0]araddr,awaddr,output wire[7:0]arlen,awlen,output wire arvalid,awvalid,input wire arready,awready,
 input wire[127:0]rdata,input wire[1:0]rresp,input wire rlast,rvalid,output wire rready,
 output wire[127:0]wdata,output wire[15:0]wstrb,output wire wlast,wvalid,input wire wready,
 input wire[1:0]bresp,input wire bvalid,output wire bready
);
 reg[31:0]src,dst,beats,ticks,read_count,write_count;
 reg start,active,read_finished,write_finished,complete;
 wire rd_busy,wr_busy,rd_done,wr_done;wire[2:0]rd_error,wr_error;
 wire[127:0]sd,md;wire sv,sr,mv,mr;wire[7:0]level;
 wire access=psel&&penable;wire idle=!active&&!rd_busy&&!wr_busy&&level==0&&!mv;
 assign pready=1;assign pslverror=access&&(paddr[1:0]!=0||(pwrite&&(!idle||rd_error!=0||wr_error!=0)));
 async_fifo #(.WIDTH(128),.DEPTH(128)) fifo(.wr_clk(clk),.rd_clk(clk),.arst_n(rst_n),.s_valid(sv),.s_ready(sr),.s_data(sd),.m_valid(mv),.m_ready(mr),.m_data(md),.wr_level(),.rd_level(level));
 p2_axi_dma dma(.clk(clk),.rst_n(rst_n),.rd_start(start),.wr_start(start),.rd_address(src),.wr_address(dst),.rd_beats(beats),.wr_beats(beats),
 .rd_busy(rd_busy),.wr_busy(wr_busy),.rd_done(rd_done),.wr_done(wr_done),.rd_error(rd_error),.wr_error(wr_error),
 .out_data(sd),.out_valid(sv),.out_ready(sr),.in_data(md),.in_valid(mv),.in_ready(mr),
 .araddr(araddr),.awaddr(awaddr),.arlen(arlen),.awlen(awlen),.arvalid(arvalid),.awvalid(awvalid),.arready(arready),.awready(awready),
 .rdata(rdata),.rresp(rresp),.rlast(rlast),.rvalid(rvalid),.rready(rready),.wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready));
 always @(posedge clk)begin
 if(!rst_n)begin src<=0;dst<=0;beats<=0;start<=0;active<=0;read_finished<=0;write_finished<=0;complete<=0;ticks<=0;read_count<=0;write_count<=0;end
 else begin
 start<=0;
 if(active)begin ticks<=ticks+1;if(rd_done)read_finished<=1;if(wr_done)write_finished<=1;
 if(read_finished&&write_finished)begin active<=0;complete<=rd_error==0&&wr_error==0;end end
 if(sv&&sr)read_count<=read_count+1;if(mv&&mr)write_count<=write_count+1;
 if(access&&pwrite&&!pslverror)case(paddr[7:2])
 0:src<=pwdata;1:dst<=pwdata;2:beats<=pwdata;
 3:if(pwdata[0])begin start<=1;active<=1;read_finished<=0;write_finished<=0;complete<=0;ticks<=0;read_count<=0;write_count<=0;end
 endcase
 end end
 always @*begin
 prdata=0;case(paddr[7:2])
 0:prdata=src;1:prdata=dst;2:prdata=beats;
 3:prdata={22'd0,wr_error,rd_error,1'b0,complete,active,idle};
 4:prdata=ticks;5:prdata=read_count;6:prdata=write_count;
 7:prdata=32'h5032444d; // P2DM transport probe identifier
 endcase end
endmodule
