`timescale 1ns/1ps
module tb_rotate_osd;
 localparam W=1280,H=720;
 reg clk=0;
 always #5 clk=~clk;
 reg rst_n=0,frame_start=0,de=0,hs=0,vs=0,fps_valid=0;
 reg [11:0] x=0,y=0,fps_bcd=0;
 reg [2:0] style_id=0;
 reg [23:0] rgb=0,rgb_rotated=0;
 wire rd,rh,rv,nd,nh,nv,td,th,tv;
 wire [23:0] rr,nr,tr;
 fps_osd_reference ref0(.clk(clk),.rst_n(rst_n),.frame_start(frame_start),.x(x),.y(y),
  .de(de),.hs(hs),.vs(vs),.rgb(rgb),.fps_bcd(fps_bcd),.fps_valid(fps_valid),
  .style_id(style_id),.out_de(rd),.out_hs(rh),.out_vs(rv),.out_rgb(rr));
 fps_osd dut0(.clk(clk),.rst_n(rst_n),.frame_start(frame_start),.x(x),.y(y),
  .de(de),.hs(hs),.vs(vs),.rgb(rgb),.fps_bcd(fps_bcd),.fps_valid(fps_valid),
  .style_id(style_id),.out_de(nd),.out_hs(nh),.out_vs(nv),.out_rgb(nr));
 fps_osd #(.ROTATE_180(1),.FRAME_WIDTH(W),.FRAME_HEIGHT(H)) dut180(
  .clk(clk),.rst_n(rst_n),.frame_start(frame_start),.x(x),.y(y),
  .de(de),.hs(hs),.vs(vs),.rgb(rgb_rotated),.fps_bcd(fps_bcd),.fps_valid(fps_valid),
  .style_id(style_id),.out_de(td),.out_hs(th),.out_vs(tv),.out_rgb(tr));
 reg [23:0] original [0:W*H-1];
 reg [23:0] rotated [0:W*H-1];
 reg previous_de=0,previous_hs=0,previous_vs=0;
 integer previous_x=0,previous_y=0,visible_count=0,total=0;
 function automatic [23:0] background(input integer px,py);
  reg [7:0] r,g,b;
  begin r=(px*13+py*3)&255;g=(px*5+py*7)&255;b=(px+py*11)&255;background={r,g,b};end
 endfunction
 task automatic tick(input integer px,py,input bit ide,ih,iv,fs);
  begin
   @(negedge clk);
   x=px;y=py;de=ide;hs=ih;vs=iv;frame_start=fs;
   rgb=background(px,py);rgb_rotated=background(W-1-px,H-1-py);
   @(posedge clk);#1;
   if({rd,rh,rv,rr} !== {nd,nh,nv,nr}) $fatal(1,"Default path changed at %0d,%0d",previous_x,previous_y);
   if({rd,rh,rv} !== {td,th,tv}) $fatal(1,"Rotation changed video timing");
   if({rd,rh,rv} !== {previous_de,previous_hs,previous_vs}) $fatal(1,"Video delay changed");
   if(previous_de)begin
    original[previous_y*W+previous_x]=rr;
    rotated[previous_y*W+previous_x]=tr;
    visible_count++;
   end
   previous_de=ide;previous_hs=ih;previous_vs=iv;previous_x=px;previous_y=py;
  end
 endtask
 integer style,xx,yy,p;
 initial begin
  repeat(3)@(negedge clk);rst_n=1;
  for(style=1;style<=5;style++)begin
   style_id=style;
   case(style)
    1:fps_bcd=12'h027;
    2:fps_bcd=12'h123;
    3:fps_bcd=12'h999;
    4:fps_bcd=12'hfff;
    5:fps_bcd=12'h105;
   endcase
   fps_valid=style!=4;
   visible_count=0;
   tick(0,0,0,0,1,1);
   repeat(8)tick(0,0,0,0,1,0);
   tick(0,0,0,0,0,0);
   for(yy=0;yy<H;yy++)begin
    for(xx=0;xx<W;xx++)tick(xx,yy,1,0,0,0);
    repeat(4)tick(0,yy,0,1,0,0);
   end
   tick(0,0,0,0,0,0);
   if(visible_count!=W*H)$fatal(1,"Wrong pixel count: %0d",visible_count);
   for(p=0;p<W*H;p++)begin
    if(rotated[p]!==original[W*H-1-p])
     $fatal(1,"Rotation mismatch style=%0d pixel=%0d expected=%06x actual=%06x",style,p,original[W*H-1-p],rotated[p]);
   end
   total+=visible_count;
   $display("PASS style %0d: all %0d pixels; exact 180-degree overlay; original behavior/timing unchanged",style,visible_count);
  end
  $display("PASS OSD rotation: %0d pixels, five Chinese labels, FPS digits/invalid state, DE/HS/VS preserved",total);
  $finish;
 end
 initial begin #100000000;$fatal(1,"Timeout");end
endmodule
