// Read immutable original/result DDR frames and show two actual VGA panels on
// the existing 1080p timing. A publish becomes visible only at a frame boundary.
module rgb_pair_display #(
 parameter SOURCE_WIDTH=1920,PANEL_WIDTH=640,PANEL_HEIGHT=480,
 parameter LEFT_X=160,RIGHT_X=1120,TOP_Y=300,FIFO_DEPTH=512,SCALE_3_2=0,SCALE_2=0,SCALE_X_2=0,ORIGINAL_PITCH=PANEL_WIDTH*3,RESULT_PITCH=PANEL_WIDTH*3
)(
 input wire clk,pclk,rst_n,
 input wire publish,input wire [31:0] input_address,result_address,job_id,
 output reg pending,front_valid,ack,
 output reg [31:0] front_job,read_errors,read_frames,
 output wire [31:0] underflows,
 input wire i_de,i_hs,i_vs,
 output reg o_de,o_hs,o_vs,output reg [23:0] o_rgb,
 output reg [11:0] o_x,o_y,
 output wire [31:0] araddr,output wire [7:0] arlen,
 output wire arvalid,input wire arready,
 input wire [127:0] rdata,input wire [1:0] rresp,
 input wire rlast,rvalid,output wire rready
);
 localparam ROW_BEATS=PANEL_WIDTH*3/16,PITCH=RESULT_PITCH;
 localparam DISPLAY_WIDTH=(SCALE_2 || SCALE_X_2)?PANEL_WIDTH*2:SCALE_3_2?PANEL_WIDTH*3/2:PANEL_WIDTH;
 localparam DISPLAY_HEIGHT=SCALE_2?PANEL_HEIGHT*2:SCALE_3_2?PANEL_HEIGHT*3/2:PANEL_HEIGHT;
 localparam RI=0,RA=1,RR=2,CR=3,CP=4;
 reg [2:0] rs;
 reg [31:0] front_input,front_result,next_input,next_result,next_job;
 reg [31:0] ptr,orig_row,result_row;
 reg [15:0] row,word_in_row;
 reg panel,reading,restart,aborting,clear_fifo,frame_fault;
 reg [3:0] prep;
 reg [5:0] burst,beat;
 // Cache one original/result row pair. Repeated 3:2 vertical rows replay
 // on chip instead of being fetched a second time from DDR.
 reg [127:0] row_cache [0:ROW_BEATS*2-1];
 reg [$clog2(ROW_BEATS*2)-1:0] cache_pos;
 reg [127:0] cache_data;
 wire cache_push=rs==CP && !aborting;
 wire fq_ready,fq_valid,fq_pop;
 always @(posedge clk)begin
  if(rs==CR)cache_data<=row_cache[cache_pos];
  if((SCALE_3_2 || SCALE_2) && rvalid && rready && !aborting && !bad_beat && y_phase==0)
   row_cache[(panel?ROW_BEATS:0)+word_in_row+beat]<=rdata;
 end
 wire [127:0] fq_data;
 wire [$clog2(FIFO_DEPTH):0] fq_level;
 wire bad_beat=rvalid && rready && (rresp!=0 || rlast!=(beat==burst-1));
 async_fifo #(.WIDTH(128),.DEPTH(FIFO_DEPTH)) queue(
  .wr_clk(clk),.rd_clk(pclk),.arst_n(rst_n && !clear_fifo),
  .s_valid(cache_push || (rvalid && rready && !aborting && !bad_beat)),.s_ready(fq_ready),.s_data(cache_push?cache_data:rdata),
  .m_valid(fq_valid),.m_ready(fq_pop),.m_data(fq_data),.wr_level(fq_level),.rd_level());
 reg [15:0] x,y;
 reg [1:0] subpixel;
 reg [1:0] x_phase,y_phase;
 reg vs_d,frame_toggle,underflow_frame;
 reg [31:0] underflow_binary,underflow_gray;
 reg [1:0] valid_sync,fault_sync;
 wire in_panel=i_de && y>=TOP_Y && y<TOP_Y+DISPLAY_HEIGHT &&
   ((x>=LEFT_X && x<LEFT_X+DISPLAY_WIDTH) || (x>=RIGHT_X && x<RIGHT_X+DISPLAY_WIDTH));
 wire consume_pixel=(SCALE_2 || SCALE_X_2)?x_phase==1:(!SCALE_3_2 || x_phase!=0);
 wire[23:0] selected_pixel;wire pixel_valid,unpack_ready;
 (* async_reg="true" *)reg[1:0] unpack_clear;
 always @(posedge pclk)if(!rst_n)unpack_clear<=3;else unpack_clear<={unpack_clear[0],clear_fifo};
 p2_rgb24_unpack unpacker(.clk(pclk),.rst_n(rst_n),.clear(unpack_clear[1]),
 .s_data(fq_data),.s_valid(fq_valid&&!underflow_frame),.s_ready(unpack_ready),
 .m_data(selected_pixel),.m_valid(pixel_valid),.m_ready((in_panel&&valid_sync[1]&&!underflow_frame&&consume_pixel)||underflow_frame));
 assign fq_pop=fq_valid&&(underflow_frame||unpack_ready);
 always @(posedge pclk)begin
  if(!rst_n)begin
   x<=0;y<=0;subpixel<=0;x_phase<=0;vs_d<=0;frame_toggle<=0;underflow_frame<=0;
   underflow_binary<=0;underflow_gray<=0;valid_sync<=0;fault_sync<=0;
   o_de<=0;o_hs<=0;o_vs<=0;o_rgb<=0;o_x<=0;o_y<=0;
  end else begin
   vs_d<=i_vs;valid_sync<={valid_sync[0],front_valid};fault_sync<={fault_sync[0],frame_fault};
   o_de<=i_de;o_hs<=i_hs;o_vs<=i_vs;o_x<=x;o_y<=y;o_rgb<=0;
   if(i_vs && !vs_d)begin
    x<=0;y<=0;subpixel<=0;x_phase<=0;frame_toggle<=!frame_toggle;underflow_frame<=0;
   end else if(i_de)begin
    if(x==SOURCE_WIDTH-1)begin x<=0;y<=y+1'b1;end else x<=x+1'b1;
   end
   if(in_panel && valid_sync[1] && !underflow_frame)begin
    if(pixel_valid && !fault_sync[1])begin
     o_rgb<=selected_pixel; // DDR bytes B,G,R; HDL bus R,G,B
     if(consume_pixel)subpixel<=subpixel+1'b1;
     if(SCALE_2 || SCALE_X_2)x_phase<=x_phase==1?0:1;
     else if(SCALE_3_2)x_phase<=x_phase==2?0:x_phase+1'b1;
    end else begin
     underflow_frame<=1;
     underflow_binary<=underflow_binary+1'b1;
     underflow_gray<=((underflow_binary+1'b1)>>1)^(underflow_binary+1'b1);
    end
   end
  end
 end
 (* async_reg="true" *) reg [1:0] frame_sync;
 (* async_reg="true" *) reg [31:0] uf1,uf2;
 reg frame_seen;
 function automatic [31:0] gray_bin(input [31:0] g);
  integer k;begin gray_bin[31]=g[31];for(k=30;k>=0;k=k-1)gray_bin[k]=gray_bin[k+1]^g[k];end
 endfunction
 assign underflows=gray_bin(uf2);
 wire [8:0] page_beats=(13'd4096-{1'b0,ptr[11:0]})>>4;
 wire [15:0] row_left=ROW_BEATS-word_in_row;
 wire [5:0] row_n=row_left<32?row_left[5:0]:6'd32;
 wire [5:0] next_n=page_beats<row_n?page_beats[5:0]:row_n;
 assign araddr=ptr;assign arlen=burst-1'b1;assign arvalid=rs==RA;
 assign rready=rs==RR && (aborting || fq_ready);
 always @(posedge clk)begin
  if(!rst_n)begin
   rs<=RI;cache_pos<=0;pending<=0;front_valid<=0;ack<=0;front_job<=0;read_errors<=0;read_frames<=0;
   front_input<=0;front_result<=0;next_input<=0;next_result<=0;next_job<=0;
   ptr<=0;orig_row<=0;result_row<=0;row<=0;word_in_row<=0;panel<=0;y_phase<=0;
   reading<=0;restart<=0;aborting<=0;clear_fifo<=1;frame_fault<=0;prep<=0;burst<=0;beat<=0;
   frame_sync<=0;frame_seen<=0;uf1<=0;uf2<=0;
  end else begin
   ack<=0;frame_sync<={frame_sync[0],frame_toggle};uf1<=underflow_gray;uf2<=uf1;
   if(publish && !pending)begin pending<=1;next_input<=input_address;next_result<=result_address;next_job<=job_id;end
   if(frame_sync[1]!=frame_seen)begin frame_seen<=frame_sync[1];restart<=1;aborting<=1;end
   if(prep!=0)begin prep<=prep-1'b1;if(prep==4)clear_fifo<=0;end
   if(bad_beat && !aborting)begin frame_fault<=1;aborting<=1;reading<=0;read_errors<=read_errors+1;end
   case(rs)
    RI:begin
     if(restart && prep==0)begin
      restart<=0;aborting<=0;clear_fifo<=1;prep<=8;frame_fault<=0;
      panel<=0;row<=0;word_in_row<=0;y_phase<=0;reading<=pending || front_valid;
      if(pending)begin
       front_input<=next_input;front_result<=next_result;front_job<=next_job;
       ptr<=next_input;orig_row<=next_input;result_row<=next_result;
       front_valid<=1;pending<=0;ack<=1;
      end else begin ptr<=front_input;orig_row<=front_input;result_row<=front_result;end
     end else if(reading && !aborting && prep==0 && FIFO_DEPTH-fq_level>=next_n)begin
      burst<=next_n;beat<=0;rs<=RA;
     end
    end
    CR:begin if(aborting)rs<=RI;else rs<=CP;end
    CP:begin
     if(aborting)rs<=RI;
     else if(fq_ready)begin
      if(cache_pos==ROW_BEATS*2-1)begin
       rs<=RI;row<=row+1'b1;y_phase<=SCALE_2?0:2;
       orig_row<=orig_row+ORIGINAL_PITCH;result_row<=result_row+PITCH;ptr<=orig_row+ORIGINAL_PITCH;
       if(row==DISPLAY_HEIGHT-1)begin reading<=0;read_frames<=read_frames+1;end
      end else begin cache_pos<=cache_pos+1'b1;rs<=CR;end
     end
    end
    RA:if(arready)rs<=RR;
    RR:if(rvalid && rready)begin
     if(rlast)begin
      rs<=RI;
      if(!aborting && !bad_beat)begin
       if(word_in_row+burst==ROW_BEATS)begin
        word_in_row<=0;
        if(!panel)begin panel<=1;ptr<=result_row;end
        else begin
         panel<=0;row<=row+1'b1;
         if((SCALE_3_2 || SCALE_2) && y_phase==0)begin
          ptr<=orig_row;
          if(row!=DISPLAY_HEIGHT-1)begin cache_pos<=0;rs<=CR;end
         end
         else begin orig_row<=orig_row+ORIGINAL_PITCH;result_row<=result_row+PITCH;ptr<=orig_row+ORIGINAL_PITCH;end
         if(SCALE_3_2)y_phase<=y_phase==2?0:y_phase+1'b1;
         if(row==DISPLAY_HEIGHT-1)begin reading<=0;read_frames<=read_frames+1;end
        end
       end else begin word_in_row<=word_in_row+burst;ptr<=ptr+{22'b0,burst,4'b0};end
      end
     end else beat<=beat+1'b1;
    end
   endcase
  end
 end
endmodule
