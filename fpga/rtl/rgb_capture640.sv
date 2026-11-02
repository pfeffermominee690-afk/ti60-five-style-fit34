// Central 1440x1080 crop, nearest sample 4/9 in both axes -> packed RGB24 640x480.
// Arm one frame at a time. DONE is after final DDR B, never just pixel EOF.
module rgb_capture640 #(
 parameter SOURCE_WIDTH=1920,SOURCE_HEIGHT=1080,CROP_X=240,CROP_WIDTH=1440,
 parameter PIXELS=(CROP_WIDTH/9*4)*(SOURCE_HEIGHT/9*4)
)(
 input wire clk,pclk,rst_n,
 input wire start,input wire [31:0] address,
 output wire ready,output reg busy,done,
 output reg [31:0] error,frame_id,completed_frames,
 input wire i_de,i_vs,input wire [7:0] i_r,i_g,i_b,
 output wire [31:0] awaddr,output wire [7:0] awlen,
 output wire awvalid,input wire awready,
 output wire [127:0] wdata,output wire [15:0] wstrb,
 output wire wlast,wvalid,input wire wready,
 input wire [1:0] bresp,input wire bvalid,output wire bready
);
 localparam BEATS=PIXELS*3/16,IDLE=0,AW=1,WD=2,BR=3;
 reg [1:0] ws;
 reg [31:0] ptr,left;
 reg [5:0] burst,beat;
 reg clear_fifo,arm_toggle;
 reg [3:0] prep;
 reg [1:0] arm_sync,abort_sync;
 reg arm_seen,waiting,active,pixel_done,pixel_fault,vs_d;
 reg [15:0] x,y;
 reg [3:0] xm,ym;
 reg [1:0] pack_index;
 reg [95:0] pack;
 reg [31:0] pixel_count,pixel_frames,pixel_frame_id;
 wire in_crop=x>=CROP_X && x<CROP_X+CROP_WIDTH;
 wire sample=i_de && in_crop && (xm==0 || xm==2 || xm==4 || xm==6)
                                      && (ym==0 || ym==2 || ym==4 || ym==6);
 reg[1:0] pack_clear;
 always @(posedge pclk)if(!rst_n)pack_clear<=3;else pack_clear<={pack_clear[0],clear_fifo};
 wire fq_push,pack_ready;wire[127:0] packed_word;
 p2_rgb24_pack packer(.clk(pclk),.rst_n(rst_n),.clear(pack_clear[1]||arm_sync[1]!=arm_seen),
 .s_data({i_b,i_g,i_r}),.s_valid(active&&sample&&!pixel_fault),.s_ready(pack_ready),
 .m_data(packed_word),.m_valid(fq_push),.m_ready(fq_ready));
 wire fq_ready,fq_valid,fq_pop;
 wire [127:0] fq_data;
 wire [9:0] fq_level;
 wire [31:0] pixel={8'b0,i_b,i_g,i_r};
 async_fifo #(.WIDTH(128),.DEPTH(512)) queue(
  .wr_clk(pclk),.rd_clk(clk),.arst_n(rst_n && !clear_fifo),
  .s_valid(fq_push),.s_ready(fq_ready),.s_data(packed_word),
  .m_valid(fq_valid),.m_ready(fq_pop),.m_data(fq_data),.wr_level(),.rd_level(fq_level));
 always @(posedge pclk) begin
  if(!rst_n)begin
   arm_sync<=0;abort_sync<=0;arm_seen<=0;waiting<=0;active<=0;pixel_done<=0;pixel_fault<=0;
   x<=0;y<=0;xm<=0;ym<=0;vs_d<=0;pack_index<=0;pack<=0;pixel_count<=0;
   pixel_frames<=0;pixel_frame_id<=0;
  end else begin
   arm_sync<={arm_sync[0],arm_toggle};abort_sync<={abort_sync[0],error!=0};vs_d<=i_vs;
   if(i_vs && !vs_d)begin
    x<=0;y<=0;xm<=0;ym<=0;pixel_frames<=pixel_frames+1;
    if(waiting)begin active<=1;waiting<=0;pixel_frame_id<=pixel_frames+1;end
    else if(active)begin active<=0;pixel_done<=1;pixel_fault<=1;end
   end else if(i_de)begin
    if(x==SOURCE_WIDTH-1)begin x<=0;y<=y+1;xm<=0;ym<=ym==8?0:ym+1'b1;end
    else begin x<=x+1;if(in_crop)xm<=xm==8?0:xm+1'b1;end
   end
   if(arm_sync[1]!=arm_seen)begin
    arm_seen<=arm_sync[1];waiting<=1;active<=0;pixel_done<=0;pixel_fault<=0;pack_index<=0;pixel_count<=0;
   end else if((active || waiting) && abort_sync[1])begin
    active<=0;waiting<=0;pixel_done<=1;pixel_fault<=1;
   end else if(active && sample)begin
    if(pack_index<3)pack[pack_index*32+:32]<=pixel;
    pack_index<=pack_index+1'b1;pixel_count<=pixel_count+1;
    if(!pack_ready)begin pixel_fault<=1;pixel_done<=1;active<=0;end
    else if(pixel_count==PIXELS-1)begin pixel_done<=1;active<=0;end
   end
  end
 end
 reg [1:0] done_sync,fault_sync,ack_sync;
 reg [31:0] id_sync1,id_sync2;
 always @(posedge clk)begin
  if(!rst_n)begin done_sync<=0;fault_sync<=0;ack_sync<=0;id_sync1<=0;id_sync2<=0;end
  else begin
   done_sync<={done_sync[0],pixel_done};fault_sync<={fault_sync[0],pixel_fault};
   ack_sync<={ack_sync[0],arm_seen};id_sync1<=pixel_frame_id;id_sync2<=id_sync1;
  end
 end
 wire [8:0] page_beats=(13'd4096-{1'b0,ptr[11:0]})>>4;
 wire [5:0] left_n=left<16?left[5:0]:6'd16;
 wire [5:0] next_n=page_beats<left_n?page_beats[5:0]:left_n;
 assign ready=!busy;
 assign awaddr=ptr;assign awlen=burst-1'b1;assign awvalid=ws==AW;
 assign wdata=fq_data;assign wstrb=16'hffff;assign wlast=beat==burst-1;
 assign wvalid=ws==WD && fq_valid;assign fq_pop=wvalid && wready;assign bready=ws==BR;
 always @(posedge clk)begin
  if(!rst_n)begin
   busy<=0;done<=0;error<=0;frame_id<=0;completed_frames<=0;ws<=IDLE;
   ptr<=0;left<=0;burst<=0;beat<=0;prep<=0;clear_fifo<=1;arm_toggle<=0;
  end else begin
   done<=0;
   if(start && ready)begin
    busy<=1;error<=0;ptr<=address;left<=BEATS;prep<=8;clear_fifo<=1;
   end else if(prep!=0)begin
    prep<=prep-1'b1;
    if(prep==4)clear_fifo<=0;
    if(prep==1)arm_toggle<=!arm_toggle;
   end else if(busy)begin
    if(ack_sync[1]==arm_toggle && fault_sync[1])error<=error|1;
    case(ws)
     IDLE:begin
      if(error!=0 && done_sync[1] && ack_sync[1]==arm_toggle)begin busy<=0;done<=1;frame_id<=id_sync2;end
      else if(left==0 && error==0)begin busy<=0;done<=1;frame_id<=id_sync2;completed_frames<=completed_frames+1;end
      else if(error==0 && fq_level>=next_n)begin burst<=next_n;beat<=0;ws<=AW;end
     end
     AW:if(awready)ws<=WD;
     WD:if(wvalid && wready)begin if(wlast)ws<=BR;else beat<=beat+1'b1;end
     BR:if(bvalid)begin
      ws<=IDLE;ptr<=ptr+{22'b0,burst,4'b0};left<=left-burst;
      if(bresp!=0)error<=error|2;
     end
    endcase
   end
  end
 end
endmodule
