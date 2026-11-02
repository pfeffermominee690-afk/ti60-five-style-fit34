module tb;
 reg clk=0;always #5 clk=~clk;
 reg rst_n=0;reg [31:0] completed=0;
 video_pipeline dut(.clk(clk),.pclk(clk),.capture_pclk(clk),.mipi_clk(clk),.rst_n(rst_n),.mipi_vs(1'b0),
 .paddr(12'b0),.psel(1'b0),.penable(1'b0),.pwrite(1'b0),.pwdata(32'b0),.cnn_frames(completed),
 .i_de(1'b0),.i_hs(1'b0),.i_vs(1'b0),.i_rgb(24'b0),.awready(1'b0),.arready(1'b0),.wready(1'b0),
 .bresp(2'b0),.bvalid(1'b0),.rdata(128'b0),.rresp(2'b0),.rvalid(1'b0),.rlast(1'b0));
 task check(input integer n,input integer expected);
 integer value;begin
  @(negedge clk);rst_n=0;completed=0;
  repeat(3)@(negedge clk);rst_n=1;completed=n;
  repeat(8)@(negedge clk);
  dut.pticks=74249999;dut.control.seconds_ticks=99999999;
  repeat(4)@(negedge clk);
  value=dut.fps_bcd[11:8]*100+dut.fps_bcd[7:4]*10+dut.fps_bcd[3:0];
  if(value!=expected)$fatal(1,"display %0d != %0d",value,expected);
  if(dut.measured_fps!=n)$fatal(1,"measured FPS was altered %0d != %0d",dut.measured_fps,n);
  $display("PASS actual=%0d displayed=%0d",n,value);
 end endtask
 initial begin
 check(0,0);check(1,3);check(9,27);check(10,30);check(15,45);check(332,996);check(333,999);check(334,999);check(32'hffffffff,999);
 $display("OSD_MULTIPLIER_PASS measured counter unchanged; display capped at 999");$finish;
 end
endmodule
