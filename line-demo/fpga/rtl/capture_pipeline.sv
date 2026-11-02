module capture_pipeline(
 input wire clk,pclk,capture_pclk,mipi_clk,rst_n,mipi_vs,mipi_de,
 input wire [11:0] paddr,input wire psel,penable,pwrite,
 input wire [31:0] pwdata,output wire [31:0] prdata,output wire pready,pslverror,
 input wire [31:0] cnn_frames,raw_drops,
 input wire i_de,i_hs,i_vs,input wire [23:0] i_rgb,
 output wire o_de,o_hs,o_vs,output wire [23:0] o_rgb,
 output wire [31:0] awaddr,araddr,output wire [7:0] awlen,arlen,
 output wire awvalid,arvalid,input wire awready,arready,
 output wire [127:0] wdata,output wire [15:0] wstrb,output wire wvalid,wlast,input wire wready,
 input wire [1:0] bresp,input wire bvalid,output wire bready,
 input wire [127:0] rdata,input wire [1:0] rresp,input wire rvalid,rlast,output wire rready,
 output wire [31:0] capture_frames,read_frames,underflows,read_errors,front_job,measured_fps,mipi_markers);
 wire start,ready,busy,done,publish,pending,front_valid,ack;
 wire[31:0]capture_address,capture_error,capture_id,input_address,result_address,job_id;
 wire[31:0]control_data,osd_data;wire control_ready,control_error,osd_error;
 wire[31:0]rgb_frames,idle_drops,raw_drop_sync;wire[127:0]hash;
 wire select_control=paddr<12'h080,select_osd=paddr>=12'h3fc;
 reg[31:0]errors,sticky,ticks,seconds,input_previous,cap_previous,input_fps,cap_fps;
 reg[8:0]line_config;
 always @(posedge clk)if(!rst_n)line_config<=0;
 else if(psel&&penable&&pwrite&&paddr==12'h0c0&&!busy)line_config<=pwdata[8:0];
 wire[31:0]dummy_fps;
 video_control control(.clk(clk),.rst_n(rst_n),.paddr(paddr),.psel(psel&&select_control),
  .penable(penable),.pwrite(pwrite),.pwdata(pwdata),.prdata(control_data),.pready(control_ready),.pslverror(control_error),
  .capture_start(start),.capture_address(capture_address),.capture_ready(ready),.capture_busy(busy),.capture_done(done),
  .capture_error(capture_error),.capture_id(capture_id),.capture_frames(capture_frames),.publish(publish),
  .input_address(input_address),.result_address(result_address),.job_id(job_id),.pending(pending),.front_valid(front_valid),
  .ack(ack),.front_job(front_job),.read_errors(read_errors),.read_frames(read_frames),.underflows(underflows),
  .cnn_frames(32'd0),.mipi_markers(mipi_markers),.measured_fps(dummy_fps));
 rgb_capture640 capture(.clk(clk),.pclk(capture_pclk),.rst_n(rst_n),.start(start),.address(capture_address),
  .ready(ready),.busy(busy),.done(done),.error(capture_error),.frame_id(capture_id),.completed_frames(capture_frames),
  .input_frames(rgb_frames),.idle_drops(idle_drops),.completed_hash(hash),.line_mode(line_config[8]),.line_threshold(line_config[7:0]),
  .i_de(i_de),.i_vs(i_vs),.i_r(i_rgb[7:0]),.i_g(i_rgb[15:8]),.i_b(i_rgb[23:16]),
  .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),.wdata(wdata),.wstrb(wstrb),
  .wlast(wlast),.wvalid(wvalid),.wready(wready),.bresp(bresp),.bvalid(bvalid),.bready(bready));
 reg mv_d;reg[31:0]input_count,words,size_errors;reg seen_frame;
 wire[31:0]size_errors_sync;
 always @(posedge mipi_clk)if(!rst_n)begin mv_d<=0;input_count<=0;words<=0;size_errors<=0;seen_frame<=0;end
 else begin
  mv_d<=mipi_vs;
  if(mipi_vs&&!mv_d)begin
   input_count<=input_count+1;words<=mipi_de?1:0;seen_frame<=1;
   if(seen_frame&&words!=518400)size_errors<=size_errors+1;
  end else if(mipi_de)words<=words+1;
 end
 capture_gray_counter size_count(.sclk(mipi_clk),.dclk(clk),.rst_n(rst_n),.value(size_errors),.result(size_errors_sync));
 capture_gray_counter mipi_count(.sclk(mipi_clk),.dclk(clk),.rst_n(rst_n),.value(input_count),.result(mipi_markers));
 capture_gray_counter raw_count(.sclk(mipi_clk),.dclk(clk),.rst_n(rst_n),.value(raw_drops),.result(raw_drop_sync));
 always @(posedge clk)begin
  if(!rst_n)begin errors<=0;sticky<=0;ticks<=0;seconds<=0;input_previous<=0;cap_previous<=0;input_fps<=0;cap_fps<=0;end
  else begin
   if(done&&capture_error!=0)begin errors<=errors+1;sticky<=sticky|capture_error;end
   if(ticks==99999999)begin
    ticks<=0;seconds<=seconds+1;input_fps<=mipi_markers-input_previous;cap_fps<=capture_frames-cap_previous;
    input_previous<=mipi_markers;cap_previous<=capture_frames;
   end else ticks<=ticks+1;
  end
 end
 assign measured_fps=cap_fps;
 reg[31:0]stats;
 always @*begin
  stats=0;
  case(paddr)
   'h080:stats=rgb_frames;'h084:stats=idle_drops;'h088:stats=raw_drop_sync;'h08c:stats=errors;
   'h090:stats=input_fps;'h094:stats=cap_fps;'h098:stats=32'h028001e0;'h09c:stats=seconds;
   'h0a0:stats=hash[31:0];'h0a4:stats=hash[63:32];'h0a8:stats=hash[95:64];'h0ac:stats=hash[127:96];
   'h0b0:stats=sticky;'h0b4:stats=size_errors_sync;'h0c0:stats={23'd0,line_config};
  endcase
 end
 assign prdata=select_control?(paddr==12'h044 ? cap_fps:control_data):select_osd?osd_data:stats;
 assign pready=1;
 assign pslverror=select_control?control_error:select_osd?osd_error:psel&&penable&&
  (paddr==12'h0c0 ? (pwrite&&(busy||pwdata[31:9]!=0)) : (pwrite||paddr[1:0]!=0||paddr<'h080||paddr>'h0b4));
 wire dde,dhs,dvs,pde,phs,pvs;wire[23:0]rgb;wire[11:0]x,y;
 vga_gen #(.H_SyncPulse(40),.H_BackPorch(220),.H_ActivePix(1280),.H_FrontPorch(110),
  .V_SyncPulse(5),.V_BackPorch(20),.V_ActivePix(720),.V_FrontPorch(5)) timing(
  .in_pclk(pclk),.in_rstn(rst_n),.out_x(),.out_y(),.out_valid(),.out_de(dde),.out_hs(dhs),.out_vs(dvs));
 rgb_pair_display #(.SOURCE_WIDTH(1280),.PANEL_WIDTH(320),.ORIGINAL_PITCH(1920),.RESULT_PITCH(1920),
  .LEFT_X(0),.RIGHT_X(640),.TOP_Y(0),.SCALE_3_2(1),.SCALE_X_2(1)) display(
  .clk(clk),.pclk(pclk),.rst_n(rst_n),.publish(publish),.input_address(input_address),.result_address(result_address),
  .job_id(job_id),.pending(pending),.front_valid(front_valid),.ack(ack),.front_job(front_job),
  .read_errors(read_errors),.read_frames(read_frames),.underflows(underflows),
  .i_de(dde),.i_hs(dhs),.i_vs(dvs),.o_de(pde),.o_hs(phs),.o_vs(pvs),.o_rgb(rgb),.o_x(x),.o_y(y),
  .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),.rdata(rdata),.rresp(rresp),.rlast(rlast),.rvalid(rvalid),.rready(rready));
 capture_osd osd(.clk(clk),.pclk(pclk),.rst_n(rst_n),.psel(psel&&select_osd),.penable(penable),.pwrite(pwrite),
  .paddr(paddr),.pwdata(pwdata),.prdata(osd_data),.error(osd_error),.x(x),.y(y),.de(pde),.hs(phs),.vs(pvs),.rgb(rgb),
  .out_de(o_de),.out_hs(o_hs),.out_vs(o_vs),.out_rgb(o_rgb));
endmodule
