// APB at 0xf8101000. Buffer ownership is firmware-managed; hardware rejects
// commands while engines are busy. Addresses are restricted to the RGB pool.
module video_control # (parameter CLOCK_HZ=100000000)(
 input wire clk,rst_n,
 input wire [11:0] paddr,input wire psel,penable,pwrite,
 input wire [31:0] pwdata,output reg [31:0] prdata,
 output wire pready,pslverror,
 output wire capture_start,output reg [31:0] capture_address,
 input wire capture_ready,capture_busy,capture_done,
 input wire [31:0] capture_error,capture_id,capture_frames,
 output wire publish,output reg [31:0] input_address,result_address,job_id,
 input wire pending,front_valid,ack,
 input wire [31:0] front_job,read_errors,read_frames,underflows,
 input wire [31:0] cnn_frames,mipi_markers,
 output reg [31:0] measured_fps
);
 reg invalid,completed;
 reg [31:0] seconds_ticks,previous_frames;
 wire access=psel && penable;
 function automatic address_ok(input [31:0] a);
  address_ok=a[3:0]==0 && a>=32'h01000000 && a<=32'h03ed4000;
 endfunction
 always @* begin
  invalid=0;prdata=0;
  if(paddr[1:0]!=0)invalid=1;
  else case(paddr)
   12'h000:begin prdata=32'h56494431;if(pwrite)invalid=1;end
   12'h004:if(pwrite && ((pwdata&~32'h3)!=0 ||
      (pwdata[0] && (!capture_ready || capture_done || !address_ok(capture_address)))))invalid=1;
   12'h008:begin prdata={27'b0,front_valid,pending,(capture_error!=0),completed,capture_busy};if(pwrite)invalid=1;end
   12'h00c:begin prdata=capture_address;if(pwrite && capture_busy)invalid=1;end
   12'h010:begin prdata=capture_error;if(pwrite)invalid=1;end
   12'h014:begin prdata=capture_id;if(pwrite)invalid=1;end
   12'h018:begin prdata=capture_frames;if(pwrite)invalid=1;end
   12'h020:begin prdata=input_address;if(pwrite && pending)invalid=1;end
   12'h024:begin prdata=result_address;if(pwrite && pending)invalid=1;end
   12'h028:begin prdata=job_id;if(pwrite && pending)invalid=1;end
   12'h02c:if(pwrite && (pwdata!=1 || pending || !address_ok(input_address) || !address_ok(result_address)))invalid=1;
   12'h030:begin prdata=front_job;if(pwrite)invalid=1;end
   12'h034:begin prdata=read_errors;if(pwrite)invalid=1;end
   12'h038:begin prdata=underflows;if(pwrite)invalid=1;end
   12'h03c:begin prdata=read_frames;if(pwrite)invalid=1;end
   12'h040:begin prdata=cnn_frames;if(pwrite)invalid=1;end
   12'h044:begin prdata=measured_fps;if(pwrite)invalid=1;end
   12'h048:begin prdata=mipi_markers;if(pwrite)invalid=1;end
   default:invalid=1;
  endcase
 end
 assign pready=1;
 assign pslverror=access && invalid;
 wire write_fire=access && pwrite && !invalid;
 assign capture_start=write_fire && paddr==12'h004 && pwdata[0];
 assign publish=write_fire && paddr==12'h02c;
 always @(posedge clk)begin
  if(!rst_n)begin
   capture_address<=0;input_address<=0;result_address<=0;job_id<=0;completed<=0;
   seconds_ticks<=0;previous_frames<=0;measured_fps<=0;
  end else begin
   if(write_fire)case(paddr)
    12'h004:if(pwdata[1])completed<=0;
    12'h00c:capture_address<=pwdata;
    12'h020:input_address<=pwdata;
    12'h024:result_address<=pwdata;
    12'h028:job_id<=pwdata;
    default:;
   endcase
   if(capture_start)completed<=0;
   if(capture_done)completed<=1;
   if(seconds_ticks==CLOCK_HZ-1)begin
    seconds_ticks<=0;measured_fps<=cnn_frames-previous_frames;previous_frames<=cnn_frames;
   end else seconds_ticks<=seconds_ticks+1;
  end
 end
endmodule
