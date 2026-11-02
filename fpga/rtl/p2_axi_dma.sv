// Native AXI128 streaming DMA. Independent read/write descriptors, one
// outstanding burst per direction, INCR bursts clipped at 4 KiB boundaries.
// Descriptors count 16-byte beats. Zero length or unaligned addresses reject.
// Completion follows the final R handshake / B response, not address issue.
// This is transport only, NOT a P2GAN inference engine.
module p2_axi_dma #(parameter MAX_BURST=64)(
 input wire clk,rst_n,
 input wire rd_start,wr_start,input wire [31:0] rd_address,wr_address,
 input wire [31:0] rd_beats,wr_beats,
 output wire rd_busy,wr_busy,output reg rd_done,wr_done,
 output reg [2:0] rd_error,wr_error,
 output wire [127:0] out_data,output wire out_valid,input wire out_ready,
 input wire [127:0] in_data,input wire in_valid,output wire in_ready,
 output wire [31:0] araddr,awaddr,output wire [7:0] arlen,awlen,
 output wire arvalid,awvalid,input wire arready,awready,
 input wire [127:0] rdata,input wire [1:0] rresp,input wire rlast,rvalid,
 output wire rready,output wire [127:0] wdata,output wire [15:0] wstrb,
 output wire wlast,wvalid,input wire wready,
 input wire [1:0] bresp,input wire bvalid,output wire bready
);
 localparam IDLE=0,ADDR=1,DATA=2,RESP=3;
 reg [1:0] rs,ws;
 reg [31:0] rp,wp,rl,wl;
 reg [8:0] rn,wn,ri,wi;
 function automatic [8:0] burst(input [31:0] addr,input [31:0] left);
 reg [12:0] page_bytes;reg [31:0] n;
 begin page_bytes=13'd4096-{1'b0,addr[11:0]};n=page_bytes>>4;
 if(n>MAX_BURST)n=MAX_BURST;if(n>left)n=left;burst=n[8:0];end
 endfunction
 assign rd_busy=rs!=IDLE;assign wr_busy=ws!=IDLE;
 assign araddr=rp;assign awaddr=wp;assign arlen=rn-1'b1;assign awlen=wn-1'b1;
 assign arvalid=rs==ADDR;assign awvalid=ws==ADDR;
 assign out_data=rdata;assign out_valid=rs==DATA&&rvalid;
 assign rready=rs==DATA&&out_ready;
 assign wdata=in_data;assign wstrb=16'hffff;
 assign wvalid=ws==DATA&&in_valid;assign in_ready=ws==DATA&&wready;
 assign wlast=wi==wn-1;assign bready=ws==RESP;
 always @(posedge clk)begin
 if(!rst_n)begin
 rs<=IDLE;ws<=IDLE;rp<=0;wp<=0;rl<=0;wl<=0;rn<=0;wn<=0;ri<=0;wi<=0;
 rd_done<=0;wr_done<=0;rd_error<=0;wr_error<=0;
 end else begin
 rd_done<=0;wr_done<=0;
 case(rs)
 IDLE:if(rd_start)begin
 rd_error<=0;
 if(rd_address[3:0]!=0||rd_beats==0)begin rd_error<=1;rd_done<=1;end
 else begin rp<=rd_address;rl<=rd_beats;rn<=burst(rd_address,rd_beats);ri<=0;rs<=ADDR;end
 end
 ADDR:if(arready)rs<=DATA;
 DATA:if(rvalid&&rready)begin
 if(rresp!=0)rd_error<=rd_error|2;
 if(rlast!=(ri==rn-1))rd_error<=rd_error|4|(rresp!=0?2:0);
 // AXI peer must eventually supply RLAST; malformed bursts latch an error.
 if(rlast)begin
 if(rd_error!=0||rresp!=0||ri!=rn-1||rl==rn)begin rs<=IDLE;rd_done<=1;end
 else begin rp<=rp+{rn,4'b0};rl<=rl-rn;rn<=burst(rp+{rn,4'b0},rl-rn);ri<=0;rs<=ADDR;end
 end else ri<=ri+1'b1;
 end
 endcase
 case(ws)
 IDLE:if(wr_start)begin
 wr_error<=0;
 if(wr_address[3:0]!=0||wr_beats==0)begin wr_error<=1;wr_done<=1;end
 else begin wp<=wr_address;wl<=wr_beats;wn<=burst(wr_address,wr_beats);wi<=0;ws<=ADDR;end
 end
 ADDR:if(awready)ws<=DATA;
 DATA:if(wvalid&&wready)begin if(wlast)ws<=RESP;else wi<=wi+1'b1;end
 RESP:if(bvalid)begin
 if(bresp!=0)wr_error<=wr_error|2;
 if(bresp!=0||wl==wn)begin ws<=IDLE;wr_done<=1;end
 else begin wp<=wp+{wn,4'b0};wl<=wl-wn;wn<=burst(wp+{wn,4'b0},wl-wn);wi<=0;ws<=ADDR;end
 end
 endcase
 end end
endmodule
