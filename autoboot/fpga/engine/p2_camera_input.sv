// RGB/BGR 640x480 right-half crop -> signed INT8 CHW, using the shared result SRAM.
// q = round((2*p/255-1)*64) = ceil(p/2)-64 exactly for all 256 input codes.
module p2_camera_input(input clk,rst_n,start,input crop,input[31:0]source_base,output_base,
 output ready,output reg done,error,
 output inject_valid,input inject_ready,output inject_page,inject_commit,output[3:0]inject_channel,inject_group,output[63:0]inject_data,
 output store_start,store_page,output[31:0]store_base,store_pixel,output[7:0]store_count,input store_ready,store_done,store_error,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready);
 localparam IDLE=0,CMD=1,RUN=2,STORE=3,NEXT=4,DRAIN=5;
 reg[2:0]state;reg[31:0]row_address;reg[9:0]x,y;reg[7:0]count,pixel;reg page,wb;
 reg[383:0]pixels;reg[1:0]beat,channel;reg half,full,read_finished;
 wire dr,dd,de,dv;wire[127:0]data;
 assign ready=state==IDLE;assign inject_valid=state==RUN&&full;
 assign inject_page=page;assign inject_channel={2'd0,channel};assign inject_group=pixel[6:3]+half;
 assign inject_commit=channel==2&&half&&pixel+16==count;
 assign store_start=state==STORE&&store_ready;assign store_page=page;assign store_base=output_base;
 assign store_pixel=(y<<8)+(y<<6)+x;assign store_count=count;
 genvar i;generate for(i=0;i<8;i=i+1)begin:quant
 wire[7:0]p=pixels[((i+half*8)*3+channel)*8+:8];
 assign inject_data[i*8+:8]={1'b0,p[7:1]}+p[0]-8'd64;
 end endgenerate
 p2_tensor_dma dma(.clk(clk),.rst_n(rst_n),.rd_start(state==CMD&&dr),.rd_address(row_address+(x<<1)+x),.rd_beats(count==128?32'd24:32'd12),.rd_ready(dr),.rd_done(dd),.rd_error(de),
 .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rvalid(rvalid),.rlast(rlast),.rready(rready),.m_data(data),.m_valid(dv),.m_ready(state==RUN&&!full),
 .wr_start(1'b0),.wr_address(32'd0),.wr_beats(32'd0),.wr_ready(),.wr_done(),.wr_error(),.awaddr(),.awlen(),.awvalid(),.awready(1'b0),.s_data(128'd0),.s_valid(1'b0),.s_ready(),.wdata(),.wstrb(),.wvalid(),.wlast(),.wready(1'b0),.bresp(2'd0),.bvalid(1'b0),.bready());
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;done<=0;error<=0;row_address<=0;x<=0;y<=0;count<=0;pixel<=0;page<=0;wb<=0;pixels<=0;beat<=0;channel<=0;half<=0;full<=0;read_finished<=0;end
  else begin
   done<=0;if(store_start)wb<=1;else if(store_done)wb<=0;
   if(dd)begin read_finished<=1;if(de)error<=1;end
   if(dv&&state==RUN&&!full)begin
    pixels[beat*128+:128]<=data;if(beat==2)begin full<=1;beat<=0;end else beat<=beat+1'b1;
   end
   if(inject_valid&&inject_ready)begin
    if(!half)half<=1;
    else begin half<=0;if(channel==2)begin channel<=0;full<=0;pixel<=pixel+16;end else channel<=channel+1'b1;end
   end
   case(state)
    IDLE:if(start)begin error<=0;row_address<=source_base+(crop?960:0);x<=0;y<=0;count<=128;pixel<=0;page<=0;beat<=0;channel<=0;half<=0;full<=0;state<=CMD;end
    CMD:if(dr)begin read_finished<=0;state<=RUN;end
    RUN:if(read_finished&&!full&&pixel==count)state<=STORE;
    STORE:if(store_start)begin page<=!page;state<=NEXT;end
    NEXT:begin pixel<=0;if(x+count==320)begin
      if(y==479)state<=DRAIN;
      else begin y<=y+1'b1;x<=0;count<=128;row_address<=row_address+(crop?1920:960);state<=CMD;end
     end else begin x<=x+count;count<=x==0?128:64;state<=CMD;end
    end
    DRAIN:if(!wb)begin done<=1;state<=IDLE;end
   endcase
   if(store_done&&store_error)error<=1;
  end
 end
endmodule
