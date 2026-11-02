// Mode-0, single-data-lane Flash byte engine. 100 MHz / 64 = 1.5625 MHz.
// Only used at startup; idle clock is held low during video inference.
module apb_boot_spi(
 input wire clk, reset,
 input wire [3:0] paddr, input wire psel, penable, pwrite,
 input wire [31:0] pwdata, output wire [31:0] prdata,
 output wire pready, pslverror,
 output reg cs_n, sclk, mosi, input wire miso
);
 reg busy;
 reg [4:0] divider;
 reg [2:0] bit_index;
 reg [7:0] tx, rx;
 wire access=psel && penable;
 wire control_write=access && pwrite && paddr[3:2]==0;
 wire data_write=access && pwrite && paddr[3:2]==1;
 assign pready=1'b1;
 assign pslverror=access && (paddr[1:0]!=0 || paddr[3:2]==3 ||
                          (pwrite && (busy || paddr[3:2]==2 || (data_write && cs_n))));
 assign prdata=paddr[3:2]==0 ? {31'd0,cs_n} :
               paddr[3:2]==1 ? {24'd0,rx} : {31'd0,busy};
 always @(posedge clk) begin
  if(reset)begin cs_n<=1; sclk<=0; mosi<=0; busy<=0; divider<=0; bit_index<=0; tx<=0; rx<=0; end
  else begin
   if(control_write && !pslverror)cs_n<=pwdata[0];
   if(data_write && !pslverror)begin
    tx<=pwdata[7:0]; mosi<=pwdata[7]; rx<=0; busy<=1; divider<=31; bit_index<=7; sclk<=0;
   end else if(busy)begin
    if(divider!=0)divider<=divider-1'b1;
    else begin
     divider<=31;
     if(!sclk)begin sclk<=1; rx<={rx[6:0],miso}; end
     else begin
      sclk<=0;
      if(bit_index==0)busy<=0;
      else begin bit_index<=bit_index-1'b1; tx<={tx[6:0],1'b0}; mosi<=tx[6]; end
     end
    end
   end
  end
 end
endmodule
