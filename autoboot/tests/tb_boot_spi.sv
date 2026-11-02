module tb_boot_spi;
 reg clk=0;always #5 clk=~clk;
 reg reset=1,psel=0,penable=0,pwrite=0;
 reg [3:0] paddr=0;reg [31:0] pwdata=0;
 wire [31:0] prdata;wire pready,pslverror,cs_n,sclk,mosi;
 reg miso=0;reg [7:0] incoming=0,reply=0;integer nbit=0,edges=0;
 apb_boot_spi dut(.*);
 always @(posedge sclk)begin incoming={incoming[6:0],mosi};edges++;end
 always @(negedge sclk)begin nbit++;if(nbit<8)miso=reply[7-nbit];end
 task wr(input[3:0]a,input[31:0]v,input bit err=0);
  @(negedge clk);psel=1;pwrite=1;paddr=a;pwdata=v;
  @(negedge clk);penable=1;
  @(posedge clk);if(!pready||pslverror!=err)$fatal(1,"APB error addr=%d",a);
  @(negedge clk);psel=0;penable=0;pwrite=0;
 endtask
 task rd(input[3:0]a,output[31:0]v);
  @(negedge clk);psel=1;pwrite=0;paddr=a;
  @(negedge clk);penable=1;
  @(posedge clk);v=prdata;if(!pready||pslverror)$fatal;
  @(negedge clk);psel=0;penable=0;
 endtask
 reg [31:0] v;reg[7:0] sent;
 initial begin
  repeat(5)@(negedge clk);reset=0;
  wr(4,8'hff,1); // refuse byte transfer while deselected
  wr(0,0);
  for(integer i=0;i<256;i++)begin
   sent=i;reply=(i*73+21)&255;nbit=0;edges=0;incoming=0;miso=reply[7];
   wr(4,sent);
   wr(0,1,1);wr(4,8'haa,1); // cannot truncate/overwrite an in-flight byte
   do rd(8,v);while(v[0]);
   rd(4,v);
   if(v[7:0]!=reply||incoming!=sent||edges!=8||sclk||cs_n)$fatal(1,"byte %0d tx=%h rx=%h expected=%h edges=%d",i,incoming,v,reply,edges);
   repeat(i%7)@(negedge clk);
  end
  wr(0,1);wr(0,0);wr(4,8'hfc);repeat(80)@(negedge clk);reset=1;
  @(negedge clk);reset=0;
  rd(8,v);if(!cs_n||sclk||v)$fatal(1,"reset did not abort");
  $display("SPI_PASS 256 byte patterns, full-duplex sampling, APB busy protection, mid-transfer reset");$finish;
 end
 initial begin #3000000;$fatal(1,"timeout");end
endmodule
