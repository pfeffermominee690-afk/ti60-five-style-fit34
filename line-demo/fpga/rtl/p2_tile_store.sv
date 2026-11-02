// BRAM-backed tile transpose, serialized reads; all writes await AXI B.
module p2_tile_store(input clk,rst_n,start,input[31:0]base,input[7:0]cout,
 output ready,output reg done,error,
 input s_valid,output s_ready,input[127:0]s_data,input[3:0]s_channel,input s_last,
 output[31:0]awaddr,output[7:0]awlen,output awvalid,input awready,
 output reg[127:0]wdata,output[15:0]wstrb,output wvalid,wlast,input wready,
 input[1:0]bresp,input bvalid,output bready);
 localparam IDLE=0,CAPTURE=1,LOOK=2,ASSEMBLE=3,ADDR=4,DATA=5,RESP=6;
 reg[2:0]state;reg[127:0]rows[0:15],read_row;reg[3:0]channel,beat,byte_index;
 reg[31:0]address;reg[7:0]co;
 wire[7:0]linear={beat,4'd0}+byte_index;
 wire[3:0]read_channel=co==3?linear%3:byte_index;
 wire[3:0]read_pixel=co==3?linear/3:beat;
 always @(posedge clk)begin
  if(state==CAPTURE&&s_valid)rows[s_channel]<=s_data;
  read_row<=rows[read_channel];
 end
 assign ready=state==IDLE;assign s_ready=state==CAPTURE;
 assign awaddr=address;assign awlen=0;assign awvalid=state==ADDR;
 assign wstrb=16'hffff;assign wvalid=state==DATA;assign wlast=1;assign bready=state==RESP;
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;done<=0;error<=0;channel<=0;beat<=0;byte_index<=0;address<=0;co<=0;wdata<=0;end
  else begin done<=0;case(state)
   IDLE:if(start)begin error<=0;channel<=0;beat<=0;byte_index<=0;address<=base;co<=cout;
    if(base[3:0]!=0||!(cout==3||(cout!=0&&cout<=128&&cout[3:0]==0)))begin done<=1;error<=1;end else state<=CAPTURE;
   end
   CAPTURE:if(s_valid)begin
    if(s_channel!=channel||s_last!=(channel==15))begin state<=IDLE;done<=1;error<=1;end
    else if(channel==15)state<=LOOK;else channel<=channel+1'b1;
   end
   LOOK:state<=ASSEMBLE;
   ASSEMBLE:begin wdata[byte_index*8+:8]<=read_row[read_pixel*8+:8];
    if(byte_index==15)state<=ADDR;else begin byte_index<=byte_index+1'b1;state<=LOOK;end
   end
   ADDR:if(awready)state<=DATA;
   DATA:if(wready)state<=RESP;
   RESP:if(bvalid)begin
    if(bresp!=0)begin error<=1;done<=1;state<=IDLE;end
    else if(beat==(co==3?2:15))begin done<=1;state<=IDLE;end
    else begin beat<=beat+1'b1;address<=address+(co==3?16:co);byte_index<=0;state<=LOOK;end
   end
  endcase end
 end
endmodule
