`timescale 1ns/1ps
// Behavioral image requirements, independent of the DUT's Sobel/tone equations.
// These checks intentionally test visibility, noise rejection, continuity and
// stream integrity rather than merely duplicating the implementation.
module tb_sobel_quality;
 localparam W=64,H=48,N=W*H;
 reg clk=0,rst_n=0,clear=0,enable=1,s_valid=0;
 reg[7:0]threshold=12;reg[23:0]s_rgb=0;
 wire[23:0]m_rgb;wire m_valid;
 always #5 clk=~clk;
 capture_sobel #(.WIDTH(W))dut(.*);
 reg recording=0;
 reg[23:0]pixels[0:N-1],source_pixels[0:N-1];
 integer outputs=0,cases=0,visible_lines=0,bypass_bytes=0;
 integer flat_pixels=0,noise_min=255;
 reg[31:0]rng=32'h389ab712;
 always @(negedge clk)if(recording&&m_valid)begin
  if(outputs>=N)$fatal(1,"extra output pixel");
  pixels[outputs]=m_rgb;outputs++;
 end
 task begin_frame(input bit bypass);
  @(negedge clk);recording=0;s_valid=0;clear=1;enable=!bypass;
  repeat(3)@(negedge clk);
  clear=0;outputs=0;recording=1;
 endtask
 task emit(input reg[23:0]value,input bit gaps);
  // Insert bubbles independent of pixel coordinates, including line transitions.
  rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};
  if(gaps&&rng[2:0]<3)begin
   @(negedge clk);s_valid=0;
   repeat(rng[4:3])@(negedge clk);
  end
  @(negedge clk);s_rgb=value;s_valid=1;
 endtask
 task finish_frame;
  @(negedge clk);s_valid=0;
  repeat(6)@(negedge clk);
  if(outputs!=N)$fatal(1,"output count got %0d wanted %0d",outputs,N);
  recording=0;cases++;
 endtask
 // kind: horizontal / vertical / diagonal step, flat, bounded noise, RGB bypass.
 task make_frame(input integer kind,contrast,shift,noise,input bit gaps);
  integer x,y,v,n;reg[23:0]value;
  begin_frame(kind==5);
  for(y=0;y<H;y++)for(x=0;x<W;x++)begin
   n=y*W+x;
   case(kind)
    0:v=100+(y>=24+shift?contrast:0);
    1:v=100+(x>=32+shift?contrast:0);
    2:v=100+(x+y>=56+shift?contrast:0);
    4:begin rng={rng[30:0],rng[31]^rng[21]^rng[1]^rng[0]};v=100+int'(rng[15:0]%(2*noise+1))-noise;end
    default:v=100;
   endcase
   if(kind==5)value={8'((x*13+y*7)&255),8'((x*3+y*17)&255),8'((x*23+y*5)&255)};
   else value={3{v[7:0]}};
   source_pixels[n]=value;emit(value,gaps);
  end
  finish_frame();
 endtask
 task check_border;
  for(integer y=0;y<H;y++)for(integer x=0;x<W;x++)begin
   if((x<2||y<2)&&pixels[y*W+x]!==24'hffffff)$fatal(1,"frame-clear/border stale data x%0d y%0d",x,y);
   if(pixels[y*W+x][23:16]!==pixels[y*W+x][7:0]||pixels[y*W+x][15:8]!==pixels[y*W+x][7:0])$fatal(1,"colored ink pixel");
  end
 endtask
 task check_step(input integer kind,contrast,shift);
  integer n,local_min,cut,limit,distance_to_edge;
  check_border();limit=contrast==8?205:16;
  // Every interior scan through a boundary must contain a visible line;
  // stronger 16/32-level boundaries must include nearly black ink.
  if(kind==0)begin
   for(integer x=3;x<W-3;x++)begin
    local_min=255;
    for(integer y=24+shift;y<=25+shift;y++)if(pixels[y*W+x][7:0]<local_min)local_min=pixels[y*W+x][7:0];
    if(local_min>limit)$fatal(1,"horizontal missing/faint contrast%0d shift%0d x%0d ink%0d",contrast,shift,x,local_min);
    visible_lines++;
   end
  end else begin
   for(integer y=3;y<H-3;y++)begin
    local_min=255;cut=kind==1?32+shift:56+shift-y;
    for(integer x=cut;x<=cut+(kind==1?1:3);x++)if(x>=2&&x<W&&pixels[y*W+x][7:0]<local_min)local_min=pixels[y*W+x][7:0];
    if(local_min>limit)$fatal(1,"missing/faint kind%0d contrast%0d shift%0d y%0d ink%0d",kind,contrast,shift,y,local_min);
    visible_lines++;
   end
  end
  // Flat regions on both sides of a boundary must remain white.
  for(integer y=3;y<H;y++)for(integer x=3;x<W;x++)begin
   distance_to_edge=kind==0?y-(24+shift):kind==1?x-(32+shift):(x+y)-(56+shift);
   if((distance_to_edge<0||distance_to_edge>3)&&pixels[y*W+x]!==24'hffffff)$fatal(1,"spurious line away from boundary kind%0d x%0d y%0d",kind,x,y);
  end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst_n=1;
  for(integer c=8;c<=32;c=c*2)for(integer kind=0;kind<3;kind++)for(integer shift=-1;shift<=1;shift++)begin
   make_frame(kind,c,shift,0,1);check_step(kind,c,shift);
  end
  make_frame(3,0,0,0,1);check_border();
  for(integer i=0;i<N;i++)begin
   if(pixels[i]!==24'hffffff)$fatal(1,"flat-field ink at %0d",i);
   flat_pixels++;
  end
  for(integer noise=1;noise<=2;noise++)begin
   make_frame(4,0,0,noise,1);check_border();
   for(integer i=0;i<N;i++)begin
    if(pixels[i][7:0]<192)$fatal(1,"strong ink from +/- %0d noise at %0d: %0d",noise,i,pixels[i][7:0]);
    if(pixels[i][7:0]<noise_min)noise_min=pixels[i][7:0];
   end
  end
  make_frame(5,0,0,0,1);
  for(integer i=0;i<N;i++)begin
   if(pixels[i]!==source_pixels[i])$fatal(1,"bypass corruption at %0d",i);
   bypass_bytes+=3;
  end
  // Abort midway through a noisy frame, with an output still in flight.
  begin_frame(0);
  for(integer i=0;i<137;i++)emit(i[0]?24'hffffff:24'h000000,1);
  make_frame(3,0,0,0,1);check_border();
  for(integer i=0;i<N;i++)if(pixels[i]!==24'hffffff)$fatal(1,"stale ink after partial-frame clear %0d",i);
  $display("PASS quality %0d complete frames, %0d visible boundary scans at contrast8/16/32 and shifts-1/0/1, %0d flat white pixels, +/-1/2 noise minimum ink%0d, %0d exact bypass bytes, bubbles and partial-frame clear",cases,visible_lines,flat_pixels,noise_min,bypass_bytes);
  $finish;
 end
 initial begin #20000000;$fatal(1,"quality timeout");end
endmodule
