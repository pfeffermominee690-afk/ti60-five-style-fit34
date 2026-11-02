// 640-pixel streaming Sobel line art. Two grayscale line buffers; one pixel
// accepted per clock. First two rows/columns are white. C selects bypass/ink.
module capture_sobel #(parameter WIDTH=640)(input clk,rst_n,clear,enable,input[7:0]threshold,
 input[23:0]s_rgb,input s_valid,output reg[23:0]m_rgb,output reg m_valid);
 reg[7:0]line1[0:WIDTH-1],line2[0:WIDTH-1];
 reg[9:0]x;reg[9:0]y;reg[9:0]xq,yq;
 reg[7:0]a,b,gq,t0,t1,m0,m1,b0,b1;reg[23:0]rgbq;
 reg validq,mode;reg[7:0]th;
 wire[9:0]gray_sum={2'd0,s_rgb[7:0]}+{1'd0,s_rgb[15:8],1'b0}+{2'd0,s_rgb[23:16]};
 reg signed[11:0]gx,gy;
 reg[11:0]mag;
 reg[11:0]magq;
 reg[23:0]rgb2;
 reg valid2,mode2,border2;
 reg[7:0]th2;
 wire[11:0]d=magq>{4'd0,th2}?magq-{4'd0,th2}:12'd0;
 // Only d=17..53 reaches the strong branch; 9 bits suffice for 6*d.
 wire[8:0]strong_ink=9'd319-({3'd0,d[5:0]}<<2)-({3'd0,d[5:0]}<<1);
 wire[7:0]ink=d>=54?8'd0:d<=16?8'd255-{d[6:0],1'b0}:strong_ink[7:0];
 always @*begin
  gx=($signed({4'd0,b})+$signed({3'd0,a,1'b0})+$signed({4'd0,gq}))-
     ($signed({4'd0,t0})+$signed({3'd0,m0,1'b0})+$signed({4'd0,b0}));
  gy=($signed({4'd0,b0})+$signed({3'd0,b1,1'b0})+$signed({4'd0,gq}))-
     ($signed({4'd0,t0})+$signed({3'd0,t1,1'b0})+$signed({4'd0,b}));
  mag=(gx<0?-gx:gx)+(gy<0?-gy:gy);
 end
 always @(posedge clk)begin
  if(s_valid)begin a<=line1[x];b<=line2[x];line2[x]<=line1[x];line1[x]<=gray_sum[9:2];end
  if(!rst_n||clear)begin x<=0;y<=0;xq<=0;yq<=0;validq<=0;m_valid<=0;m_rgb<=0;mode<=0;th<=0;
   magq<=0;rgb2<=0;valid2<=0;mode2<=0;border2<=0;th2<=0;
   gq<=0;rgbq<=0;t0<=0;t1<=0;m0<=0;m1<=0;b0<=0;b1<=0;
  end else begin
   validq<=s_valid;valid2<=validq;m_valid<=valid2;
   if(s_valid)begin
    xq<=x;yq<=y;gq<=gray_sum[9:2];rgbq<=s_rgb;mode<=enable;th<=threshold;
    if(x==WIDTH-1)begin x<=0;y<=y+1;end else x<=x+1;
   end
   if(validq)begin
    t0<=t1;t1<=b;m0<=m1;m1<=a;b0<=b1;b1<=gq;
    magq<=mag;rgb2<=rgbq;mode2<=mode;th2<=th;border2<=xq<2||yq<2;
   end
   if(valid2)begin
    if(!mode2)m_rgb<=rgb2;
    else if(border2)m_rgb<=24'hffffff;
    else m_rgb<={3{ink}};
   end
  end
 end
endmodule
