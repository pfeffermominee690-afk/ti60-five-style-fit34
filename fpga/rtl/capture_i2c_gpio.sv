// Open drain pins only. No autonomous register table or I2C sequencer.
module capture_i2c_gpio(input clk,rst_n,psel,penable,pwrite,input[11:0]paddr,
 input[31:0]pwdata,output[31:0]prdata,output error,input scl_in,sda_in,
 output scl_oe,sda_oe,sensor_reset);
 reg[2:0]control;
 (* async_reg="true" *)reg[1:0]scl_sync,sda_sync;
 assign scl_oe=control[0];assign sda_oe=control[1];assign sensor_reset=control[2];
 assign prdata=paddr==0?{29'd0,control}:paddr==4?{30'd0,sda_sync[1],scl_sync[1]}:32'h49324331;
 assign error=psel&&penable&&((paddr!=0&&paddr!=4&&paddr!=8)||(pwrite&&(paddr!=0||pwdata[31:3]!=0)));
 always @(posedge clk)begin
  if(!rst_n)begin control<=4;scl_sync<=3;sda_sync<=3;end
  else begin
   scl_sync<={scl_sync[0],scl_in};sda_sync<={sda_sync[0],sda_in};
   if(psel&&penable&&pwrite&&!error)control<=pwdata[2:0];
  end
 end
endmodule
