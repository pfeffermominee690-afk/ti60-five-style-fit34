// Firmware writes inactive text RAM, then commits. Bank switches only at VS.
module capture_osd(input clk,pclk,rst_n,psel,penable,pwrite,input[11:0]paddr,input[31:0]pwdata,
 output[31:0]prdata,output error,input[11:0]x,y,input de,hs,vs,input[23:0]rgb,
 output reg out_de,out_hs,out_vs,output reg[23:0]out_rgb);
 reg[31:0]text[0:255];reg[7:0]font[0:2047];initial $readmemh("capture-font.hex",font);
 reg request,front,vs_d,valid,details;
 reg[1:0]detail_bank;
 (* async_reg="true" *)reg[1:0]req_sync,ack_sync;
 wire pending=request!=ack_sync[1];
 assign prdata={31'd0,pending};
 assign error=psel&&penable&&(paddr[1:0]!=0||paddr<'h3fc||paddr>'h5fc||(pwrite&&pending));
 always @(posedge clk)begin
  if(!rst_n)begin request<=0;ack_sync<=0;detail_bank<=0;end
  else begin
   ack_sync<={ack_sync[0],front};
   if(psel&&penable&&pwrite&&!error)begin
    if(paddr=='h3fc)begin request<=!request;detail_bank[!request]<=pwdata[1];end
    else text[{!request,paddr[8:2]}]<=pwdata;
   end
  end
 end
 wire[11:0]dx=x-16,dy=y-16;
 wire panel=de&&valid&&x>=16&&x<(details?1040:528)&&y>=16&&y<(details?272:48);
 reg[31:0]word_q;reg[1:0]byte_q;reg[3:0]row_q;reg[2:0]col_q,col2;
 wire[7:0]ch=word_q[byte_q*8+:8];reg[7:0]bits_q;
 reg[1:0]panel_q,de_q,hs_q,vs_q;reg[23:0]rgb1,rgb2;
 always @(posedge pclk)begin
  word_q<=text[{front,dy[7:5],dx[9:6]}];byte_q<=dx[5:4];row_q<=dy[4:1];col_q<=dx[3:1];
  bits_q<=font[{ch[6:0],row_q}];col2<=col_q;
  if(!rst_n)begin front<=0;req_sync<=0;vs_d<=0;valid<=0;details<=0;panel_q<=0;de_q<=0;hs_q<=0;vs_q<=0;out_de<=0;out_hs<=0;out_vs<=0;out_rgb<=0;rgb1<=0;rgb2<=0;end
  else begin
   req_sync<={req_sync[0],request};vs_d<=vs;
   if(vs&&!vs_d&&req_sync[1]!=front)begin front<=req_sync[1];valid<=1;details<=detail_bank[req_sync[1]];end
   panel_q<={panel_q[0],panel};de_q<={de_q[0],de};hs_q<={hs_q[0],hs};vs_q<={vs_q[0],vs};rgb1<=rgb;rgb2<=rgb1;
   out_de<=de_q[1];out_hs<=hs_q[1];out_vs<=vs_q[1];
   out_rgb<=panel_q[1]?(bits_q[7-col2]?24'hffffff:{2'b0,rgb2[23:18],2'b0,rgb2[15:10],2'b0,rgb2[7:2]}):rgb2;
  end
 end
endmodule
