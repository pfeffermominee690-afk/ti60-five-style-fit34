// Fair, independent read/write arbitration. One outstanding burst per channel.
// Owner is registered before asserting address VALID and held through LAST/B.
// ID/lock/size/burst are preserved. CACHE/PROT/QOS are not carried; the top
// ties those DDR attributes to zero. No tag truncation or reordering assumed.
module axi_arbiter128 #(parameter N=3)(
 input wire clk,rst_n,
 input wire [N-1:0] s_awvalid,output reg [N-1:0] s_awready,
 input wire [N*32-1:0] s_awaddr,input wire [N*8-1:0] s_awlen,s_awid,
 input wire [N*3-1:0] s_awsize,input wire [N*2-1:0] s_awburst,
 input wire [N-1:0] s_awlock,
 input wire [N-1:0] s_wvalid,output reg [N-1:0] s_wready,
 input wire [N*128-1:0] s_wdata,input wire [N*16-1:0] s_wstrb,input wire [N-1:0] s_wlast,
 output reg [N-1:0] s_bvalid,input wire [N-1:0] s_bready,
 output wire [N*8-1:0] s_bid,output wire [N*2-1:0] s_bresp,
 input wire [N-1:0] s_arvalid,output reg [N-1:0] s_arready,
 input wire [N*32-1:0] s_araddr,input wire [N*8-1:0] s_arlen,s_arid,
 input wire [N*3-1:0] s_arsize,input wire [N*2-1:0] s_arburst,
 input wire [N-1:0] s_arlock,
 output reg [N-1:0] s_rvalid,input wire [N-1:0] s_rready,
 output wire [N*128-1:0] s_rdata,output wire [N*8-1:0] s_rid,
 output wire [N*2-1:0] s_rresp,output wire [N-1:0] s_rlast,
 output wire m_awvalid,input wire m_awready,output wire [31:0] m_awaddr,
 output wire [7:0] m_awlen,m_awid,output wire [2:0] m_awsize,
 output wire [1:0] m_awburst,output wire m_awlock,
 output wire m_wvalid,input wire m_wready,output wire [127:0] m_wdata,
 output wire [15:0] m_wstrb,output wire m_wlast,
 input wire m_bvalid,output wire m_bready,input wire [7:0] m_bid,input wire [1:0] m_bresp,
 output wire m_arvalid,input wire m_arready,output wire [31:0] m_araddr,
 output wire [7:0] m_arlen,m_arid,output wire [2:0] m_arsize,
 output wire [1:0] m_arburst,output wire m_arlock,
 input wire m_rvalid,output wire m_rready,input wire [127:0] m_rdata,
 input wire [7:0] m_rid,input wire [1:0] m_rresp,input wire m_rlast
);
 localparam IDLE=0,ADDR=1,DATA=2,RESP=3;
 reg [1:0] ws,rs;
 integer wo,ro,wp,rp,k,idx,wnext,rnext;
 always @* begin
  wnext=-1;rnext=-1;
  for(k=N-1;k>=0;k=k-1)begin
   idx=wp+k;if(idx>=N)idx=idx-N;
   if(s_awvalid[idx])wnext=idx;
   idx=rp+k;if(idx>=N)idx=idx-N;
   if(s_arvalid[idx])rnext=idx;
  end
 end
 assign m_awvalid=ws==ADDR && s_awvalid[wo];
 assign m_awaddr=s_awaddr[wo*32+:32];assign m_awlen=s_awlen[wo*8+:8];assign m_awid=s_awid[wo*8+:8];
 assign m_awsize=s_awsize[wo*3+:3];assign m_awburst=s_awburst[wo*2+:2];assign m_awlock=s_awlock[wo];
 assign m_wvalid=ws==DATA && s_wvalid[wo];assign m_wdata=s_wdata[wo*128+:128];
 assign m_wstrb=s_wstrb[wo*16+:16];assign m_wlast=s_wlast[wo];
 assign m_bready=ws==RESP && s_bready[wo];
 assign s_bid={N{m_bid}};assign s_bresp={N{m_bresp}};
 assign m_arvalid=rs==ADDR && s_arvalid[ro];
 assign m_araddr=s_araddr[ro*32+:32];assign m_arlen=s_arlen[ro*8+:8];assign m_arid=s_arid[ro*8+:8];
 assign m_arsize=s_arsize[ro*3+:3];assign m_arburst=s_arburst[ro*2+:2];assign m_arlock=s_arlock[ro];
 assign m_rready=rs==DATA && s_rready[ro];
 assign s_rdata={N{m_rdata}};assign s_rid={N{m_rid}};assign s_rresp={N{m_rresp}};assign s_rlast={N{m_rlast}};
 always @* begin
  s_awready=0;s_wready=0;s_bvalid=0;s_arready=0;s_rvalid=0;
  if(ws==ADDR)s_awready[wo]=m_awready;
  if(ws==DATA)s_wready[wo]=m_wready;
  if(ws==RESP)s_bvalid[wo]=m_bvalid;
  if(rs==ADDR)s_arready[ro]=m_arready;
  if(rs==DATA)s_rvalid[ro]=m_rvalid;
 end
 always @(posedge clk)begin
  if(!rst_n)begin ws<=IDLE;rs<=IDLE;wo<=0;ro<=0;wp<=0;rp<=0;end
  else begin
   case(ws)
    IDLE:if(wnext>=0)begin wo<=wnext;ws<=ADDR;end
    ADDR:if(m_awvalid && m_awready)ws<=DATA;
    DATA:if(m_wvalid && m_wready && m_wlast)ws<=RESP;
    RESP:if(m_bvalid && m_bready)begin ws<=IDLE;wp<=wo==N-1?0:wo+1;end
   endcase
   case(rs)
    IDLE:if(rnext>=0)begin ro<=rnext;rs<=ADDR;end
    ADDR:if(m_arvalid && m_arready)rs<=DATA;
    DATA:if(m_rvalid && m_rready && m_rlast)begin rs<=IDLE;rp<=ro==N-1?0:ro+1;end
    default:rs<=IDLE;
   endcase
  end
 end
endmodule
