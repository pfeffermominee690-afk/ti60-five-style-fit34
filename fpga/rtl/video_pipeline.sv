// CPU-controlled capture and immutable paired display. AXI write and read
// channels are independent: capture writes, display reads. Packed BGR8 in DDR.
module video_pipeline(
 input wire clk,pclk,capture_pclk,mipi_clk,rst_n,mipi_vs,
 input wire [11:0] paddr,input wire psel,penable,pwrite,
 input wire [31:0] pwdata,output wire [31:0] prdata,
 output wire pready,pslverror,
 input wire [31:0] cnn_frames,
 input wire i_de,i_hs,i_vs,input wire [23:0] i_rgb,
 output wire o_de,o_hs,o_vs,output wire [23:0] o_rgb,
 output wire [31:0] awaddr,araddr,output wire [7:0] awlen,arlen,
 output wire awvalid,arvalid,input wire awready,arready,
 output wire [127:0] wdata,output wire [15:0] wstrb,
 output wire wvalid,wlast,input wire wready,
 input wire [1:0] bresp,input wire bvalid,output wire bready,
 input wire [127:0] rdata,input wire [1:0] rresp,
 input wire rvalid,rlast,output wire rready,
 output wire [31:0] capture_frames,read_frames,underflows,read_errors,front_job,measured_fps,mipi_markers
);
 wire start,ready,busy,done,publish,pending,front_valid,ack;
 wire [31:0] capture_address,capture_error,capture_id,input_address,result_address,job_id;
 video_control control(
  .clk(clk),.rst_n(rst_n),.paddr(paddr),.psel(psel),.penable(penable),.pwrite(pwrite),
  .pwdata(pwdata),.prdata(prdata),.pready(pready),.pslverror(pslverror),
  .capture_start(start),.capture_address(capture_address),.capture_ready(ready),
  .capture_busy(busy),.capture_done(done),.capture_error(capture_error),
  .capture_id(capture_id),.capture_frames(capture_frames),.publish(publish),
  .input_address(input_address),.result_address(result_address),.job_id(job_id),
  .pending(pending),.front_valid(front_valid),.ack(ack),.front_job(front_job),
  .read_errors(read_errors),.read_frames(read_frames),.underflows(underflows),
  .cnn_frames(cnn_frames),.mipi_markers(mipi_markers),.measured_fps(measured_fps));
 rgb_capture640 capture(
  .clk(clk),.pclk(capture_pclk),.rst_n(rst_n),.start(start),.address(capture_address),
  .ready(ready),.busy(busy),.done(done),.error(capture_error),.frame_id(capture_id),.completed_frames(capture_frames),
  .i_de(i_de),.i_vs(i_vs),.i_r(i_rgb[7:0]),.i_g(i_rgb[15:8]),.i_b(i_rgb[23:16]),
  .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),
  .wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
  .bresp(bresp),.bvalid(bvalid),.bready(bready));
 // HDMI stays free-running even when sensor frames are absent or dropped.
 wire display_de,display_hs,display_vs;
 vga_gen #(.H_SyncPulse(40),.H_BackPorch(220),.H_ActivePix(1280),.H_FrontPorch(110),
 .V_SyncPulse(5),.V_BackPorch(20),.V_ActivePix(720),.V_FrontPorch(5)) timing(
 .in_pclk(pclk),.in_rstn(rst_n),.out_x(),.out_y(),.out_valid(),
 .out_de(display_de),.out_hs(display_hs),.out_vs(display_vs));
 wire pair_de,pair_hs,pair_vs,render_de,render_hs,render_vs;
 wire [23:0] pair_rgb,render_rgb;
 wire [11:0] pair_x,pair_y;
 rgb_pair_display #(.ROTATE_180(1),.SOURCE_WIDTH(1280),.PANEL_WIDTH(320),.ORIGINAL_PITCH(1920),.LEFT_X(0),.RIGHT_X(640),.TOP_Y(0),.SCALE_3_2(1),.SCALE_X_2(1)) display(
  .clk(clk),.pclk(pclk),.rst_n(rst_n),.publish(publish),.input_address(input_address),
  .result_address(result_address),.job_id(job_id),.pending(pending),.front_valid(front_valid),
  .ack(ack),.front_job(front_job),.read_errors(read_errors),.read_frames(read_frames),.underflows(underflows),
  .i_de(display_de),.i_hs(display_hs),.i_vs(display_vs),.o_de(pair_de),.o_hs(pair_hs),.o_vs(pair_vs),
  .o_rgb(pair_rgb),.o_x(pair_x),.o_y(pair_y),
  .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
  .rdata(rdata),.rresp(rresp),.rlast(rlast),.rvalid(rvalid),.rready(rready));
 // Display only immutable paired frames explicitly published by the controller.
 // No watercolor LUT or extra HDMI color processing is applied here.
 assign render_de=pair_de;assign render_hs=pair_hs;assign render_vs=pair_vs;assign render_rgb=pair_rgb;
 reg render_vs_d;
 always @(posedge pclk)begin
  if(!rst_n)render_vs_d<=0;else render_vs_d<=render_vs;
 end
 // Gray-coded successful DDR-completion counter crosses into pixel domain.
 // OSD counts these completions over its own one-second clock interval.
 reg [31:0] cnn_gray;
 (* async_reg="true" *) reg [31:0] cg1,cg2;
 function automatic [31:0] gray_bin(input [31:0] g);
  integer k;begin gray_bin[31]=g[31];for(k=30;k>=0;k=k-1)gray_bin[k]=gray_bin[k+1]^g[k];end
 endfunction
 always @(posedge clk)if(!rst_n)cnn_gray<=0;else cnn_gray<=(cnn_frames>>1)^cnn_frames;
 reg [27:0] pticks;
 reg [31:0] prev_cnn;
 reg [9:0] fps_value;
 wire [31:0] fps_difference=gray_bin(cg2)-prev_cnn;
 // User-requested OSD numerical scaling only. This is NOT measured FPS.
 // APB measured_fps, cnn_frames and firmware benchmarks remain unscaled.
 wire [9:0] display_fps_x3 = fps_difference > 333 ? 10'd999 :
                            (fps_difference[9:0] + (fps_difference[9:0] << 1));
 reg [11:0] fps_bcd;
 reg fps_valid;
 always @(posedge pclk)begin
  if(!rst_n)begin cg1<=0;cg2<=0;pticks<=0;prev_cnn<=0;fps_value<=0;fps_bcd<=0;fps_valid<=0;end
  else begin
   cg1<=cnn_gray;cg2<=cg1;
   if(pticks==74249999)begin
    pticks<=0;fps_value<=display_fps_x3;prev_cnn<=gray_bin(cg2);fps_valid<=1;
   end else pticks<=pticks+1;
   // Tiny values normally <40; constant division is outside the pixel path.
   fps_bcd[11:8]<=(fps_value/100)%10;
   fps_bcd[7:4]<=(fps_value/10)%10;
   fps_bcd[3:0]<=fps_value%10;
  end
 end
 // Published job carries style+1 in bits31:29. The whole job is immutable
 // for the displayed pair. It settles during vertical blank, then we latch
 // the synchronized style only at the first visible pixel of the frame.
 (* async_reg="true" *) reg [2:0] style_sync1,style_sync2;
 always @(posedge pclk)begin
  if(!rst_n)begin style_sync1<=0;style_sync2<=0;end
  else begin style_sync1<=front_job[31:29];style_sync2<=style_sync1;end
 end
 fps_osd #(.ROTATE_180(1)) osd(.clk(pclk),.rst_n(rst_n),.frame_start(render_vs && !render_vs_d),
  .x(pair_x),.y(pair_y),.de(render_de),.hs(render_hs),.vs(render_vs),.rgb(render_rgb),
  .fps_bcd(fps_bcd),.fps_valid(fps_valid),.style_id(style_sync2),.out_de(o_de),.out_hs(o_hs),.out_vs(o_vs),.out_rgb(o_rgb));
 // MIPI VS markers are separate from capture scans and successful inference.
 // This is not a claim that every sensor frame reached DDR without loss.
 reg mv_d;reg [31:0] mbin,mgray;
 (* async_reg="true" *)reg [31:0] mg1,mg2;
 always @(posedge mipi_clk)begin
  if(!rst_n)begin mv_d<=0;mbin<=0;mgray<=0;end
  else begin mv_d<=mipi_vs;if(mipi_vs && !mv_d)begin mbin<=mbin+1;mgray<=((mbin+1)>>1)^(mbin+1);end end
 end
 always @(posedge clk)if(!rst_n)begin mg1<=0;mg2<=0;end else begin mg1<=mgray;mg2<=mg1;end
 assign mipi_markers=gray_bin(mg2);
endmodule
