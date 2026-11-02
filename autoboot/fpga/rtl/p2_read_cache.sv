// Read-only, direct-mapped 4KiB feature/weight cache, 16-byte lines.
// One outstanding aligned AXI read. Invalidate between tensor writes/layers.
// Synchronous data RAM, no reset on data. Backpressure and RRESP propagated.
module p2_read_cache(input clk,rst_n,invalidate,output ready,
 input req_valid,output req_ready,input[31:0]req_address,
 output rsp_valid,input rsp_ready,output reg[7:0]rsp_data,output reg rsp_error,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rvalid,rlast,output rready,
 output reg[31:0]hits,misses);
 localparam IDLE=0,LOOKUP=1,ADDRESS=2,DATA=3,REPLY=4;
 reg[2:0]state;reg[31:0]address;
 reg[255:0]valid_bits;reg[19:0]tags[0:255];reg[127:0]mem[0:255];
 reg[127:0]read_data;reg[19:0]read_tag;reg read_valid;
 assign ready=state==IDLE;assign req_ready=ready&&!invalidate;
 assign rsp_valid=state==REPLY;
 assign araddr={address[31:4],4'b0};assign arlen=0;assign arvalid=state==ADDRESS;
 assign rready=state==DATA;
 always @(posedge clk)begin
  if(req_valid&&req_ready)begin
   read_data<=mem[req_address[11:4]];read_tag<=tags[req_address[11:4]];read_valid<=valid_bits[req_address[11:4]];
  end
  if(state==DATA&&rvalid&&rresp==0&&rlast)begin mem[address[11:4]]<=rdata;tags[address[11:4]]<=address[31:12];end
 end
 always @(posedge clk)begin
  if(!rst_n)begin state<=IDLE;address<=0;valid_bits<=0;rsp_data<=0;rsp_error<=0;hits<=0;misses<=0;end
  else begin
   case(state)
    IDLE:if(invalidate)valid_bits<=0;
     else if(req_valid)begin address<=req_address;rsp_error<=0;state<=LOOKUP;end
    LOOKUP:if(read_valid&&read_tag==address[31:12])begin
     rsp_data<=read_data[address[3:0]*8+:8];hits<=hits+1'b1;state<=REPLY;
    end else begin misses<=misses+1'b1;state<=ADDRESS;end
    ADDRESS:if(arready)state<=DATA;
    DATA:if(rvalid)begin
     rsp_data<=rdata[address[3:0]*8+:8];rsp_error<=rresp!=0||!rlast;
     if(rresp==0&&rlast)valid_bits[address[11:4]]<=1;
     state<=REPLY;
    end
    REPLY:if(rsp_ready)state<=IDLE;
    default:state<=IDLE;
   endcase
  end
 end
endmodule
