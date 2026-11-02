module tb;
reg clk=0;always #5 clk=~clk;
reg  io_systemClk=0;
wire [15:0] io_ddrA_w_payload_strb;
wire [127:0] io_ddrA_w_payload_data;
reg  axiA_awready=0;
wire [7:0] axiA_awlen;
wire [2:0] axiA_awsize;
wire [1:0] axiA_arburst;
wire  axiA_awlock;
wire [3:0] axiA_arcache;
wire [3:0] axiA_awqos;
wire [2:0] axiA_awprot;
wire [2:0] axiA_arsize;
wire [3:0] axiA_arregion;
reg  axiA_arready=0;
wire [3:0] axiA_arqos;
wire [2:0] axiA_arprot;
wire  axiA_arlock;
wire [7:0] axiA_arlen;
wire [7:0] axiA_arid;
wire [3:0] axiA_awcache;
wire [1:0] axiA_awburst;
wire [31:0] axiA_awaddr;
reg  axiAInterrupt=0;
reg  axiA_rlast=0;
reg  jtagCtrl_enable=0;
reg  jtagCtrl_tdi=0;
reg  jtagCtrl_capture=0;
reg  jtagCtrl_shift=0;
reg  jtagCtrl_update=0;
reg  jtagCtrl_reset=0;
wire  jtagCtrl_tdo;
reg  jtagCtrl_tck=0;
wire [31:0] axiA_araddr;
wire  axiA_wvalid;
reg  axiA_wready=0;
wire [31:0] axiA_wdata;
wire [3:0] axiA_wstrb;
wire  axiA_wlast;
reg  axiA_bvalid=0;
wire  axiA_bready;
reg [7:0] axiA_bid=0;
reg [1:0] axiA_bresp=0;
reg  axiA_rvalid=0;
wire  axiA_rready;
reg [31:0] axiA_rdata=0;
reg [7:0] axiA_rid=0;
reg [1:0] axiA_rresp=0;
wire  axiA_arvalid;
wire [7:0] axiA_awid;
wire [3:0] axiA_awregion;
wire  axiA_awvalid;
reg  io_ddrA_r_payload_last=0;
reg [1:0] io_ddrA_r_payload_resp=0;
reg [7:0] io_ddrA_r_payload_id=0;
reg [127:0] io_ddrA_r_payload_data=0;
wire  io_ddrA_r_ready;
reg  io_ddrA_r_valid=0;
reg [1:0] io_ddrA_b_payload_resp=0;
reg [7:0] io_ddrA_b_payload_id=0;
wire  io_ddrA_b_ready;
reg  io_ddrA_b_valid=0;
wire  io_ddrA_w_payload_last;
reg  io_ddrA_w_ready=0;
wire  io_ddrA_w_valid;
wire [2:0] io_ddrA_aw_payload_prot;
wire [3:0] io_ddrA_aw_payload_qos;
wire [3:0] io_ddrA_aw_payload_cache;
wire  io_ddrA_aw_payload_lock;
wire [1:0] io_ddrA_aw_payload_burst;
wire [2:0] io_ddrA_aw_payload_size;
wire [7:0] io_ddrA_aw_payload_len;
wire [3:0] io_ddrA_aw_payload_region;
wire [7:0] io_ddrA_aw_payload_id;
wire [31:0] io_ddrA_aw_payload_addr;
reg  io_ddrA_aw_ready=0;
wire  io_ddrA_aw_valid;
wire [2:0] io_ddrA_ar_payload_prot;
wire [3:0] io_ddrA_ar_payload_qos;
wire [3:0] io_ddrA_ar_payload_cache;
wire  io_ddrA_ar_payload_lock;
wire [1:0] io_ddrA_ar_payload_burst;
wire [2:0] io_ddrA_ar_payload_size;
wire [7:0] io_ddrA_ar_payload_len;
wire [3:0] io_ddrA_ar_payload_region;
wire [7:0] io_ddrA_ar_payload_id;
wire [31:0] io_ddrA_ar_payload_addr;
reg  io_ddrA_ar_ready=0;
wire  io_ddrA_ar_valid;
reg  system_spi_0_io_data_0_read=0;
wire  system_spi_0_io_data_0_write;
wire  system_spi_0_io_data_0_writeEnable;
reg  system_spi_0_io_data_1_read=0;
wire  system_spi_0_io_data_1_write;
wire  system_spi_0_io_data_1_writeEnable;
reg  system_spi_0_io_data_2_read=0;
wire  system_spi_0_io_data_2_write;
wire  system_spi_0_io_data_2_writeEnable;
reg  system_spi_0_io_data_3_read=0;
wire  system_spi_0_io_data_3_write;
wire  system_spi_0_io_data_3_writeEnable;
wire  system_spi_0_io_sclk_write;
reg  userInterruptA=0;
wire [15:0] io_apbSlave_0_PADDR;
wire  io_apbSlave_0_PENABLE;
reg [31:0] io_apbSlave_0_PRDATA=0;
reg  io_apbSlave_0_PREADY=0;
wire  io_apbSlave_0_PSEL;
reg  io_apbSlave_0_PSLVERROR=0;
wire [31:0] io_apbSlave_0_PWDATA;
wire  io_apbSlave_0_PWRITE;
reg  io_asyncReset=0;
reg  io_memoryClk=0;
wire  io_systemReset;
wire  system_uart_0_io_txd;
wire  io_memoryReset;
reg  system_uart_0_io_rxd=0;
reg  system_i2c_0_io_scl_read=0;
wire  system_i2c_0_io_scl_write;
reg  system_i2c_0_io_sda_read=0;
wire  system_i2c_0_io_sda_write;
wire [3:0] system_gpio_0_io_writeEnable;
wire  io_ddrMasters_0_reset;
reg  io_ddrMasters_0_clk=0;
wire  io_ddrMasters_0_r_payload_last;
wire [1:0] io_ddrMasters_0_r_payload_resp;
wire [3:0] io_ddrMasters_0_r_payload_id;
wire [31:0] io_ddrMasters_0_r_payload_data;
reg  io_ddrMasters_0_r_ready=0;
wire  io_ddrMasters_0_r_valid;
reg [2:0] io_ddrMasters_0_ar_payload_prot=0;
reg [3:0] io_ddrMasters_0_ar_payload_qos=0;
reg [3:0] io_ddrMasters_0_ar_payload_cache=0;
reg  io_ddrMasters_0_ar_payload_lock=0;
reg [1:0] io_ddrMasters_0_ar_payload_burst=0;
reg [2:0] io_ddrMasters_0_ar_payload_size=0;
reg [7:0] io_ddrMasters_0_ar_payload_len=0;
reg [3:0] io_ddrMasters_0_ar_payload_region=0;
reg [3:0] io_ddrMasters_0_ar_payload_id=0;
reg [31:0] io_ddrMasters_0_ar_payload_addr=0;
wire  io_ddrMasters_0_ar_ready;
reg  io_ddrMasters_0_ar_valid=0;
wire [1:0] io_ddrMasters_0_b_payload_resp;
wire [3:0] io_ddrMasters_0_b_payload_id;
reg  io_ddrMasters_0_b_ready=0;
wire  io_ddrMasters_0_b_valid;
reg  io_ddrMasters_0_w_payload_last=0;
reg [3:0] io_ddrMasters_0_w_payload_strb=0;
reg [31:0] io_ddrMasters_0_w_payload_data=0;
wire  io_ddrMasters_0_w_ready;
reg  io_ddrMasters_0_w_valid=0;
reg [2:0] io_ddrMasters_0_aw_payload_prot=0;
reg [3:0] io_ddrMasters_0_aw_payload_qos=0;
reg [3:0] io_ddrMasters_0_aw_payload_cache=0;
reg  io_ddrMasters_0_aw_payload_lock=0;
reg [1:0] io_ddrMasters_0_aw_payload_burst=0;
reg [2:0] io_ddrMasters_0_aw_payload_size=0;
reg [7:0] io_ddrMasters_0_aw_payload_len=0;
reg [3:0] io_ddrMasters_0_aw_payload_region=0;
reg [3:0] io_ddrMasters_0_aw_payload_id=0;
reg [31:0] io_ddrMasters_0_aw_payload_addr=0;
wire  io_ddrMasters_0_aw_ready;
reg  io_ddrMasters_0_aw_valid=0;
wire [3:0] system_gpio_0_io_write;
reg [3:0] system_gpio_0_io_read=0;
wire [0:0] system_spi_0_io_ss;
soc dut(.io_systemClk(io_systemClk),.io_ddrA_w_payload_strb(io_ddrA_w_payload_strb),.io_ddrA_w_payload_data(io_ddrA_w_payload_data),.axiA_awready(axiA_awready),.axiA_awlen(axiA_awlen),.axiA_awsize(axiA_awsize),.axiA_arburst(axiA_arburst),.axiA_awlock(axiA_awlock),.axiA_arcache(axiA_arcache),.axiA_awqos(axiA_awqos),.axiA_awprot(axiA_awprot),.axiA_arsize(axiA_arsize),.axiA_arregion(axiA_arregion),.axiA_arready(axiA_arready),.axiA_arqos(axiA_arqos),.axiA_arprot(axiA_arprot),.axiA_arlock(axiA_arlock),.axiA_arlen(axiA_arlen),.axiA_arid(axiA_arid),.axiA_awcache(axiA_awcache),.axiA_awburst(axiA_awburst),.axiA_awaddr(axiA_awaddr),.axiAInterrupt(axiAInterrupt),.axiA_rlast(axiA_rlast),.jtagCtrl_enable(jtagCtrl_enable),.jtagCtrl_tdi(jtagCtrl_tdi),.jtagCtrl_capture(jtagCtrl_capture),.jtagCtrl_shift(jtagCtrl_shift),.jtagCtrl_update(jtagCtrl_update),.jtagCtrl_reset(jtagCtrl_reset),.jtagCtrl_tdo(jtagCtrl_tdo),.jtagCtrl_tck(jtagCtrl_tck),.axiA_araddr(axiA_araddr),.axiA_wvalid(axiA_wvalid),.axiA_wready(axiA_wready),.axiA_wdata(axiA_wdata),.axiA_wstrb(axiA_wstrb),.axiA_wlast(axiA_wlast),.axiA_bvalid(axiA_bvalid),.axiA_bready(axiA_bready),.axiA_bid(axiA_bid),.axiA_bresp(axiA_bresp),.axiA_rvalid(axiA_rvalid),.axiA_rready(axiA_rready),.axiA_rdata(axiA_rdata),.axiA_rid(axiA_rid),.axiA_rresp(axiA_rresp),.axiA_arvalid(axiA_arvalid),.axiA_awid(axiA_awid),.axiA_awregion(axiA_awregion),.axiA_awvalid(axiA_awvalid),.io_ddrA_r_payload_last(io_ddrA_r_payload_last),.io_ddrA_r_payload_resp(io_ddrA_r_payload_resp),.io_ddrA_r_payload_id(io_ddrA_r_payload_id),.io_ddrA_r_payload_data(io_ddrA_r_payload_data),.io_ddrA_r_ready(io_ddrA_r_ready),.io_ddrA_r_valid(io_ddrA_r_valid),.io_ddrA_b_payload_resp(io_ddrA_b_payload_resp),.io_ddrA_b_payload_id(io_ddrA_b_payload_id),.io_ddrA_b_ready(io_ddrA_b_ready),.io_ddrA_b_valid(io_ddrA_b_valid),.io_ddrA_w_payload_last(io_ddrA_w_payload_last),.io_ddrA_w_ready(io_ddrA_w_ready),.io_ddrA_w_valid(io_ddrA_w_valid),.io_ddrA_aw_payload_prot(io_ddrA_aw_payload_prot),.io_ddrA_aw_payload_qos(io_ddrA_aw_payload_qos),.io_ddrA_aw_payload_cache(io_ddrA_aw_payload_cache),.io_ddrA_aw_payload_lock(io_ddrA_aw_payload_lock),.io_ddrA_aw_payload_burst(io_ddrA_aw_payload_burst),.io_ddrA_aw_payload_size(io_ddrA_aw_payload_size),.io_ddrA_aw_payload_len(io_ddrA_aw_payload_len),.io_ddrA_aw_payload_region(io_ddrA_aw_payload_region),.io_ddrA_aw_payload_id(io_ddrA_aw_payload_id),.io_ddrA_aw_payload_addr(io_ddrA_aw_payload_addr),.io_ddrA_aw_ready(io_ddrA_aw_ready),.io_ddrA_aw_valid(io_ddrA_aw_valid),.io_ddrA_ar_payload_prot(io_ddrA_ar_payload_prot),.io_ddrA_ar_payload_qos(io_ddrA_ar_payload_qos),.io_ddrA_ar_payload_cache(io_ddrA_ar_payload_cache),.io_ddrA_ar_payload_lock(io_ddrA_ar_payload_lock),.io_ddrA_ar_payload_burst(io_ddrA_ar_payload_burst),.io_ddrA_ar_payload_size(io_ddrA_ar_payload_size),.io_ddrA_ar_payload_len(io_ddrA_ar_payload_len),.io_ddrA_ar_payload_region(io_ddrA_ar_payload_region),.io_ddrA_ar_payload_id(io_ddrA_ar_payload_id),.io_ddrA_ar_payload_addr(io_ddrA_ar_payload_addr),.io_ddrA_ar_ready(io_ddrA_ar_ready),.io_ddrA_ar_valid(io_ddrA_ar_valid),.system_spi_0_io_data_0_read(system_spi_0_io_data_0_read),.system_spi_0_io_data_0_write(system_spi_0_io_data_0_write),.system_spi_0_io_data_0_writeEnable(system_spi_0_io_data_0_writeEnable),.system_spi_0_io_data_1_read(system_spi_0_io_data_1_read),.system_spi_0_io_data_1_write(system_spi_0_io_data_1_write),.system_spi_0_io_data_1_writeEnable(system_spi_0_io_data_1_writeEnable),.system_spi_0_io_data_2_read(system_spi_0_io_data_2_read),.system_spi_0_io_data_2_write(system_spi_0_io_data_2_write),.system_spi_0_io_data_2_writeEnable(system_spi_0_io_data_2_writeEnable),.system_spi_0_io_data_3_read(system_spi_0_io_data_3_read),.system_spi_0_io_data_3_write(system_spi_0_io_data_3_write),.system_spi_0_io_data_3_writeEnable(system_spi_0_io_data_3_writeEnable),.system_spi_0_io_sclk_write(system_spi_0_io_sclk_write),.userInterruptA(userInterruptA),.io_apbSlave_0_PADDR(io_apbSlave_0_PADDR),.io_apbSlave_0_PENABLE(io_apbSlave_0_PENABLE),.io_apbSlave_0_PRDATA(io_apbSlave_0_PRDATA),.io_apbSlave_0_PREADY(io_apbSlave_0_PREADY),.io_apbSlave_0_PSEL(io_apbSlave_0_PSEL),.io_apbSlave_0_PSLVERROR(io_apbSlave_0_PSLVERROR),.io_apbSlave_0_PWDATA(io_apbSlave_0_PWDATA),.io_apbSlave_0_PWRITE(io_apbSlave_0_PWRITE),.io_asyncReset(io_asyncReset),.io_memoryClk(io_memoryClk),.io_systemReset(io_systemReset),.system_uart_0_io_txd(system_uart_0_io_txd),.io_memoryReset(io_memoryReset),.system_uart_0_io_rxd(system_uart_0_io_rxd),.system_i2c_0_io_scl_read(system_i2c_0_io_scl_read),.system_i2c_0_io_scl_write(system_i2c_0_io_scl_write),.system_i2c_0_io_sda_read(system_i2c_0_io_sda_read),.system_i2c_0_io_sda_write(system_i2c_0_io_sda_write),.system_gpio_0_io_writeEnable(system_gpio_0_io_writeEnable),.io_ddrMasters_0_reset(io_ddrMasters_0_reset),.io_ddrMasters_0_clk(io_ddrMasters_0_clk),.io_ddrMasters_0_r_payload_last(io_ddrMasters_0_r_payload_last),.io_ddrMasters_0_r_payload_resp(io_ddrMasters_0_r_payload_resp),.io_ddrMasters_0_r_payload_id(io_ddrMasters_0_r_payload_id),.io_ddrMasters_0_r_payload_data(io_ddrMasters_0_r_payload_data),.io_ddrMasters_0_r_ready(io_ddrMasters_0_r_ready),.io_ddrMasters_0_r_valid(io_ddrMasters_0_r_valid),.io_ddrMasters_0_ar_payload_prot(io_ddrMasters_0_ar_payload_prot),.io_ddrMasters_0_ar_payload_qos(io_ddrMasters_0_ar_payload_qos),.io_ddrMasters_0_ar_payload_cache(io_ddrMasters_0_ar_payload_cache),.io_ddrMasters_0_ar_payload_lock(io_ddrMasters_0_ar_payload_lock),.io_ddrMasters_0_ar_payload_burst(io_ddrMasters_0_ar_payload_burst),.io_ddrMasters_0_ar_payload_size(io_ddrMasters_0_ar_payload_size),.io_ddrMasters_0_ar_payload_len(io_ddrMasters_0_ar_payload_len),.io_ddrMasters_0_ar_payload_region(io_ddrMasters_0_ar_payload_region),.io_ddrMasters_0_ar_payload_id(io_ddrMasters_0_ar_payload_id),.io_ddrMasters_0_ar_payload_addr(io_ddrMasters_0_ar_payload_addr),.io_ddrMasters_0_ar_ready(io_ddrMasters_0_ar_ready),.io_ddrMasters_0_ar_valid(io_ddrMasters_0_ar_valid),.io_ddrMasters_0_b_payload_resp(io_ddrMasters_0_b_payload_resp),.io_ddrMasters_0_b_payload_id(io_ddrMasters_0_b_payload_id),.io_ddrMasters_0_b_ready(io_ddrMasters_0_b_ready),.io_ddrMasters_0_b_valid(io_ddrMasters_0_b_valid),.io_ddrMasters_0_w_payload_last(io_ddrMasters_0_w_payload_last),.io_ddrMasters_0_w_payload_strb(io_ddrMasters_0_w_payload_strb),.io_ddrMasters_0_w_payload_data(io_ddrMasters_0_w_payload_data),.io_ddrMasters_0_w_ready(io_ddrMasters_0_w_ready),.io_ddrMasters_0_w_valid(io_ddrMasters_0_w_valid),.io_ddrMasters_0_aw_payload_prot(io_ddrMasters_0_aw_payload_prot),.io_ddrMasters_0_aw_payload_qos(io_ddrMasters_0_aw_payload_qos),.io_ddrMasters_0_aw_payload_cache(io_ddrMasters_0_aw_payload_cache),.io_ddrMasters_0_aw_payload_lock(io_ddrMasters_0_aw_payload_lock),.io_ddrMasters_0_aw_payload_burst(io_ddrMasters_0_aw_payload_burst),.io_ddrMasters_0_aw_payload_size(io_ddrMasters_0_aw_payload_size),.io_ddrMasters_0_aw_payload_len(io_ddrMasters_0_aw_payload_len),.io_ddrMasters_0_aw_payload_region(io_ddrMasters_0_aw_payload_region),.io_ddrMasters_0_aw_payload_id(io_ddrMasters_0_aw_payload_id),.io_ddrMasters_0_aw_payload_addr(io_ddrMasters_0_aw_payload_addr),.io_ddrMasters_0_aw_ready(io_ddrMasters_0_aw_ready),.io_ddrMasters_0_aw_valid(io_ddrMasters_0_aw_valid),.system_gpio_0_io_write(system_gpio_0_io_write),.system_gpio_0_io_read(system_gpio_0_io_read),.system_spi_0_io_ss(system_spi_0_io_ss));
always @* begin io_systemClk=clk;io_memoryClk=clk;io_ddrMasters_0_clk=clk;end
reg [7:0] mem[0:524287];
integer cycle=0,reads=0,writes=0,j;
reg ra=0,wa=0;reg[31:0] raddr,waddr;integer rleft,wleft,rsize,wsize;reg[7:0] rid,wid;
initial begin
 for(j=0;j<524288;j=j+1)mem[j]=0;
 io_asyncReset=1;system_uart_0_io_rxd=1;io_apbSlave_0_PREADY=1;
 repeat(20)@(negedge clk);io_asyncReset=0;
end
always @(negedge clk)begin
 cycle=cycle+1;
 io_ddrA_ar_ready=!ra && !io_ddrA_r_valid && (cycle%5!=0);
 io_ddrA_aw_ready=!wa && !io_ddrA_b_valid && (cycle%7!=0);
 io_ddrA_w_ready=wa && (cycle%3!=0);
 if(cycle>850000000)$fatal(1,"CPU timeout reads=%0d writes=%0d",reads,writes);
end
always @(posedge clk)begin
 if(io_ddrA_ar_valid&&io_ddrA_ar_ready)begin
  ra<=1;raddr<=io_ddrA_ar_payload_addr;rleft<=io_ddrA_ar_payload_len+1;rsize<=1<<io_ddrA_ar_payload_size;rid<=io_ddrA_ar_payload_id;reads<=reads+1;
 end
 if(io_ddrA_r_valid&&io_ddrA_r_ready)begin io_ddrA_r_valid<=0;raddr<=raddr+rsize;rleft<=rleft-1;if(rleft==1)ra<=0;end
 if(ra&&!io_ddrA_r_valid&&cycle%4!=0)begin
  if(raddr<32'h02f00000||raddr>=32'h02f80000)$fatal(1,"read address %h",raddr);
  for(integer k=0;k<16;k=k+1)io_ddrA_r_payload_data[k*8+:8]<=mem[((raddr-32'h02f00000)&32'hfffffff0)+k];
  io_ddrA_r_payload_id<=rid;io_ddrA_r_payload_last<=(rleft==1);io_ddrA_r_valid<=1;
 end
 if(io_ddrA_aw_valid&&io_ddrA_aw_ready)begin wa<=1;waddr<=io_ddrA_aw_payload_addr;wleft<=io_ddrA_aw_payload_len+1;wsize<=1<<io_ddrA_aw_payload_size;wid<=io_ddrA_aw_payload_id;end
 if(io_ddrA_w_valid&&io_ddrA_w_ready)begin
  if(waddr<32'h02f00000||waddr>=32'h02f80000)$fatal(1,"write address %h",waddr);
  for(integer k=0;k<16;k=k+1)if(io_ddrA_w_payload_strb[k])mem[((waddr-32'h02f00000)&32'hfffffff0)+k]<=io_ddrA_w_payload_data[k*8+:8];
  if(io_ddrA_w_payload_last!=(wleft==1))$fatal(1,"WLAST");
  waddr<=waddr+wsize;wleft<=wleft-1;writes<=writes+1;
  if(wleft==1)begin wa<=0;io_ddrA_b_valid<=1;io_ddrA_b_payload_id<=wid;end
 end
 if(io_ddrA_b_valid&&io_ddrA_b_ready)io_ddrA_b_valid<=0;
 if(io_apbSlave_0_PSEL&&io_apbSlave_0_PENABLE&&io_apbSlave_0_PWRITE)begin
  if(io_apbSlave_0_PADDR!=16'h0084)$fatal(1,"unexpected first neural write %h",io_apbSlave_0_PADDR);
  if(corrupt)$fatal(1,"corrupt payload was accepted");
  for(integer k=0;k<330136;k++)if(mem[k]!==flash[k+256])$fatal(1,"model byte mismatch %0d",k);
  $display("AUTOBOOT_PASS real RV32 firmware from initialized RAM, 330136 bytes SPI to DDR, CRC and DDR readback, random AXI stalls, cycles=%0d",cycle);$finish;
 end
end
always @* io_apbSlave_0_PRDATA=io_apbSlave_0_PADDR==0?32'h50324e38:io_apbSlave_0_PADDR==16'h1000 ? 32'h56494431:0;
reg [7:0] flash[0:330391];
integer bit_count=0,flash_address=0;
reg [7:0] command=0,byte_shift=0,outbyte;
bit corrupt;
initial begin $readmemh("payload.hex",flash);corrupt=$test$plusargs("corrupt");if(corrupt)flash[1024]=flash[1024]^8'h80;end
always @(negedge system_spi_0_io_ss[0])begin bit_count<=0;flash_address=0;command=0;byte_shift=0;end
always @(posedge system_spi_0_io_sclk_write)if(!system_spi_0_io_ss[0])begin
 byte_shift={byte_shift[6:0],system_spi_0_io_data_0_write};
 if(bit_count%8==7)begin
  if(bit_count==7)command=byte_shift;
  else if(command==3 && bit_count<32)flash_address=(flash_address<<8)|int'(byte_shift);
 end
 bit_count<=bit_count+1;
end
always @* begin
 outbyte=8'hff;
 if(command==8'h9f)case(bit_count/8)1:outbyte=8'hc8;2:outbyte=8'h60;3:outbyte=8'h17;default:outbyte=8'hff;endcase
 if(command==3 && bit_count>=32 && flash_address>=32'h400000 && flash_address+bit_count/8-4<32'h450a98)
  outbyte=flash[flash_address-32'h400000+bit_count/8-4];
 system_spi_0_io_data_1_read=outbyte[7-(bit_count%8)];
end

wire[31:0] error_word={dut.u_EfxSapphireSoc.system_ramA_logic.ram_symbol3[2520],dut.u_EfxSapphireSoc.system_ramA_logic.ram_symbol2[2520],dut.u_EfxSapphireSoc.system_ramA_logic.ram_symbol1[2520],dut.u_EfxSapphireSoc.system_ramA_logic.ram_symbol0[2520]};
always @(negedge clk)if(cycle>10000 && error_word!=0)begin
 if(corrupt && error_word==32'hb004)begin $display("AUTOBOOT_CORRUPT_PASS invalid weights stopped before inference");$finish;end
 else $fatal(1,"firmware boot error %h cycles=%d",error_word,cycle);
end
endmodule
