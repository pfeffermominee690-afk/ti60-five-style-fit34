// Deterministic geometric renderer AFTER CNN, BEFORE output-frame DMA.
// RGB word order: R[7:0], G[15:8], B[23:16] (same as cnn_stream_q8).
// One strip is collected, summarized, then emitted in raster order. Both
// interfaces use ready/valid. Never connect directly to an unstalled HDMI clock.
// start accepted only in IDLE; use the same launch and error recovery as CNN.
module lowpoly_stream #(
 parameter WIDTH=640, HEIGHT=480, BLOCK=16
)(
 input wire clk,rst_n,start,
 output wire start_ready,
 input wire s_valid,output wire s_ready,input wire [23:0] s_rgb,
 output wire m_valid,input wire m_ready,output wire [23:0] m_rgb,
 output wire m_last,output reg done,
 output wire busy
);
 localparam CELLS=WIDTH/BLOCK, STRIPS=HEIGHT/BLOCK;
 localparam N0=BLOCK*(BLOCK+1)/2, N1=BLOCK*(BLOCK-1)/2;
 localparam SW=$clog2(255*N0+1), SUM_BITS=3*SW;
 // Ceiling reciprocals are EXACT over the bounded sums, checked exhaustively
 // by check_lowpoly.py. Restrict BLOCK to 8 or 16 to keep that proof applicable.
 localparam [23:0] RECIP0=((64'd1<<24)+N0-1)/N0;
 localparam [23:0] RECIP1=((64'd1<<24)+N1-1)/N1;
 localparam IDLE=0,CLEAR=1,COLLECT=2,UPDATE=3,READ0=4,
            MEAN0=5,MEAN1=6,CHOOSE=7,PAL_READ=8,EMIT=9;
 reg [3:0] state;
 localparam XW=$clog2(WIDTH+1), YW=$clog2(BLOCK+1);
 localparam TW=$clog2(STRIPS+1), CW=$clog2(CELLS+1), AW=$clog2(2*CELLS+1);
 reg [XW-1:0] x;
 reg [YW-1:0] ly;
 reg [TW-1:0] strip;
 reg [AW-1:0] clear_addr,pending_a,pending_b;
 reg [CW-1:0] cell_index;
 reg [23:0] pending_rgb;
 reg [SUM_BITS-1:0] sum_a[0:2*CELLS-1],sum_b[0:2*CELLS-1];
 reg [SUM_BITS-1:0] read_a,read_b;
 reg [23:0] a0,a1,b0,b1;
 reg [48:0] palette[0:CELLS-1],pal;
 wire [YW-1:0] local_x=x%BLOCK;
 wire [CW-1:0] input_cell=x/BLOCK;
 wire [AW-1:0] addr_a=2*input_cell+(local_x>=ly?0:1);
 wire [AW-1:0] addr_b=2*input_cell+(local_x+ly<BLOCK?0:1);
 wire diagonal=(distance(b0,b1)>distance(a0,a1));
 wire half=pal[48] ? (local_x+ly>=BLOCK) : (local_x<ly);
 assign start_ready=(state==IDLE);
 assign busy=(state!=IDLE);
 assign s_ready=(state==COLLECT);
 assign m_valid=(state==EMIT);
 assign m_rgb=half?pal[47:24]:pal[23:0];
 assign m_last=m_valid && strip==STRIPS-1 && ly==BLOCK-1 && x==WIDTH-1;

 function automatic [SUM_BITS-1:0] add_pixel(input [SUM_BITS-1:0] total,input [23:0] rgb);
  integer c;
  begin
   for(c=0;c<3;c=c+1)add_pixel[c*SW+:SW]=total[c*SW+:SW]+rgb[c*8+:8];
  end
 endfunction
 function automatic [7:0] mean_channel0(input [SW-1:0] value);
  reg [SW:0] rounded;reg [SW+24:0] product;
  begin rounded={1'b0,value}+N0/2;product=rounded*RECIP0;mean_channel0=product>>24;end
 endfunction
 function automatic [7:0] mean_channel1(input [SW-1:0] value);
  reg [SW:0] rounded;reg [SW+24:0] product;
  begin rounded={1'b0,value}+N1/2;product=rounded*RECIP1;mean_channel1=product>>24;end
 endfunction
 function automatic [23:0] mean0(input [SUM_BITS-1:0] value);
  integer c;begin for(c=0;c<3;c=c+1)mean0[c*8+:8]=mean_channel0(value[c*SW+:SW]);end
 endfunction
 function automatic [23:0] mean1(input [SUM_BITS-1:0] value);
  integer c;begin for(c=0;c<3;c=c+1)mean1[c*8+:8]=mean_channel1(value[c*SW+:SW]);end
 endfunction
 function automatic [9:0] distance(input [23:0] a,input [23:0] b);
  integer c;reg [7:0] ac,bc;reg [9:0] d;
  begin
   d=0;for(c=0;c<3;c=c+1)begin
    ac=a[c*8+:8];bc=b[c*8+:8];d=d+(ac>bc?ac-bc:bc-ac);
   end
   distance=d;
  end
 endfunction
 function automatic [23:0] quantize(input [23:0] rgb);
  integer c;reg [8:0] rounded;
  begin
   for(c=0;c<3;c=c+1)begin
    rounded={1'b0,rgb[c*8+:8]}+9'd16;
    quantize[c*8+:8]=rounded[8]?8'd255:{rounded[7:5],5'b00000};
   end
  end
 endfunction

 // Multiplex addresses BEFORE the synchronous RAM ports. Multiple array-read
 // expressions in separate branches were inferred as asynchronous multiports.
 // Neither the RAM arrays nor their output registers have a reset.
 wire sum_we=(state==CLEAR || state==UPDATE);
 wire sum_re=(state==COLLECT && s_valid) || state==READ0 || state==MEAN0;
 wire [AW-1:0] wa=(state==CLEAR)?clear_addr:pending_a;
 wire [AW-1:0] wb=(state==CLEAR)?clear_addr:pending_b;
 wire [AW-1:0] cell_read=2*cell_index+(state==MEAN0);
 wire [AW-1:0] ra=(state==COLLECT)?addr_a:cell_read;
 wire [AW-1:0] rb=(state==COLLECT)?addr_b:cell_read;
 wire [SUM_BITS-1:0] da=(state==CLEAR)?{SUM_BITS{1'b0}}:add_pixel(read_a,pending_rgb);
 wire [SUM_BITS-1:0] db=(state==CLEAR)?{SUM_BITS{1'b0}}:add_pixel(read_b,pending_rgb);
 always @(posedge clk)begin
  if(sum_we)sum_a[wa]<=da;
  if(sum_re)read_a<=sum_a[ra];
 end
 always @(posedge clk)begin
  if(sum_we)sum_b[wb]<=db;
  if(sum_re)read_b<=sum_b[rb];
 end
 always @(posedge clk)begin
  if(state==CHOOSE)palette[cell_index]<={diagonal,quantize(diagonal?b1:a1),quantize(diagonal?b0:a0)};
  if(state==PAL_READ)pal<=palette[input_cell];
 end

 always @(posedge clk)begin
  if(!rst_n)begin
   state<=IDLE;x<=0;ly<=0;strip<=0;clear_addr<=0;cell_index<=0;
   pending_a<=0;pending_b<=0;pending_rgb<=0;
   a0<=0;a1<=0;b0<=0;b1<=0;done<=0;
  end else begin
   done<=0;
   case(state)
    IDLE:if(start)begin state<=CLEAR;clear_addr<=0;strip<=0;x<=0;ly<=0;end
    CLEAR:begin
     if(clear_addr==2*CELLS-1)begin state<=COLLECT;x<=0;ly<=0;end
     else clear_addr<=clear_addr+1;
    end
    COLLECT:if(s_valid)begin
     pending_a<=addr_a;pending_b<=addr_b;pending_rgb<=s_rgb;state<=UPDATE;
    end
    UPDATE:begin
     state<=COLLECT;
     if(x==WIDTH-1)begin
      x<=0;
      if(ly==BLOCK-1)begin state<=READ0;cell_index<=0;end
      else ly<=ly+1;
     end else x<=x+1;
    end
    READ0:state<=MEAN0;
    MEAN0:begin a0<=mean0(read_a);b0<=mean0(read_b);state<=MEAN1;end
    MEAN1:begin a1<=mean1(read_a);b1<=mean1(read_b);state<=CHOOSE;end
    CHOOSE:begin
     if(cell_index==CELLS-1)begin x<=0;ly<=0;state<=PAL_READ;end
     else begin cell_index<=cell_index+1;state<=READ0;end
    end
    PAL_READ:state<=EMIT;
    EMIT:if(m_ready)begin
     if(x==WIDTH-1)begin
      x<=0;
      if(ly==BLOCK-1)begin
       if(strip==STRIPS-1)begin state<=IDLE;done<=1;end
       else begin strip<=strip+1;state<=CLEAR;clear_addr<=0;end
      end else begin ly<=ly+1;state<=PAL_READ;end
     end else begin
      x<=x+1;
      if(local_x==BLOCK-1)state<=PAL_READ;
     end
    end
    default:state<=IDLE;
   endcase
  end
 end
`ifndef SYNTHESIS
 initial begin
  if((BLOCK!=8 && BLOCK!=16) || WIDTH%BLOCK || HEIGHT%BLOCK || WIDTH<BLOCK || HEIGHT<BLOCK)
   $fatal(1,"lowpoly_stream requires BLOCK 8/16 and dimensions divisible by BLOCK");
 end
`endif
endmodule
