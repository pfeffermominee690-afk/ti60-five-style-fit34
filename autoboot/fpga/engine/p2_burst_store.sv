// Two 2KiB pages: accumulate 128 pixels x 16 channels, then burst CHW.
// 8 independent byte banks accept one 8-pixel vector per clock.
module p2_burst_store(input clk,rst_n,
 input s_valid,output s_ready,input s_page,input[3:0]s_channel,s_group,input[63:0]s_data,input s_commit,
 input start,page,input[31:0]base,plane_pixels,tile_pixel,input[7:0]pixel_count,input[4:0]channels,
 output ready,output reg done,error,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,input[1:0]bresp,input bvalid,output bready);
 localparam IDLE=0,COMMAND=1,RUN=2,ABORT=3;
 reg[1:0]state,committed;reg pg;reg[31:0]address,stride;reg[4:0]co,ch,halves,issued;reg qvalid,qhalf,ov;
 reg[63:0]low;reg[127:0]outdata;wire[63:0]qdata;
 wire dr,dd,de,os;wire advance=!ov||os;
 wire read_en=state==RUN&&advance&&issued<halves;
 wire[8:0]ra={pg,ch[3:0],issued[3:0]},wa={s_page,s_channel,s_group};
 assign s_ready=!committed[s_page]&&(state==IDLE||s_page!=pg)&&!(start&&ready&&s_page==page);
 wire write_en=s_valid&&s_ready;
 assign ready=state==IDLE&&committed[page];
 genvar b;
 generate for(b=0;b<8;b=b+1)begin:bank
  reg[7:0]mem[0:511],q;
  always @(posedge clk)begin
   if(write_en)mem[wa]<=s_data[b*8+:8];
   if(read_en)q<=mem[ra];
  end
  assign qdata[b*8+:8]=q;
 end endgenerate
 p2_tensor_dma dma(.clk(clk),.rst_n(rst_n&&state!=ABORT),
 .rd_start(1'b0),.rd_address(32'd0),.rd_beats(32'd0),.rd_ready(),.rd_done(),.rd_error(),
 .araddr(),.arlen(),.arvalid(),.arready(1'b0),.rdata(128'd0),.rresp(2'd0),.rvalid(1'b0),.rlast(1'b0),.rready(),.m_data(),.m_valid(),.m_ready(1'b0),
 .wr_start(state==COMMAND&&dr),.wr_address(address),.wr_beats({28'd0,halves[4:1]}),.wr_ready(dr),.wr_done(dd),.wr_error(de),
 .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),.s_data(outdata),.s_valid(ov),.s_ready(os),
 .wdata(wdata),.wstrb(wstrb),.wvalid(wvalid),.wlast(wlast),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready));
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;committed<=0;pg<=0;address<=0;stride<=0;co<=0;ch<=0;halves<=0;issued<=0;qvalid<=0;qhalf<=0;ov<=0;low<=0;outdata<=0;done<=0;error<=0;end
  else begin
   done<=0;
   if(write_en&&s_commit)committed[s_page]<=1;
   case(state)
    IDLE:if(start&&ready)begin
     error<=0;
     if(base[3:0]!=0||plane_pixels[3:0]!=0||tile_pixel[3:0]!=0||pixel_count==0||pixel_count>128||pixel_count[3:0]!=0||channels==0||channels>16)begin done<=1;error<=1;end
     else begin pg<=page;address<=base+tile_pixel;stride<=plane_pixels;co<=channels;ch<=0;halves<=pixel_count>>3;issued<=0;qvalid<=0;ov<=0;state<=COMMAND;end
    end
    COMMAND:if(dr)state<=RUN;
    RUN:begin
     if(advance)begin
      qvalid<=read_en;if(read_en)begin issued<=issued+1'b1;qhalf<=issued[0];end
      ov<=qvalid&&qhalf;
      if(qvalid)begin if(qhalf)outdata<={qdata,low};else low<=qdata;end
     end
     if(dd)begin
      if(de)begin error<=1;state<=ABORT;end
      else if(ch+1==co)begin done<=1;committed[pg]<=0;state<=IDLE;end
      else begin ch<=ch+1'b1;address<=address+stride;issued<=0;qvalid<=0;ov<=0;state<=COMMAND;end
     end
    end
    ABORT:begin done<=1;committed[pg]<=0;state<=IDLE;qvalid<=0;ov<=0;end
   endcase
  end
 end
endmodule
