
/////////////////////////////////////////////////////////////////////////////
//
// Copyright (C) 2013-2021 Efinix Inc. All rights reserved.
//
// Description:
// Example top file for ti60f225 dev kit OOB design
//
// Language:  Verilog 2001
//
// ------------------------------------------------------------------------------

/////////////////////////////////////////////////////////////////////////////////
//`define SOFT_TAP 1
`include "ddr3_controller/ddr3_parameter.vh"
// `include "define.v"

module ti60f225_oob_top #(

	parameter                       RANK_RATIO         = 1,       // # of unique CS outputs per rank
	parameter                       ASYN_AXI_CLK       = `ASYN_AXI_CLK, 
	parameter                       RANKS              = `RANKS,
	parameter                       CK_WIDTH           = `CK_WIDTH,       // # of CK/CK# outputs to memory   
	parameter                       CKE_WIDTH          = `CKE_WIDTH,       // # of cke outputs
	parameter                       CS_WIDTH           = `CS_WIDTH,       // # of unique CS outputs
	parameter                       BANK_WIDTH         = `BANK_WIDTH,       // # of bank bits
	parameter                       ROW_WIDTH          = `ROW_WIDTH,       // DRAM address bus width
	parameter                       COL_WIDTH          = `COL_WIDTH,      // column address width
	parameter                       DM_WIDTH           = `DM_WIDTH,       // # of DM (data mask)
	parameter                       DQS_WIDTH          = `DQS_WIDTH,       // # of DQS (strobe)
	parameter                       DQ_WIDTH           = `DQ_WIDTH,      // # of DQ (data)
	parameter                       ODT_WIDTH          = `ODT_WIDTH,
	parameter                       DQ_CNT_WIDTH       = `DQ_CNT_WIDTH,       // = ceil(log2(DQ_WIDTH))
	parameter                       DQS_CNT_WIDTH      = `DQS_CNT_WIDTH,       // = ceil(log2(DQS_WIDTH))  
	parameter                       DRAM_WIDTH         = `DRAM_WIDTH,       // # of DQ per DQS   
	parameter                       DATA_WIDTH         = `DATA_WIDTH,
	parameter                       ADDR_WIDTH         = `ADDR_WIDTH,    
	parameter                       AXI_ID_WIDTH       = `AXI_ID_WIDTH,
	parameter                       AXI_ADDR_WIDTH     = `AXI_ADDR_WIDTH,
	parameter                       AXI_DATA_WIDTH     = `AXI_DATA_WIDTH
)
(

  (* syn_peri_port = 0 *) input jtag_inst1_CAPTURE,
  (* syn_peri_port = 0 *) input jtag_inst1_DRCK,
  (* syn_peri_port = 0 *) input jtag_inst1_RESET,
  (* syn_peri_port = 0 *) input jtag_inst1_RUNTEST,
  (* syn_peri_port = 0 *) input jtag_inst1_SEL,
  (* syn_peri_port = 0 *) input jtag_inst1_SHIFT,
  (* syn_peri_port = 0 *) input jtag_inst1_TCK,
  (* syn_peri_port = 0 *) input jtag_inst1_TDI,
  (* syn_peri_port = 0 *) input jtag_inst1_TMS,
  (* syn_peri_port = 0 *) input jtag_inst1_UPDATE,
  (* syn_peri_port = 0 *) output jtag_inst1_TDO,

   output system_spi_0_io_sclk_write,
   output system_spi_0_io_ss,
   output system_spi_0_io_data_0_OUT, output system_spi_0_io_data_0_OE,
   input system_spi_0_io_data_0_IN,
   output system_spi_0_io_data_1_OUT, output system_spi_0_io_data_1_OE,
   input system_spi_0_io_data_1_IN,
   //Clocks 
	input	wire	i_arstn,
    input	wire	i_mipi_rx_pclk,
    input wire  vid_clk_dvi2,
    input wire hdmi_tx_slow_clk,
    input wire CLK_5M,
    input  wire CLK_25M,
	output  wire    pll_inst1_RSTN,
	input	wire	i_pll_locked,
	input 	wire  	pll_locked,
	output  wire    pll_inst4_RSTN,
	input   wire    pll_inst4_LOCKED,
	output  wire  	USER_PLL_RSTN,
    output 	wire 	DDR3_PLL_RSTN,
	input 	wire  	user_pll_locked,
    //CSI Interface
    input	 wire		io_cam_sda_IN,
    output wire   io_cam_sda_OUT,
    output wire		io_cam_sda_OE,

    output io_cam_scl_OUT,
    input io_cam_scl_IN,
    output io_cam_scl_OE,

    output	wire		o_cam_rst_p,
    
    input	wire		i_cam_ck_LP_P_IN,
    input	wire		i_cam_ck_LP_N_IN,
    output	wire		o_cam_ck_HS_TERM,
    output	wire		o_cam_ck_HS_ENA,
    input	wire		i_cam_ck_CLKOUT,
    
    input	wire	[7:0]			cam_d0_HS_IN,
    input	  wire		      cam_d0_LP_P_IN,
    input	  wire		      cam_d0_LP_N_IN,
    output	wire		      cam_d0_HS_TERM,
    output	wire		      cam_d0_HS_ENA,
    output	wire		      cam_d0_RST,
    output	wire		      cam_d0_FIFO_RD,
    input	  wire		      cam_d0_FIFO_EMPTY,
    
    input 	wire	[7:0]			cam_d1_HS_IN,
    input	  wire		        cam_d1_LP_P_IN,
    input	  wire		        cam_d1_LP_N_IN,
    output	wire		        cam_d1_HS_TERM,
    output	wire		        cam_d1_HS_ENA,
    output	wire		        cam_d1_RST,
    output	wire		        cam_d1_FIFO_RD,
    input	  wire		        cam_d1_FIFO_EMPTY,
    
    input 	wire	[7:0]			cam_d2_HS_IN,
    input	  wire		        cam_d2_LP_P_IN,
    input	  wire		        cam_d2_LP_N_IN,
    output	wire		        cam_d2_HS_TERM,
    output	wire		        cam_d2_HS_ENA,
    output	wire		        cam_d2_RST,
    output	wire		        cam_d2_FIFO_RD,
    input	  wire		        cam_d2_FIFO_EMPTY,  
   
    input 	wire	[7:0]			cam_d3_HS_IN,
    input	  wire		        cam_d3_LP_P_IN,
    input	  wire		        cam_d3_LP_N_IN,
    output	wire		        cam_d3_HS_TERM,
    output	wire		        cam_d3_HS_ENA,
    output	wire		        cam_d3_RST,
    output	wire		        cam_d3_FIFO_RD,
    input	  wire		        cam_d3_FIFO_EMPTY,

	
	input 					tx_cal_clk_90edge,
  	input 					rx_cal_clk,
  	input 					tx_cal_clk,
	input                              core_clk,     // CORE CLK @ 100MHz
	input                              sdram_clk,    // SDRAM CK @ 400MHz
	// PLL status flags  
	output [2:0]                       pll_shift,  
	output [4:0]                       pll_shift_sel,
	output                             pll_shift_ena,  
	// memory interface ports
	output                             ddr_ck_hi,
	output                             ddr_ck_lo,
	output                             ddr_reset_n,
	output [CKE_WIDTH-1:0]             ddr_cke,     
	output [ROW_WIDTH-1:0]             ddr_addr,
	output [BANK_WIDTH-1:0]            ddr_ba,
	output                             ddr_cas_n,
 
	output [CS_WIDTH*RANK_RATIO-1:0]   ddr_cs_n,
	output                             ddr_ras_n,
	output                             ddr_we_n,
	
	input  [DQS_WIDTH-1:0]             ddr_dqs_in_hi,
	input  [DQS_WIDTH-1:0]             ddr_dqs_in_lo,
	input  [DQ_WIDTH-1:0]              ddr_dq_in_hi,
	input  [DQ_WIDTH-1:0]              ddr_dq_in_lo,
	
	output [DQS_WIDTH-1:0]             ddr_dqs_oe,
	output [DQS_WIDTH-1:0]             ddr_dqs_oe_n,
	output [DQ_WIDTH-1:0]              ddr_dq_oe,  
	output [DQS_WIDTH-1:0]             ddr_dqs_out_hi,
	output [DQS_WIDTH-1:0]             ddr_dqs_out_lo,
	output [DQ_WIDTH-1:0]              ddr_dq_out_hi,
	output [DQ_WIDTH-1:0]              ddr_dq_out_lo,
	output [DM_WIDTH-1:0]              ddr_dm_hi,
	output [DM_WIDTH-1:0]              ddr_dm_lo,
	output [ODT_WIDTH-1:0]             ddr_odt,

       //LED
       output [3:0] led,

       // MIPI DSI
       input	wire	                     i_mipi_tx_pclk		,
       output	wire	                     mipi_dp_clk_LP_P_OUT		,
       output	wire	                     mipi_dp_clk_LP_N_OUT		,
       output	wire	[7:0] 	              mipi_dp_clk_HS_OUT		,
       output	wire	                     mipi_dp_clk_HS_OE		,
       output	wire	                     mipi_dp_data3_LP_P_OUT	,
       output	wire	                     mipi_dp_data2_LP_P_OUT	,
       output	wire	                     mipi_dp_data1_LP_P_OUT	,
       output	wire	                     mipi_dp_data0_LP_P_OUT	,
       output	wire	                     mipi_dp_data3_LP_N_OUT	,
       output	wire	                     mipi_dp_data2_LP_N_OUT	,
       output	wire	                     mipi_dp_data1_LP_N_OUT	,
       output	wire	                     mipi_dp_data0_LP_N_OUT	,
       output	wire	[7:0] 	              mipi_dp_data0_HS_OUT	       ,
       output	wire	[7:0] 	              mipi_dp_data1_HS_OUT	       ,
       output	wire	[7:0] 	              mipi_dp_data2_HS_OUT	       ,
       output	wire	[7:0] 	              mipi_dp_data3_HS_OUT	       ,
       output	wire	                     mipi_dp_data3_HS_OE		,
       output	wire	                     mipi_dp_data2_HS_OE		,
       output	wire	                     mipi_dp_data1_HS_OE		,
       output	wire	                     mipi_dp_data0_HS_OE		,

       output	wire	                     mipi_dp_clk_RST		,
       output	wire	                     mipi_dp_data0_RST		,
       output	wire	                     mipi_dp_data1_RST		,
       output	wire	                     mipi_dp_data2_RST		,
       output	wire	                     mipi_dp_data3_RST		,
       output	wire	                     mipi_dp_clk_LP_P_OE		,
       output	wire	                     mipi_dp_clk_LP_N_OE		,
       output	wire	                     mipi_dp_data3_LP_P_OE	,
       output	wire	                     mipi_dp_data3_LP_N_OE	,
       output	wire	                     mipi_dp_data2_LP_P_OE	,
       output	wire	                     mipi_dp_data2_LP_N_OE	,
       output	wire	                     mipi_dp_data1_LP_P_OE	,
       output	wire	                     mipi_dp_data1_LP_N_OE	,
       output	wire	                     mipi_dp_data0_LP_P_OE	,
       output	wire	                     mipi_dp_data0_LP_N_OE	,

       input  wire	                     mipi_dp_data0_LP_P_IN	,
       input  wire	                     mipi_dp_data0_LP_N_IN	,
       output	wire	                     LCD_RST_P			,
       output wire                        LCD_POWER			,

       // hdmi interface

    output tmds_tx_clk_TX_OE,
    output [9:0] tmds_tx_clk_TX_DATA,
    output tmds_tx_clk_TX_RST,
    output tmds_tx_data0_TX_OE,
    output [9:0] tmds_tx_data0_TX_DATA,
    output tmds_tx_data0_TX_RST,
    output tmds_tx_data1_TX_OE,
    output [9:0] tmds_tx_data1_TX_DATA,
    output tmds_tx_data1_TX_RST,
    output tmds_tx_data2_TX_OE,
    output [9:0] tmds_tx_data2_TX_DATA,
    output tmds_tx_data2_TX_RST


);

function integer log2;
	input	integer	val;
	integer	i;
	begin
		log2 = 0;
		for (i=0; 2**i<val; i=i+1)
			log2 = i+1;
	end
endfunction


//===============================================================================
//localparam
//===============================================================================
localparam WR_FIFO_DEPTH  = 1024;
localparam RD_FIFO_DEPTH  = 1024;

// localparam	MAX_HRES		= 12'd1920;
// localparam	MAX_VRES		= 12'd1080;
// localparam	HSP			= 8'd2;
// localparam	HBP			= 8'd88;
// localparam	HFP			= 8'd120;
// localparam	VSP			= 8'd2;
// localparam	VBP			= 8'd20;
// localparam	VFP			= 8'd20;

localparam MAX_HRES = 1920;
localparam HFP      = 88;
localparam HSP      = 44;
localparam HBP      = 148;

localparam MAX_VRES = 1080;
localparam VFP      = 4;
localparam VSP      = 5;
localparam VBP      = 36;
//===============================================================================
//signal
//===============================================================================
   
wire                              app_sr_active;
wire                              app_ref_ack;
wire                              app_zq_ack;
wire                              cal_done;

// Slave Interface Write Address Ports
wire [AXI_ID_WIDTH-1:0]           s_axi_awid;
wire [AXI_ADDR_WIDTH-1:0]         s_axi_awaddr;
wire [7:0]                        s_axi_awlen;
wire [2:0]                        s_axi_awsize;
wire [1:0]                        s_axi_awburst;
wire [0:0]                        s_axi_awlock;
wire [3:0]                        s_axi_awcache;
wire [2:0]                        s_axi_awprot;
wire                              s_axi_awvalid;
wire                              s_axi_awready;
// Slave Interface Write Data Ports
wire [AXI_DATA_WIDTH-1:0]         s_axi_wdata;
wire [(AXI_DATA_WIDTH/8)-1:0]     s_axi_wstrb;
wire                              s_axi_wlast;
wire                              s_axi_wvalid;
wire                              s_axi_wready;
// Slave Interface Write Response Ports
wire                              s_axi_bready;
wire [AXI_ID_WIDTH-1:0]           s_axi_bid;
wire [1:0]                        s_axi_bresp;
wire                              s_axi_bvalid;
// Slave Interface Read Address Ports
wire [AXI_ID_WIDTH-1:0]           s_axi_arid;
wire [AXI_ADDR_WIDTH-1:0]         s_axi_araddr;
wire [7:0]                        s_axi_arlen;
wire [2:0]                        s_axi_arsize;
wire [1:0]                        s_axi_arburst;
wire [0:0]                        s_axi_arlock;
wire [3:0]                        s_axi_arcache;
wire [2:0]                        s_axi_arprot;
wire                              s_axi_arvalid;
wire                              s_axi_arready;
// Slave Interface Read Data Ports
wire                              s_axi_rready;
wire [AXI_ID_WIDTH-1:0]           s_axi_rid;
wire [AXI_DATA_WIDTH-1:0]         s_axi_rdata;
wire [1:0]                        s_axi_rresp;
wire                              s_axi_rlast;
wire                              s_axi_rvalid;




////////////////////////////////////////////////////////////////
// System & Debugger
wire    w_arstn;
// wire	w_sysclk_mcu_arstn;
// wire	w_sysclk_mcu_arst;
wire	w_mipi_rx_pclk_arstn;
wire	w_mipi_rx_pclk_arst;

wire		       w_mipi_rx_vs;
wire		       w_mipi_rx_hs;
wire	       w_mipi_rx_de;
wire	[63:0]			w_mipi_rx_data	;

wire					io_systemReset;



//===================================================================================================
//reset module
//===================================================================================================

assign w_arstn  		       = i_pll_locked & pll_locked & user_pll_locked;
assign pll_inst1_RSTN  		= i_arstn;
assign USER_PLL_RSTN      		= i_arstn;
assign mipi_dsi_tx_pll_RSTN 	= i_arstn;
assign DDR3_PLL_RSTN 		= i_arstn;
reset_ctrl
#(
	.NUM_RST		(2),
	.CYCLE			(1),
	.IN_RST_ACTIVE	(4'b00),
	.OUT_RST_ACTIVE	(4'b10)
)
inst_reset_ctrl
(
	.i_arst		({2{w_arstn}}),//({{4{i_pll_locked}},                  {2{i_arstn}}}),
	.i_clk			({2{i_mipi_rx_pclk}}),
	.o_srst		({w_mipi_rx_pclk_arst, w_mipi_rx_pclk_arstn})
);



reg [25:0] cnt = 'd0;
always @( posedge core_clk)
begin 
       cnt <= cnt + 1'b1;
end
assign led[0]  = cal_done ? cnt[24] : 1'b0;

//========================================================================================================
//MIPI RX
//========================================================================================================
wire i_mipi_clk ;
assign i_mipi_clk = core_clk;

		assign	cam_d0_RST		= 1'b0;
		assign	cam_d1_RST		= 1'b0;
		assign  cam_d2_RST = 1'b0;
    assign  cam_d3_RST = 1'b0;
	
	
		

		csi_rx_controller inst_efx_csi2_rx
		(
              .reset_n			(i_arstn),
              .clk				(i_mipi_clk),
              .reset_byte_HS_n	(i_arstn),
              .clk_byte_HS		  (i_cam_ck_CLKOUT),
              .reset_pixel_n		(w_mipi_rx_pclk_arstn),
              .clk_pixel			  (i_mipi_rx_pclk),
              
              .Rx_LP_CLK_P		  (i_cam_ck_LP_P_IN),
              .Rx_LP_CLK_N		  (i_cam_ck_LP_N_IN),
              .Rx_HS_enable_C		(o_cam_ck_HS_ENA),
              .LVDS_termen_C		(o_cam_ck_HS_TERM),
              
              .Rx_LP_D_P			({cam_d3_LP_P_IN, cam_d2_LP_P_IN, cam_d1_LP_P_IN, cam_d0_LP_P_IN}),//(r_mipi_rx_data_LP_P_IN_2P),
              .Rx_LP_D_N			({cam_d3_LP_N_IN, cam_d2_LP_N_IN, cam_d1_LP_N_IN, cam_d0_LP_N_IN}),//(r_mipi_rx_data_LP_N_IN_2P),
              .Rx_HS_D_0			(cam_d0_HS_IN),//(r_mipi_rx_data_HS_IN_2P[0*8+:8]),
              .Rx_HS_D_1			(cam_d1_HS_IN),//(r_mipi_rx_data_HS_IN_2P[1*8+:8]),
              .Rx_HS_D_2			(cam_d2_HS_IN),
              .Rx_HS_D_3			(cam_d3_HS_IN),
              .Rx_HS_D_4			(),
              .Rx_HS_D_5			(),
              .Rx_HS_D_6			(),
              .Rx_HS_D_7			(),
              .Rx_HS_enable_D		({cam_d3_HS_ENA    ,cam_d2_HS_ENA    ,cam_d1_HS_ENA    ,cam_d0_HS_ENA    }),//( w_cam_d_HS_ENA),
              .LVDS_termen_D		({cam_d3_HS_TERM   ,cam_d2_HS_TERM   ,cam_d1_HS_TERM   ,cam_d0_HS_TERM   }),
              .fifo_rd_enable		({cam_d3_FIFO_RD   ,cam_d2_FIFO_RD   ,cam_d1_FIFO_RD   ,cam_d0_FIFO_RD   }),
              .fifo_rd_empty		({cam_d3_FIFO_EMPTY,cam_d2_FIFO_EMPTY,cam_d1_FIFO_EMPTY,cam_d0_FIFO_EMPTY}),
              .DLY_enable_D		       (),
              .DLY_inc_D			(),
              .u_dly_enable_D		(),
              .u_dly_inc_D		       (),
              
              .axi_clk			(1'b0),
              .axi_reset_n		       (1'b0),
              .axi_awaddr			(6'b0),
              .axi_awvalid		       (1'b0),
              .axi_awready		       (),
              .axi_wdata			(32'b0),
              .axi_wvalid			(1'b0),
              .axi_wready			(),
              
              .axi_bvalid			(),
              .axi_bready			(1'b0),
              .axi_araddr			(6'b0),
              .axi_arvalid		       (1'b0),
              .axi_arready		       (),
              .axi_rdata			(),
              .axi_rvalid			(),
              .axi_rready			(1'b1),
              
              .hsync_vc0			(w_mipi_rx_hs),
              .hsync_vc1			(),
              .hsync_vc2			(),
              .hsync_vc3			(),
              .vsync_vc0			(w_mipi_rx_vs),
              .vsync_vc1			(),
              .vsync_vc2			(),
              .vsync_vc3			(),
              .vc				(),
              .word_count			(),
              .shortpkt_data_field        (),
              .datatype			(),
              .pixel_per_clk		(),
              .pixel_data			(w_mipi_rx_data),
              .pixel_data_valid	       (w_mipi_rx_de),
              .irq				()
		);

//     wire		       w1_mipi_rx_vs;
// wire		       w1_mipi_rx_hs;
// wire	       w1_mipi_rx_de;
// wire	[39:0]			w1_mipi_rx_data	;
// sensor_clipper  sensor_clipper_inst (
//     .clk(i_mipi_rx_pclk),
//     .i_vs(w_mipi_rx_vs),
//     .i_hs(w_mipi_rx_hs),
//     .i_de(w_mipi_rx_de),
//     .i_dat(w_mipi_rx_data[39:0]),

//     .o_hs(w1_mipi_rx_hs),
//     .o_vs(w1_mipi_rx_vs),
//     .o_de(w1_mipi_rx_de),
//     .o_dat(w1_mipi_rx_data)
   
//   );

//========================================================================================================
//
//========================================================================================================
		

//*************** imx219 config********************/
// mipi_config_imx219_top u_config_imx219(
// 										.i_sys_clk(CLK_5M)    	,    /////48M 
// 										.sys_rstn(vid_rst_n )    ,
// 										.o_sen_rst_n(o_cam_rstn)  	,
										
										// .o_iic_sda_OE(io_cam_sda_OE) ,
										// .i_iic_sda(io_cam_sda_IN)   	,
										// .o_iic_sda(io_cam_sda_OUT)   	,
										// .o_iic_scl(io_cam_scl)    	
										// ); 	

wire scl_padoen_o;
wire sda_padoen_o;


// Sensor initialization moved to RISC-V GPIO peripheral below.
//=====================================================================================
//frame buffer
//=====================================================================================
wire [7:0] 	ch0_r;
wire [7:0]    ch0_g;
wire [7:0]    ch0_b;
wire ch0_vs;
wire ch0_hs;
wire ch0_de;
// RAW line streaming: no RAW frame reads or writes through DDR.
reg raw_vs_d;
always @(posedge i_mipi_rx_pclk or negedge vid_rst_n)
 if(!vid_rst_n)raw_vs_d<=0;else raw_vs_d<=w_mipi_rx_vs;
wire[31:0] raw_dropped_frames,raw_committed_lines,raw_output_lines;
raw_line_bridge raw_stream(
 .s_clk(i_mipi_rx_pclk),.m_clk(vid_clk_dvi2),.rst_n(vid_rst_n),
 .s_sof(w_mipi_rx_vs&&!raw_vs_d),.s_valid(w_mipi_rx_de&&w_mipi_rx_hs),
 .s_data({w_mipi_rx_data[39:32],w_mipi_rx_data[29:22],w_mipi_rx_data[19:12],w_mipi_rx_data[9:2]}),
 .o_vs(ch0_vs),.o_hs(ch0_hs),.o_de(ch0_de),.o_data({ch0_g,ch0_b}),
 .dropped_frames(raw_dropped_frames),.committed_lines(raw_committed_lines),.output_lines(raw_output_lines));
assign ch0_r=0;
assign cam_axi_awid='0;


assign cam_axi_awsize=3'd4;
assign cam_axi_awburst=2'b01;
assign cam_axi_awprot='0;
assign cam_axi_awcache='0;
assign cam_axi_awlock='0;

assign cam_axi_arid='0;


assign cam_axi_arsize=3'd4;
assign cam_axi_arburst=2'b01;
assign cam_axi_arprot='0;
assign cam_axi_arcache='0;
assign cam_axi_arlock='0;










ddr3_top                 u_ddr3_top
(

.axi_clk                (core_clk            ),
.core_clk               (core_clk            ),
.sdram_clk              (sdram_clk           ),  
.rx_cal_clk             (rx_cal_clk          ),
.tx_cal_clk             (tx_cal_clk          ),
.tx_cal_clk_90edge      (tx_cal_clk_90edge   ),
.rstn                   (w_arstn             ),      
.pll_shift              (pll_shift           ),
.pll_shift_sel          (pll_shift_sel       ),
.pll_shift_ena          (pll_shift_ena       ),       
///////////////DDR BUS
.ddr_ck_hi              (ddr_ck_hi           ),
.ddr_ck_lo              (ddr_ck_lo           ),
.ddr_cke                (ddr_cke             ),    
.ddr_reset_n            (ddr_reset_n         ),
.ddr_cs_n               (ddr_cs_n            ),
.ddr_ras_n              (ddr_ras_n           ),
.ddr_cas_n              (ddr_cas_n           ),
.ddr_we_n               (ddr_we_n            ),     
.ddr_addr               (ddr_addr            ),
.ddr_ba                 (ddr_ba              ),

.ddr_dqs_oe             (ddr_dqs_oe          ),
.ddr_dqs_oe_n           (ddr_dqs_oe_n        ),
.ddr_dq_oe              (ddr_dq_oe           ),
.ddr_dqs_in_hi          (ddr_dqs_in_hi       ),
.ddr_dqs_in_lo          (ddr_dqs_in_lo       ),
.ddr_dq_in_hi           (ddr_dq_in_hi        ),
.ddr_dq_in_lo           (ddr_dq_in_lo        ),

.ddr_dqs_out_hi         (ddr_dqs_out_hi      ),
.ddr_dqs_out_lo         (ddr_dqs_out_lo      ),
.ddr_dq_out_hi          (ddr_dq_out_hi       ),
.ddr_dq_out_lo          (ddr_dq_out_lo       ),

.ddr_dm_hi              (ddr_dm_hi           ),
.ddr_dm_lo              (ddr_dm_lo           ),
.ddr_odt                (ddr_odt             ),

// Application interface ports
.app_sr_req                     (1'b0),
.app_ref_req                    (1'b0),
.app_zq_req                     (1'b0),
.app_sr_active                  (app_sr_active),
.app_ref_ack                    (app_ref_ack),
.app_zq_ack                     (app_zq_ack),

// Slave Interface Write Address Ports
.s_axi_awid                     (s_axi_awid        ),
.s_axi_awaddr                   (s_axi_awaddr      ),
.s_axi_awlen                    (s_axi_awlen       ),
.s_axi_awsize                   (s_axi_awsize      ),
.s_axi_awburst                  (s_axi_awburst     ),
.s_axi_awlock                   (s_axi_awlock      ),
.s_axi_awcache                  (s_axi_awcache     ),
.s_axi_awprot                   (s_axi_awprot      ),
.s_axi_awqos                    (4'h0              ),
.s_axi_awvalid                  (s_axi_awvalid     ),
.s_axi_awready                  (s_axi_awready     ),
// Slave Interface Write Data Ports
.s_axi_wdata                    (s_axi_wdata       ),
.s_axi_wstrb                    (s_axi_wstrb       ),
.s_axi_wlast                    (s_axi_wlast       ),
.s_axi_wvalid                   (s_axi_wvalid      ),
.s_axi_wready                   (s_axi_wready      ),
// Slave Interface Write Response Ports
.s_axi_bid                      (s_axi_bid         ),
.s_axi_bresp                    (s_axi_bresp       ),
.s_axi_bvalid                   (s_axi_bvalid      ),
.s_axi_bready                   (s_axi_bready      ),
// Slave Interface Read Address Ports
.s_axi_arid                     (s_axi_arid        ),
.s_axi_araddr                   (s_axi_araddr      ),
.s_axi_arlen                    (s_axi_arlen       ),
.s_axi_arsize                   (s_axi_arsize      ),
.s_axi_arburst                  (s_axi_arburst     ),
.s_axi_arlock                   (s_axi_arlock      ),
.s_axi_arcache                  (s_axi_arcache     ),
.s_axi_arprot                   (s_axi_arprot      ),
.s_axi_arqos                    (4'h0              ),
.s_axi_arvalid                  (s_axi_arvalid     ),
.s_axi_arready                  (s_axi_arready     ),
// Slave Interface Read Data Ports
.s_axi_rid                      (s_axi_rid         ),
.s_axi_rdata                    (s_axi_rdata       ),
.s_axi_rresp                    (s_axi_rresp       ),
.s_axi_rlast                    (s_axi_rlast       ),
.s_axi_rvalid                   (s_axi_rvalid      ),
.s_axi_rready                   (s_axi_rready      ),
//DEBUG       
.wrlvl_dq_check                 (wrlvl_dq_check    ) ,
.rd_level_dqs_check             (rd_level_dqs_check) ,
.init_cur_state                 (init_cur_state    ) ,
.idelay_ld                      (idelay_ld         ) ,
.mpr_rdlvl_dly                  (mpr_rdlvl_dly     ) ,
.cal_done                       (cal_done          ) 
);

//***************************************************************************
// debayer
//***************************************************************************


wire        rgb_vs;
wire        rgb_hs;
wire        rgb_de;
wire        rgb_valid;
wire [47:0] rgb_datax2;
wire [15:0] r_gain;
wire [15:0] g_gain;
wire [15:0] b_gain;

debayer_top_2to1 debayer_top
(
	.in_pclk		  (vid_clk_dvi2),//(i_mipi_rx_pclk ),
	.in_rstn		  (vid_rst_n	),
	
	.raw_vs_i		  (ch0_vs		      ),
	.raw_hs_i		  (ch0_hs		      ),
	.raw_de_i		  (ch0_de		      ),
	.raw_valid_i	(ch0_de	        ),
	.raw_datax4_i	({ch0_b,ch0_g}	),
	.r_gain       (|r_gain? r_gain:255 ),
  .g_gain       (|g_gain? g_gain:255 ),
  .b_gain       (|b_gain? b_gain:255 ),
	.rgb_vs_o		  (rgb_vs         ),
	.rgb_hs_o		  (rgb_hs         ),
	.rgb_de_o		  (rgb_de         ),
	.rgb_valid_o	(rgb_valid      ),
	.rgb_datax2_o (rgb_datax2     )//b,g,r,b,g,r
);
reg rgb_vs_r = 'd0;
always @( posedge hdmi_tx_slow_clk )
begin
  rgb_vs_r <= rgb_vs;
end
assign pos_vs = {rgb_vs_r,rgb_vs} == 2'b01;
reg vid_cnt = 'd0;
reg [7:0] hdmi_tx_rdata ;
reg [7:0] hdmi_tx_gdata ;
reg [7:0] hdmi_tx_bdata ;
reg hdmi_tx_vs;
reg hdmi_tx_hs;
reg hdmi_tx_de;
always @( posedge hdmi_tx_slow_clk )
begin
    if( pos_vs )
      vid_cnt <= 1'b1;
    else if( rgb_de )
      vid_cnt <= ~vid_cnt ;

    if( vid_cnt )
      {hdmi_tx_bdata,hdmi_tx_gdata,hdmi_tx_rdata} <= rgb_datax2[23:0];
    else 
      {hdmi_tx_bdata,hdmi_tx_gdata,hdmi_tx_rdata} <= rgb_datax2[47:24];

  hdmi_tx_vs <= rgb_vs;
  hdmi_tx_hs <= rgb_hs;
  hdmi_tx_de <= rgb_de;
end
//==============================================================================
// MIPI DSI
//==============================================================================
// signal 

reg		[25:0]	r_rst_cnt;

wire	[31:0]	w_axi_rdata;
wire			w_axi_awready;
wire			w_axi_wready;
wire			w_axi_arready;
wire			w_axi_rvalid;
wire			w_axi_bvalid;

wire	[6:0]	w_axi_awaddr;
wire			w_axi_awvalid;
wire	[31:0]	w_axi_wdata;
wire			w_axi_wvalid;
wire			w_axi_bready;
wire	[6:0]	w_axi_araddr;
wire			w_axi_arvalid;
wire			w_axi_rready;

wire			w_confdone;
assign w_confdone = 1'b1;

assign  LCD_POWER 			= i_arstn;
assign	LCD_RST_P	      = ~w_arstn;//~r_rst_cnt[23]; LCD复位先释放，然后再释放MIPI 的复位
assign	mipi_dp_clk_RST		= ~i_arstn;
assign	mipi_dp_data0_RST	= ~i_arstn;
assign	mipi_dp_data1_RST	= ~i_arstn;
assign	mipi_dp_data2_RST	= ~i_arstn;
assign	mipi_dp_data3_RST	= ~i_arstn;
////////////////////////////////////////////////////////////////
always@(posedge i_mipi_clk or  negedge w_arstn )
begin
  if ( !w_arstn ) begin
    r_rst_cnt	<= 'd0;
  end else 		
    r_rst_cnt	<= r_rst_cnt[25] ? r_rst_cnt :r_rst_cnt + 1'b1;
end

wire axi_rst_n = r_rst_cnt[25];

reg [26:0] dly_cnt = 'd0;

always @( posedge vid_clk_dvi2 or negedge w_arstn )
begin
  if( !w_arstn )
    dly_cnt <= 'd0;
  else if( w_confdone )
    dly_cnt <= dly_cnt[26] ? dly_cnt :(dly_cnt + 1'b1);
  else 
    dly_cnt <= 'd0;
end 

assign vid_rst_n = dly_cnt[26];




wire hs;
wire vs;
wire de;
wire [7:0] rgb_r;
wire [7:0] rgb_g;
wire [7:0] rgb_b;
  
  // color_bar_rgb #(
  // .HS_POLORY 		(1'b1		),
  // .VS_POLORY 		(1'b1		),
  // .H_FRONT_PORCH 	(HFP		),///2
  // .H_SYNC 		(HSP		),//
  // .H_VALID 		(MAX_HRES	),//
  // .H_BACK_PORCH 	(HBP		),//
  // .V_FRONT_PORCH 	(VFP		),
  // .V_SYNC 		(VSP		),
  // .V_VALID 		(MAX_VRES	),
  // .V_BACK_PORCH 	(VBP		),
  // .TEST_MODE 		(2'd2)
  // )u_color_bar_rgb1(
  // /*i*/.clk	(vid_clk_dvi2),//(vid_clk),
  // /*i*/.rst_n	(vid_rst_n),
  // /*o*/.hs	(hs),
  // /*o*/.vs	(vs),
  // /*o*/.de	(de),
  // // /*O*/.h_cnt (h_cnt),
  // // /*O*/.v_cnt (v_cnt),
  // /*o*/.rgb_r	(rgb_r),    //像素数据、红色分量
  // /*o*/.rgb_g	(rgb_g),    //像素数据、绿色分量
  // /*o*/.rgb_b (rgb_b)    //像素数据、蓝色分量
  
  // );

//=================================================================================
//hdmi tx ctrl 
//=================================================================================
wire                            video_hs;
wire                            video_vs;
wire                            video_de;
wire[7:0]                       video_r;
wire[7:0]                       video_g;
wire[7:0]                       video_b;

assign tmds_tx_data0_TX_OE = 1'b1;
assign tmds_tx_data1_TX_OE = 1'b1;
assign tmds_tx_data2_TX_OE = 1'b1;
assign tmds_tx_clk_TX_OE   = 1'b1;

assign tmds_tx_data0_TX_RST = 1'b0;
assign tmds_tx_data1_TX_RST = 1'b0;
assign tmds_tx_data2_TX_RST = 1'b0;
assign tmds_tx_clk_TX_RST   = 1'b0;

	  color_bar color_bar_m0(
	.clk(hdmi_tx_slow_clk),
	.rst(~vid_rst_n),
	.hs(video_hs),
	.vs(video_vs),
	.de(video_de),
	.rgb_r(video_r),
	.rgb_g(video_g),
	.rgb_b(video_b)
);

wire [9:0] tmds_data0;
wire [9:0] tmds_data1;
wire [9:0] tmds_data2;
wire [9:0] tmds_clk ;
wire [7:0] gamma_rdata ;
wire [7:0] gamma_gdata ;
wire [7:0] gamma_bdata ;
wire gamma_valid;
wire gamma_hs;
wire gamma_vs;
wire gamma_sel;

wire [7:0] con_rdata ;
wire [7:0] con_gdata ;
wire [7:0] con_bdata ;
wire con_de;
wire con_hs;
wire con_vs;
wire con_sel;

wire [7:0] BRIGHT_SIG    ;
wire CONTRAST_SIG_G;
wire CONTRAST_SIG_R;
wire [7:0] CONTRAST_G    ;
wire CONTRAST_SIG_B;
wire [7:0] BRIGHT        ;
wire [7:0] CONTRAST_R    ;


wire CONTRAST_B    ;


gamma_correction
#(
	.DATA_WIDTH		(8),
	.GAMMA_CURVE	("./rtl/gamma_conrrection/display_balanced.mem")
)
inst_gamma_correction
(
	.i_pclk		(hdmi_tx_slow_clk),
	.i_rstn		(vid_rst_n),
	
	.i_red		(hdmi_tx_rdata),//(con_rdata  ),//
	.i_green	(hdmi_tx_gdata),//(con_gdata  ),//
	.i_blue		(hdmi_tx_bdata),//(con_bdata  ),//
  .i_valid	(hdmi_tx_de   ),//(con_de     ),//
  .i_hs     (hdmi_tx_hs   ),//(con_hs     ),//
  .i_vs     (hdmi_tx_vs   ),//(con_vs     ),//
	.o_blue		(gamma_bdata		),
  .o_green	(gamma_gdata	  ),
	.o_red		(gamma_rdata		),
	.o_valid	(gamma_valid	  ),
  .o_hs     (gamma_hs       ),
  .o_vs     (gamma_vs       )
);

wire [15:0] apb_paddr;
wire [31:0] apb_pwdata,apb_prdata;
wire apb_psel,apb_penable,apb_pwrite,apb_pready,apb_pslverror;
wire soc_reset,dma_reset,style_irq;
wire [31:0] cnn_araddr,cnn_awaddr,cnn_wdata,cnn_rdata;
wire [7:0] cnn_arlen,cnn_awlen;
wire [3:0] cnn_wstrb;
wire [1:0] cnn_rresp,cnn_bresp;
wire cnn_arvalid,cnn_arready,cnn_rvalid,cnn_rready,cnn_rlast;
wire cnn_awvalid,cnn_awready,cnn_wvalid,cnn_wready,cnn_wlast,cnn_bvalid,cnn_bready;

wire [7:0] cam_axi_awid;
wire [31:0] cam_axi_awaddr;
wire [7:0] cam_axi_awlen;
wire [2:0] cam_axi_awsize;
wire [1:0] cam_axi_awburst;
wire cam_axi_awlock;
wire [3:0] cam_axi_awcache;
wire [2:0] cam_axi_awprot;
wire cam_axi_awvalid;
wire cam_axi_awready;
wire [127:0] cam_axi_wdata;
wire [15:0] cam_axi_wstrb;
wire cam_axi_wlast;
wire cam_axi_wvalid;
wire cam_axi_wready;
wire [7:0] cam_axi_bid;
wire [1:0] cam_axi_bresp;
wire cam_axi_bvalid;
wire cam_axi_bready;
wire [7:0] cam_axi_arid;
wire [31:0] cam_axi_araddr;
wire [7:0] cam_axi_arlen;
wire [2:0] cam_axi_arsize;
wire [1:0] cam_axi_arburst;
wire cam_axi_arlock;
wire [3:0] cam_axi_arcache;
wire [2:0] cam_axi_arprot;
wire cam_axi_arvalid;
wire cam_axi_arready;
wire [7:0] cam_axi_rid;
wire [127:0] cam_axi_rdata;
wire [1:0] cam_axi_rresp;
wire cam_axi_rlast;
wire cam_axi_rvalid;
wire cam_axi_rready;
wire [7:0] soc_axi_awid;
wire [31:0] soc_axi_awaddr;
wire [7:0] soc_axi_awlen;
wire [2:0] soc_axi_awsize;
wire [1:0] soc_axi_awburst;
wire soc_axi_awlock;
wire [3:0] soc_axi_awcache;
wire [2:0] soc_axi_awprot;
wire soc_axi_awvalid;
wire soc_axi_awready;
wire [127:0] soc_axi_wdata;
wire [15:0] soc_axi_wstrb;
wire soc_axi_wlast;
wire soc_axi_wvalid;
wire soc_axi_wready;
wire [7:0] soc_axi_bid;
wire [1:0] soc_axi_bresp;
wire soc_axi_bvalid;
wire soc_axi_bready;
wire [7:0] soc_axi_arid;
wire [31:0] soc_axi_araddr;
wire [7:0] soc_axi_arlen;
wire [2:0] soc_axi_arsize;
wire [1:0] soc_axi_arburst;
wire soc_axi_arlock;
wire [3:0] soc_axi_arcache;
wire [2:0] soc_axi_arprot;
wire soc_axi_arvalid;
wire soc_axi_arready;
wire [7:0] soc_axi_rid;
wire [127:0] soc_axi_rdata;
wire [1:0] soc_axi_rresp;
wire soc_axi_rlast;
wire soc_axi_rvalid;
wire soc_axi_rready;
wire [7:0] vid_axi_awid;
wire [31:0] vid_axi_awaddr;
wire [7:0] vid_axi_awlen;
wire [2:0] vid_axi_awsize;
wire [1:0] vid_axi_awburst;
wire vid_axi_awlock;
wire [3:0] vid_axi_awcache;
wire [2:0] vid_axi_awprot;
wire vid_axi_awvalid;
wire vid_axi_awready;
wire [127:0] vid_axi_wdata;
wire [15:0] vid_axi_wstrb;
wire vid_axi_wlast;
wire vid_axi_wvalid;
wire vid_axi_wready;
wire [7:0] vid_axi_bid;
wire [1:0] vid_axi_bresp;
wire vid_axi_bvalid;
wire vid_axi_bready;
wire [7:0] vid_axi_arid;
wire [31:0] vid_axi_araddr;
wire [7:0] vid_axi_arlen;
wire [2:0] vid_axi_arsize;
wire [1:0] vid_axi_arburst;
wire vid_axi_arlock;
wire [3:0] vid_axi_arcache;
wire [2:0] vid_axi_arprot;
wire vid_axi_arvalid;
wire vid_axi_arready;
wire [7:0] vid_axi_rid;
wire [127:0] vid_axi_rdata;
wire [1:0] vid_axi_rresp;
wire vid_axi_rlast;
wire vid_axi_rvalid;
wire vid_axi_rready;

wire system_ready=axi_rst_n && cal_done && !soc_reset && !dma_reset;
wire [31:0] style_prdata,video_prdata,cnn_frames;
wire style_pready,style_pslverror,video_pready,video_pslverror;
wire [31:0] capture_frames,display_frames,display_underflows,display_errors,front_job,measured_fps,mipi_markers;
wire pair_de,pair_hs,pair_vs;wire [23:0] pair_rgb;

// Independent native-width transport validation master; no inference completion.
wire [31:0] transport_prdata;wire transport_pready,transport_pslverror;
wire select_transport=apb_paddr[15:12]==2;
wire [0:0] p2_axi_awvalid;
wire [0:0] p2_axi_awready;
wire [31:0] p2_axi_awaddr;
wire [7:0] p2_axi_awlen;
wire [7:0] p2_axi_awid;
wire [2:0] p2_axi_awsize;
wire [1:0] p2_axi_awburst;
wire [0:0] p2_axi_awlock;
wire [0:0] p2_axi_wvalid;
wire [0:0] p2_axi_wready;
wire [127:0] p2_axi_wdata;
wire [15:0] p2_axi_wstrb;
wire [0:0] p2_axi_wlast;
wire [0:0] p2_axi_bvalid;
wire [0:0] p2_axi_bready;
wire [7:0] p2_axi_bid;
wire [1:0] p2_axi_bresp;
wire [0:0] p2_axi_arvalid;
wire [0:0] p2_axi_arready;
wire [31:0] p2_axi_araddr;
wire [7:0] p2_axi_arlen;
wire [7:0] p2_axi_arid;
wire [2:0] p2_axi_arsize;
wire [1:0] p2_axi_arburst;
wire [0:0] p2_axi_arlock;
wire [0:0] p2_axi_rvalid;
wire [0:0] p2_axi_rready;
wire [127:0] p2_axi_rdata;
wire [7:0] p2_axi_rid;
wire [1:0] p2_axi_rresp;
wire [0:0] p2_axi_rlast;
assign p2_axi_arid=8'd3;
assign p2_axi_arsize=3'd4;
assign p2_axi_arburst=2'd1;
assign p2_axi_arlock=1'b0;
assign p2_axi_awid=8'd3;
assign p2_axi_awsize=3'd4;
assign p2_axi_awburst=2'd1;
assign p2_axi_awlock=1'b0;
// Tensor DMA now lives in the layer executor; retire the old copy-test master.
assign transport_prdata=0;assign transport_pready=1;assign transport_pslverror=apb_psel&&apb_penable&&select_transport;
assign p2_axi_awvalid='0;
assign p2_axi_awaddr='0;
assign p2_axi_awlen='0;
assign p2_axi_wvalid='0;
assign p2_axi_wdata='0;
assign p2_axi_wstrb='0;
assign p2_axi_wlast='0;
assign p2_axi_bready='0;
assign p2_axi_arvalid='0;
assign p2_axi_araddr='0;
assign p2_axi_arlen='0;
assign p2_axi_rready='0;

wire [31:0] coeff_prdata;wire coeff_pready,coeff_pslverror;
wire select_coeff=apb_paddr[15:12]==3;
// Standalone coefficient debug core removed; network has its own coefficient engine.
assign coeff_prdata=0;assign coeff_pready=1;assign coeff_pslverror=apb_psel&&select_coeff&&apb_penable;
wire [31:0] sensor_prdata; wire sensor_error;
wire select_sensor=apb_paddr[15:12]==4;
wire select_style=apb_paddr[15:12]==0;
wire select_video=apb_paddr[15:12]==1;
assign apb_prdata=select_style?style_prdata:select_video?video_prdata:select_transport?transport_prdata:select_coeff?coeff_prdata:select_sensor?sensor_prdata:32'b0;
assign apb_pready=select_style?style_pready:select_video?video_pready:select_transport?transport_pready:select_coeff?coeff_pready:1'b1;
assign apb_pslverror=select_style?style_pslverror:select_video?video_pslverror:select_transport?transport_pslverror:select_coeff?coeff_pslverror:select_sensor?sensor_error:(apb_psel && apb_penable);
assign r_gain=16'd1024;assign g_gain=16'd530;assign b_gain=16'd1024;assign gamma_sel=1'b1;

dvi_encoder dvi_encoder_m0
(
	.pixelclk      		(vid_clk_dvi2          ),// system clock
	.rst_p         		(~vid_rst_n      ),// reset
	.i_bdata      		(pair_rgb[7:0]),//(hdmi_tx_rdata ),//(video_b            ),//(bdata_in	),   //
	.i_gdata     		  (pair_rgb[15:8]),//(hdmi_tx_gdata ),//(video_g            ),//(gdata_in	),   //   
	.i_rdata       		(pair_rgb[23:16]),//(hdmi_tx_bdata ),//(video_r            ),//(rdata_in	),   //   
  .i_de            	(pair_de),//(hdmi_tx_de    ),//(video_de           ),//(rx_de		  ),   //
	.i_hs         		(~pair_hs),//(video_hs           ),//(rx_hsync	),   //   
	.i_vs         		(~pair_vs),//(video_vs           ),//(rx_vsync	),   //  
	
  .video_format     (2'b00), //// 00 = RGB, 01 = YCbCr 4:2:2, 10 = YCbCr 4:4:4
  .video_VIC        (7'd4),
	.audio_L			    (24'd0),
  .audio_R			    (24'd0),
  .audio_valid		  (1'b0),
  .audio_N                (6144),     //(20'h01880),//     
  .audio_CTS              (74250),      //(20'h28488),//      
  .audio_sample_frequency (4'd2),    //(3'b000),// 
  .audio_word_length      (4'b1011),//(4'b1011),//

	.tmds_data0    		(tmds_data0),
  .tmds_data1    		(tmds_data1),
  .tmds_data2    		(tmds_data2),
  .tmds_clk      	  (tmds_clk  )
);
assign tmds_tx_clk_TX_DATA   = ~tmds_clk;
assign tmds_tx_data0_TX_DATA = ~tmds_data0;
assign tmds_tx_data1_TX_DATA = ~tmds_data1;
assign tmds_tx_data2_TX_DATA = ~tmds_data2;

soc u_sapphire_soc(
    .io_asyncReset                      (!axi_rst_n || !cal_done),
    .io_systemClk                       (core_clk                           ),

    
    .system_uart_0_io_txd               (),
    .system_uart_0_io_rxd               (1'b1),
    .io_memoryClk                       (core_clk                           ),
    .io_memoryReset                     (                                   ),
    .io_systemReset                     (soc_reset),
    
    .io_ddrA_aw_payload_prot            (                                  ),
    .io_ddrA_aw_payload_qos             (                                  ),
    .io_ddrA_aw_payload_cache           (                                  ),
    .io_ddrA_aw_payload_lock            (soc_axi_awlock                     ),
    .io_ddrA_aw_payload_burst           (soc_axi_awburst                    ),
    .io_ddrA_aw_payload_size            (soc_axi_awsize                     ),
    .io_ddrA_aw_payload_len             (soc_axi_awlen                      ),
    .io_ddrA_aw_payload_region          (                                 ),
    .io_ddrA_aw_payload_id              (soc_axi_awid                       ),
    .io_ddrA_aw_payload_addr            (soc_axi_awaddr                     ),
    .io_ddrA_aw_ready                   (soc_axi_awready                    ),
    .io_ddrA_aw_valid                   (soc_axi_awvalid                    ),
    .io_ddrA_w_payload_last             (soc_axi_wlast                      ),
    .io_ddrA_w_ready                    (soc_axi_wready                     ),
    .io_ddrA_w_valid                    (soc_axi_wvalid                     ),  
    .io_ddrA_w_payload_strb             (soc_axi_wstrb                      ),
    .io_ddrA_w_payload_data             (soc_axi_wdata                      ),
    .io_ddrA_b_payload_resp             (soc_axi_bresp),
    .io_ddrA_b_payload_id               (soc_axi_bid                        ),
    .io_ddrA_b_ready                    (soc_axi_bready                     ),
    .io_ddrA_b_valid                    (soc_axi_bvalid                     ),
    .io_ddrA_ar_payload_prot            (                                 ),
    .io_ddrA_ar_payload_qos             (                                 ),
    .io_ddrA_ar_payload_cache           (                                 ),
    .io_ddrA_ar_payload_region          (                                 ),
    .io_ddrA_ar_payload_lock            (soc_axi_arlock                     ),
    .io_ddrA_ar_payload_burst           (soc_axi_arburst                    ),
    .io_ddrA_ar_payload_size            (soc_axi_arsize                     ),
    .io_ddrA_ar_payload_len             (soc_axi_arlen                      ),
    .io_ddrA_ar_payload_id              (soc_axi_arid                       ),
    .io_ddrA_ar_payload_addr            (soc_axi_araddr                     ),
    .io_ddrA_ar_ready                   (soc_axi_arready                    ),
    .io_ddrA_ar_valid                   (soc_axi_arvalid                    ),
    .io_ddrA_r_payload_last             (soc_axi_rlast                      ),
    .io_ddrA_r_payload_resp             (soc_axi_rresp                      ),
    .io_ddrA_r_payload_id               (soc_axi_rid                        ),
    .io_ddrA_r_payload_data             (soc_axi_rdata                      ),
    .io_ddrA_r_ready                    (soc_axi_rready                     ),
    .io_ddrA_r_valid                    (soc_axi_rvalid                     ),
     
    .system_spi_0_io_sclk_write(system_spi_0_io_sclk_write),
    .system_spi_0_io_data_0_writeEnable(system_spi_0_io_data_0_OE),
    .system_spi_0_io_data_0_read(system_spi_0_io_data_0_IN),
    .system_spi_0_io_data_0_write(system_spi_0_io_data_0_OUT),
    .system_spi_0_io_data_1_writeEnable(system_spi_0_io_data_1_OE),
    .system_spi_0_io_data_1_read(system_spi_0_io_data_1_IN),
    .system_spi_0_io_data_1_write(system_spi_0_io_data_1_OUT),
    .system_spi_0_io_data_2_writeEnable (                                   ),
    .system_spi_0_io_data_2_read        (1'b0),
    .system_spi_0_io_data_2_write       (                                   ),
    .system_spi_0_io_data_3_writeEnable (                                   ),
    .system_spi_0_io_data_3_read        (1'b0),
    .system_spi_0_io_data_3_write       (                                   ),
    .system_spi_0_io_ss(system_spi_0_io_ss),
    
    .io_apbSlave_0_PADDR                (apb_paddr                          ),
    .io_apbSlave_0_PSEL                 (apb_psel                           ),
    .io_apbSlave_0_PENABLE              (apb_penable                        ),
    .io_apbSlave_0_PREADY               (apb_pready                         ),
    .io_apbSlave_0_PWRITE               (apb_pwrite                         ),
    .io_apbSlave_0_PWDATA               (apb_pwdata                         ),
    .io_apbSlave_0_PRDATA               (apb_prdata                         ),
    .io_apbSlave_0_PSLVERROR            (apb_pslverror                      ),

    .system_gpio_0_io_write             (),
    .system_gpio_0_io_read              ('d0),
    .system_gpio_0_io_writeEnable       (),


    
    .jtagCtrl_tck                       (jtag_inst1_TCK                     ),
    .jtagCtrl_tdi                       (jtag_inst1_TDI                     ),
    .jtagCtrl_tdo                       (jtag_inst1_TDO                     ),
    .jtagCtrl_enable                    (jtag_inst1_SEL                     ),
    .jtagCtrl_capture                   (jtag_inst1_CAPTURE                 ),
    .jtagCtrl_shift                     (jtag_inst1_SHIFT                   ),
    .jtagCtrl_update                    (jtag_inst1_UPDATE                  ),
    .jtagCtrl_reset                     (jtag_inst1_RESET                   ),
    .io_ddrMasters_0_clk(core_clk),
    .io_ddrMasters_0_reset(dma_reset),
    .userInterruptA(style_irq),
    .io_ddrMasters_0_ar_payload_addr(cnn_araddr),
    .io_ddrMasters_0_ar_payload_len(cnn_arlen),
    .io_ddrMasters_0_ar_valid(cnn_arvalid),
    .io_ddrMasters_0_ar_ready(cnn_arready),
    .io_ddrMasters_0_ar_payload_size(3'd2),
    .io_ddrMasters_0_ar_payload_burst(2'b01),
    .io_ddrMasters_0_ar_payload_id(4'b0),
    .io_ddrMasters_0_ar_payload_lock(1'b0),
    .io_ddrMasters_0_ar_payload_cache(4'b0),
    .io_ddrMasters_0_ar_payload_prot(3'b0),
    .io_ddrMasters_0_ar_payload_qos(4'b0),
    .io_ddrMasters_0_ar_payload_region(4'b0),
    .io_ddrMasters_0_aw_payload_addr(cnn_awaddr),
    .io_ddrMasters_0_aw_payload_len(cnn_awlen),
    .io_ddrMasters_0_aw_valid(cnn_awvalid),
    .io_ddrMasters_0_aw_ready(cnn_awready),
    .io_ddrMasters_0_aw_payload_size(3'd2),
    .io_ddrMasters_0_aw_payload_burst(2'b01),
    .io_ddrMasters_0_aw_payload_id(4'b0),
    .io_ddrMasters_0_aw_payload_lock(1'b0),
    .io_ddrMasters_0_aw_payload_cache(4'b0),
    .io_ddrMasters_0_aw_payload_prot(3'b0),
    .io_ddrMasters_0_aw_payload_qos(4'b0),
    .io_ddrMasters_0_aw_payload_region(4'b0),
    .io_ddrMasters_0_r_payload_data(cnn_rdata),
    .io_ddrMasters_0_r_payload_resp(cnn_rresp),
    .io_ddrMasters_0_r_payload_last(cnn_rlast),
    .io_ddrMasters_0_r_valid(cnn_rvalid),
    .io_ddrMasters_0_r_ready(cnn_rready),
    .io_ddrMasters_0_w_payload_data(cnn_wdata),
    .io_ddrMasters_0_w_payload_strb(cnn_wstrb),
    .io_ddrMasters_0_w_payload_last(cnn_wlast),
    .io_ddrMasters_0_w_valid(cnn_wvalid),
    .io_ddrMasters_0_w_ready(cnn_wready),
    .io_ddrMasters_0_b_payload_resp(cnn_bresp),
    .io_ddrMasters_0_b_valid(cnn_bvalid),
    .io_ddrMasters_0_b_ready(cnn_bready),
    .axiA_awready('d0),
    .axiA_arready('d0),
    .axiAInterrupt('d0),
    .axiA_rlast('d0),
    .axiA_wready('d0),
    .axiA_bvalid('d0),
    .axiA_bid('d0),
    .axiA_bresp('d0),
    .axiA_rvalid('d0),
    .axiA_rdata('d0),
    .axiA_rid('d0),
    .axiA_rresp('d0),
    .system_i2c_0_io_scl_read(1'b1),
    .system_i2c_0_io_sda_read(1'b1)

);
// No neural engine exists in the capture Demo. Former AXI port verifies DDR.
assign cnn_frames=0;
assign cam_axi_awaddr=0;assign cam_axi_awlen=0;assign cam_axi_awvalid=0;
assign cam_axi_wdata=0;assign cam_axi_wstrb=0;assign cam_axi_wvalid=0;assign cam_axi_wlast=0;assign cam_axi_bready=1;
capture_verifier verify(.clk(core_clk),.rst_n(system_ready),
 .paddr(apb_paddr[11:0]),.psel(apb_psel&&select_style),.penable(apb_penable),.pwrite(apb_pwrite),
 .pwdata(apb_pwdata),.prdata(style_prdata),.pready(style_pready),.pslverror(style_pslverror),
 .araddr(cam_axi_araddr),.arlen(cam_axi_arlen),.arvalid(cam_axi_arvalid),.arready(cam_axi_arready),
 .rdata(cam_axi_rdata),.rresp(cam_axi_rresp),.rlast(cam_axi_rlast),.rvalid(cam_axi_rvalid),.rready(cam_axi_rready));

// Arithmetic capacity probe only; never reports completed inference frames.
assign style_irq=0;
assign cnn_araddr=0;assign cnn_arlen=0;assign cnn_arvalid=0;assign cnn_rready=1;
assign cnn_awaddr=0;assign cnn_awlen=0;assign cnn_awvalid=0;
assign cnn_wdata=0;assign cnn_wstrb=0;assign cnn_wlast=0;assign cnn_wvalid=0;assign cnn_bready=1;
    


capture_pipeline u_video(
 .clk(core_clk),.pclk(vid_clk_dvi2),.capture_pclk(hdmi_tx_slow_clk),.mipi_clk(i_mipi_rx_pclk),.rst_n(system_ready && vid_rst_n),.mipi_vs(w_mipi_rx_vs),
 .paddr(apb_paddr[11:0]),.psel(apb_psel && select_video),.penable(apb_penable),.pwrite(apb_pwrite),
 .pwdata(apb_pwdata),.prdata(video_prdata),.pready(video_pready),.pslverror(video_pslverror),.cnn_frames(cnn_frames),.raw_drops(raw_dropped_frames),.mipi_de(w_mipi_rx_de&&w_mipi_rx_hs),
 .i_de(gamma_valid),.i_hs(gamma_hs),.i_vs(gamma_vs),.i_rgb({gamma_bdata,gamma_gdata,gamma_rdata}),
 .o_de(pair_de),.o_hs(pair_hs),.o_vs(pair_vs),.o_rgb(pair_rgb),
 .awaddr(vid_axi_awaddr),.awlen(vid_axi_awlen),.awvalid(vid_axi_awvalid),.awready(vid_axi_awready),
 .wdata(vid_axi_wdata),.wstrb(vid_axi_wstrb),.wvalid(vid_axi_wvalid),.wlast(vid_axi_wlast),.wready(vid_axi_wready),
 .bresp(vid_axi_bresp),.bvalid(vid_axi_bvalid),.bready(vid_axi_bready),
 .araddr(vid_axi_araddr),.arlen(vid_axi_arlen),.arvalid(vid_axi_arvalid),.arready(vid_axi_arready),
 .rdata(vid_axi_rdata),.rresp(vid_axi_rresp),.rvalid(vid_axi_rvalid),.rlast(vid_axi_rlast),.rready(vid_axi_rready),
 .capture_frames(capture_frames),.read_frames(display_frames),.underflows(display_underflows),.read_errors(display_errors),
 .front_job(front_job),.measured_fps(measured_fps),.mipi_markers(mipi_markers));
assign vid_axi_awid=8'b0;
assign vid_axi_awsize=3'd4;
assign vid_axi_awburst=2'b01;
assign vid_axi_awlock=1'b0;
assign s_axi_awcache=0;assign s_axi_awprot=0;
assign vid_axi_arid=8'b0;
assign vid_axi_arsize=3'd4;
assign vid_axi_arburst=2'b01;
assign vid_axi_arlock=1'b0;
assign s_axi_arcache=0;assign s_axi_arprot=0;
axi_arbiter128 #(.N(4)) u_arbiter(
.clk(core_clk),
.rst_n(axi_rst_n && cal_done),
.s_awid({p2_axi_awid,vid_axi_awid,soc_axi_awid,cam_axi_awid}),
.m_awid(s_axi_awid),
.s_awaddr({p2_axi_awaddr,vid_axi_awaddr,soc_axi_awaddr,cam_axi_awaddr}),
.m_awaddr(s_axi_awaddr),
.s_awlen({p2_axi_awlen,vid_axi_awlen,soc_axi_awlen,cam_axi_awlen}),
.m_awlen(s_axi_awlen),
.s_awsize({p2_axi_awsize,vid_axi_awsize,soc_axi_awsize,cam_axi_awsize}),
.m_awsize(s_axi_awsize),
.s_awburst({p2_axi_awburst,vid_axi_awburst,soc_axi_awburst,cam_axi_awburst}),
.m_awburst(s_axi_awburst),
.s_awlock({p2_axi_awlock,vid_axi_awlock,soc_axi_awlock,cam_axi_awlock}),
.m_awlock(s_axi_awlock),
.s_awvalid({p2_axi_awvalid,vid_axi_awvalid,soc_axi_awvalid,cam_axi_awvalid}),
.m_awvalid(s_axi_awvalid),
.s_awready({p2_axi_awready,vid_axi_awready,soc_axi_awready,cam_axi_awready}),
.m_awready(s_axi_awready),
.s_wdata({p2_axi_wdata,vid_axi_wdata,soc_axi_wdata,cam_axi_wdata}),
.m_wdata(s_axi_wdata),
.s_wstrb({p2_axi_wstrb,vid_axi_wstrb,soc_axi_wstrb,cam_axi_wstrb}),
.m_wstrb(s_axi_wstrb),
.s_wlast({p2_axi_wlast,vid_axi_wlast,soc_axi_wlast,cam_axi_wlast}),
.m_wlast(s_axi_wlast),
.s_wvalid({p2_axi_wvalid,vid_axi_wvalid,soc_axi_wvalid,cam_axi_wvalid}),
.m_wvalid(s_axi_wvalid),
.s_wready({p2_axi_wready,vid_axi_wready,soc_axi_wready,cam_axi_wready}),
.m_wready(s_axi_wready),
.s_bid({p2_axi_bid,vid_axi_bid,soc_axi_bid,cam_axi_bid}),
.m_bid(s_axi_bid),
.s_bresp({p2_axi_bresp,vid_axi_bresp,soc_axi_bresp,cam_axi_bresp}),
.m_bresp(s_axi_bresp),
.s_bvalid({p2_axi_bvalid,vid_axi_bvalid,soc_axi_bvalid,cam_axi_bvalid}),
.m_bvalid(s_axi_bvalid),
.s_bready({p2_axi_bready,vid_axi_bready,soc_axi_bready,cam_axi_bready}),
.m_bready(s_axi_bready),
.s_arid({p2_axi_arid,vid_axi_arid,soc_axi_arid,cam_axi_arid}),
.m_arid(s_axi_arid),
.s_araddr({p2_axi_araddr,vid_axi_araddr,soc_axi_araddr,cam_axi_araddr}),
.m_araddr(s_axi_araddr),
.s_arlen({p2_axi_arlen,vid_axi_arlen,soc_axi_arlen,cam_axi_arlen}),
.m_arlen(s_axi_arlen),
.s_arsize({p2_axi_arsize,vid_axi_arsize,soc_axi_arsize,cam_axi_arsize}),
.m_arsize(s_axi_arsize),
.s_arburst({p2_axi_arburst,vid_axi_arburst,soc_axi_arburst,cam_axi_arburst}),
.m_arburst(s_axi_arburst),
.s_arlock({p2_axi_arlock,vid_axi_arlock,soc_axi_arlock,cam_axi_arlock}),
.m_arlock(s_axi_arlock),
.s_arvalid({p2_axi_arvalid,vid_axi_arvalid,soc_axi_arvalid,cam_axi_arvalid}),
.m_arvalid(s_axi_arvalid),
.s_arready({p2_axi_arready,vid_axi_arready,soc_axi_arready,cam_axi_arready}),
.m_arready(s_axi_arready),
.s_rid({p2_axi_rid,vid_axi_rid,soc_axi_rid,cam_axi_rid}),
.m_rid(s_axi_rid),
.s_rdata({p2_axi_rdata,vid_axi_rdata,soc_axi_rdata,cam_axi_rdata}),
.m_rdata(s_axi_rdata),
.s_rresp({p2_axi_rresp,vid_axi_rresp,soc_axi_rresp,cam_axi_rresp}),
.m_rresp(s_axi_rresp),
.s_rlast({p2_axi_rlast,vid_axi_rlast,soc_axi_rlast,cam_axi_rlast}),
.m_rlast(s_axi_rlast),
.s_rvalid({p2_axi_rvalid,vid_axi_rvalid,soc_axi_rvalid,cam_axi_rvalid}),
.m_rvalid(s_axi_rvalid),
.s_rready({p2_axi_rready,vid_axi_rready,soc_axi_rready,cam_axi_rready}),
.m_rready(s_axi_rready)
);


// All sensor reset/I2C transactions are initiated by RISC-V C.
capture_i2c_gpio sensor_bus(.clk(core_clk),.rst_n(system_ready),
 .psel(apb_psel&&select_sensor),.penable(apb_penable),.pwrite(apb_pwrite),
 .paddr(apb_paddr[11:0]),.pwdata(apb_pwdata),.prdata(sensor_prdata),.error(sensor_error),
 .scl_in(io_cam_scl_IN),.sda_in(io_cam_sda_IN),
 .scl_oe(io_cam_scl_OE),.sda_oe(io_cam_sda_OE),.sensor_reset(o_cam_rst_p));
assign io_cam_scl_OUT=0;assign io_cam_sda_OUT=0;
endmodule
