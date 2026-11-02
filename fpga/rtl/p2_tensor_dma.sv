// 128-bit aligned tensor DMA, independent read/write commands, one burst
// outstanding per direction. Commands count 16-byte beats. Burst splitting
// is bounded by 4KiB and 256 beats. Write completion waits for every B response.
module p2_tensor_dma(input clk,rst_n,
 input rd_start,input[31:0]rd_address,rd_beats,output rd_ready,output reg rd_done,rd_error,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 output[127:0]m_data,output m_valid,input m_ready,
 input wr_start,input[31:0]wr_address,wr_beats,output wr_ready,output reg wr_done,wr_error,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 input[127:0]s_data,input s_valid,output s_ready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,
 input[1:0]bresp,input bvalid,output bready);
 localparam IDLE=0,ADDR=1,DATA=2,RESP=3;
 reg[1:0]rs,ws;reg[31:0]ra,wa,rleft,wleft;reg[8:0]rn,wn,ri,wi;
 function automatic[8:0]burst(input[31:0]address,left);
  reg[8:0]boundary;
  begin boundary=9'd256-{1'b0,address[11:4]};burst=left<boundary?left[8:0]:boundary;end
 endfunction
 wire[36:0]rend={5'd0,rd_address}+({5'd0,rd_beats}<<4);
 wire[36:0]wend={5'd0,wr_address}+({5'd0,wr_beats}<<4);
 assign rd_ready=rs==IDLE;assign wr_ready=ws==IDLE;
 assign araddr=ra;assign arlen=rn-1'b1;assign arvalid=rs==ADDR;
 assign awaddr=wa;assign awlen=wn-1'b1;assign awvalid=ws==ADDR;
 assign m_data=rdata;assign m_valid=rs==DATA&&rvalid&&!rd_error&&rresp==0;
 assign rready=rs==DATA&&(rd_error||rresp!=0||m_ready);
 assign s_ready=ws==DATA&&wready;
 assign wdata=s_data;assign wstrb=16'hffff;assign wvalid=ws==DATA&&s_valid;assign wlast=wi==wn-1'b1;
 assign bready=ws==RESP;
 always @(posedge clk)begin
  if(!rst_n)begin rs<=IDLE;ws<=IDLE;ra<=0;wa<=0;rleft<=0;wleft<=0;rn<=0;wn<=0;ri<=0;wi<=0;rd_done<=0;wr_done<=0;rd_error<=0;wr_error<=0;end
  else begin
   rd_done<=0;wr_done<=0;
   case(rs)
    IDLE:if(rd_start)begin
     rd_error<=0;
     if(rd_address[3:0]!=0||rd_beats==0||rend>37'h100000000)begin rd_done<=1;rd_error<=1;end
     else begin ra<=rd_address;rleft<=rd_beats;rn<=burst(rd_address,rd_beats);ri<=0;rs<=ADDR;end
    end
    ADDR:if(arready)rs<=DATA;
    DATA:if(rvalid&&rready)begin
     if(rresp!=0||rlast!=(ri==rn-1'b1))rd_error<=1;
     if(rlast||ri==rn-1'b1)begin
      if(rleft==rn||rd_error||rresp!=0||rlast!=(ri==rn-1'b1))begin rs<=IDLE;rd_done<=1;end
      else begin ra<=ra+{rn,4'b0};rleft<=rleft-rn;rn<=burst(ra+{rn,4'b0},rleft-rn);ri<=0;rs<=ADDR;end
     end else ri<=ri+1'b1;
    end
   endcase
   case(ws)
    IDLE:if(wr_start)begin
     wr_error<=0;
     if(wr_address[3:0]!=0||wr_beats==0||wend>37'h100000000)begin wr_done<=1;wr_error<=1;end
     else begin wa<=wr_address;wleft<=wr_beats;wn<=burst(wr_address,wr_beats);wi<=0;ws<=ADDR;end
    end
    ADDR:if(awready)ws<=DATA;
    DATA:if(s_valid&&wready)begin if(wlast)ws<=RESP;else wi<=wi+1'b1;end
    RESP:if(bvalid)begin
     if(bresp!=0)wr_error<=1;
     if(wleft==wn||bresp!=0)begin ws<=IDLE;wr_done<=1;end
     else begin wa<=wa+{wn,4'b0};wleft<=wleft-wn;wn<=burst(wa+{wn,4'b0},wleft-wn);wi<=0;ws<=ADDR;end
    end
   endcase
  end
 end
endmodule
