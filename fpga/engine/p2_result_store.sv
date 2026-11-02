// Two 2KiB pages: accumulate 128 pixels x 16 channels, then burst CHW.
// 8 independent byte banks accept one 8-pixel vector per clock.
module p2_result_store(input clk,rst_n,
 input s_valid,output s_ready,input s_page,input[3:0]s_channel,s_group,input[63:0]s_data,input s_commit,
 input start,page,rgb_mode,input[31:0]base,plane_pixels,tile_pixel,input[7:0]pixel_count,input[4:0]channels,
 output ready,output reg done,error,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,input[1:0]bresp,input bvalid,output bready);
 localparam IDLE=0,COMMAND=1,RUN=2,ABORT=3;
 reg[1:0]state,committed;reg pg,rgb,offset8,qlast,qfirst;reg[15:0]outstrb;reg[1:0]rgb_read,rgb_chunk;reg[4:0]rgb_group;reg[63:0]red,green;reg[191:0]rgb_bits;reg rgb_collect,rgb_emit;reg rgb_half;reg[31:0]address,stride;reg[4:0]co,ch,halves,issued;reg qvalid,qhalf,ov;
 reg[63:0]low;reg[127:0]outdata;wire[63:0]qdata;
 wire dr,dd,de,os;wire advance=!ov||os;
 wire read_en=state==RUN&&(rgb?(rgb_collect&&rgb_read<3):(advance&&issued<halves));
 wire[8:0]ra=rgb?{pg,2'd0,rgb_read,rgb_group[3:0]}:{pg,ch[3:0],issued[3:0]},wa={s_page,s_channel,s_group};
 assign s_ready=!committed[s_page]&&(state==IDLE||s_page!=pg)&&!(start&&ready&&s_page==page);
 wire write_en=s_valid&&s_ready;
 assign wstrb=outstrb;
 assign ready=state==IDLE&&committed[page];
 wire[191:0]interleaved;
 genvar z;generate for(z=0;z<8;z=z+1)begin:interleave
 // Model channel order is retained: byte0=channel0, byte1=channel1, byte2=channel2.
 assign interleaved[z*24+:24]={qdata[z*8+:8],green[z*8+:8],red[z*8+:8]};
 end endgenerate
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
 .wr_start(state==COMMAND&&dr),.wr_address(address),.wr_beats(rgb?({27'd0,halves}*3)>>1:({27'd0,halves}+offset8+1)>>1),.wr_ready(dr),.wr_done(dd),.wr_error(de),
 .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),.s_data(outdata),.s_valid(ov),.s_ready(os),
 .wdata(wdata),.wstrb(),.wvalid(wvalid),.wlast(wlast),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready));
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;committed<=0;pg<=0;rgb<=0;offset8<=0;qlast<=0;qfirst<=0;outstrb<=16'hffff;rgb_read<=0;rgb_chunk<=0;rgb_group<=0;red<=0;green<=0;rgb_bits<=0;rgb_collect<=0;rgb_emit<=0;rgb_half<=0;address<=0;stride<=0;co<=0;ch<=0;halves<=0;issued<=0;qvalid<=0;qhalf<=0;ov<=0;low<=0;outdata<=0;done<=0;error<=0;end
  else begin
   done<=0;
   if(write_en&&s_commit)committed[s_page]<=1;
   case(state)
    IDLE:if(start&&ready)begin
     error<=0;
     if(base[3:0]!=0||plane_pixels[3:0]!=0||tile_pixel[2:0]!=0||pixel_count==0||pixel_count>128||pixel_count[2:0]!=0||channels==0||channels>16||(rgb_mode&&(channels!=3||tile_pixel[3]||pixel_count[3])))begin done<=1;error<=1;end
     else begin pg<=page;rgb<=rgb_mode;offset8<=tile_pixel[3];outstrb<=16'hffff;rgb_read<=0;rgb_chunk<=0;rgb_group<=0;rgb_collect<=rgb_mode;rgb_emit<=0;rgb_half<=0;address<=base+(rgb_mode?tile_pixel*3:{tile_pixel[31:4],4'd0});stride<=plane_pixels;co<=channels;ch<=0;halves<=pixel_count>>3;issued<=0;qvalid<=0;ov<=0;state<=COMMAND;end
    end
    COMMAND:if(dr)state<=RUN;
    RUN:begin
     if(!rgb&&advance)begin
      qvalid<=read_en;if(read_en)begin issued<=issued+1'b1;qhalf<=issued[0]^offset8;qlast<=issued+1==halves;qfirst<=issued==0;end
      ov<=qvalid&&(qhalf||qlast);
      if(qvalid)begin
       if(qhalf)begin outdata<={qdata,low};outstrb<=offset8&&qfirst?16'hff00:16'hffff;end
       else if(qlast)begin outdata<={64'd0,qdata};outstrb<=16'h00ff;end
       else low<=qdata;
      end
     end
     if(rgb)begin
      qvalid<=read_en;
      if(read_en)rgb_read<=rgb_read+1'b1;
      if(qvalid)begin
       case(rgb_read)
        1:red<=qdata;
        2:green<=qdata;
        3:begin rgb_bits<=interleaved;rgb_collect<=0;rgb_emit<=1;rgb_chunk<=0;end
       endcase
      end
      if(advance)begin
       ov<=0;
       if(rgb_emit)begin
        if(rgb_half)begin outdata<={rgb_bits[63:0],low};ov<=1;end else low<=rgb_bits[63:0];
        rgb_half<=!rgb_half;rgb_bits<=rgb_bits>>64;
        if(rgb_chunk==2)begin
         rgb_emit<=0;rgb_group<=rgb_group+1'b1;rgb_read<=0;
         if(rgb_group+1<halves)rgb_collect<=1;
        end else rgb_chunk<=rgb_chunk+1'b1;
       end
      end
     end
     if(dd)begin
      if(de)begin error<=1;state<=ABORT;end
      else if(rgb||ch+1==co)begin done<=1;committed[pg]<=0;state<=IDLE;end
      else begin ch<=ch+1'b1;address<=address+stride;issued<=0;qvalid<=0;ov<=0;state<=COMMAND;end
     end
    end
    ABORT:begin done<=1;committed[pg]<=0;state<=IDLE;qvalid<=0;ov<=0;end
   endcase
  end
 end
endmodule
