// Full-frame readback: length, AXI response/last and 128-bit rolling fingerprint.
// Fingerprint is a corruption diagnostic, not a cryptographic or collision-free proof.
module capture_verifier #(parameter BEATS=57600)(input clk,rst_n,
 input[11:0]paddr,input psel,penable,pwrite,input[31:0]pwdata,
 output reg[31:0]prdata,output pready,pslverror,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input[127:0]rdata,input[1:0]rresp,input rlast,rvalid,output rready);
 reg[1:0]state;reg done;reg[31:0]base,ptr,left,errors,frames,bytes;
 reg[3:0]beat;reg[127:0]expected,hash;
 wire access=psel&&penable,wr=access&&pwrite;
 assign pready=1;
 assign pslverror=access&&(paddr[1:0]!=0||paddr>44||(pwrite&&!(paddr==4||paddr==8||paddr>=16&&paddr<=28))||(pwrite&&state!=0));
 assign araddr=ptr;assign arlen=15;assign arvalid=state==1;assign rready=state==2;
 always @*begin
  prdata=0;
  case(paddr)
   0:prdata=32'h56455231;
   4:prdata={29'd0,(errors!=0),done,(state!=0)};
   8:prdata=base;12:prdata=errors;
   16,20,24,28:prdata=hash[(paddr-16)*8+:32];
   32:prdata=frames;36:prdata=bytes;40:prdata=BEATS*16;44:prdata=left;
  endcase
 end
 always @(posedge clk)begin
  if(!rst_n)begin state<=0;done<=0;base<=0;ptr<=0;left<=0;beat<=0;expected<=0;hash<=0;errors<=0;frames<=0;bytes<=0;end
  else begin
   if(wr&&!pslverror)case(paddr)
    8:base<=pwdata;
    16,20,24,28:expected[(paddr-16)*8+:32]<=pwdata;
    4:if(pwdata==1)begin
     done<=0;errors<=0;hash<=0;bytes<=0;beat<=0;ptr<=base;left<=BEATS;
     if(base[11:0]!=0||base<32'h01000000||base>32'h01200000)begin errors<=8;done<=1;end
     else state<=1;
    end
   endcase
   case(state)
    1:if(arready)state<=2;
    2:if(rvalid)begin
     hash<={hash[126:0],1'b0}^(hash[127]?128'h87:128'd0)^rdata;bytes<=bytes+16;
     if(rresp!=0||rlast!=(beat==15))errors<=errors|1;
     if(rlast)begin
      ptr<=ptr+256;left<=left-16;beat<=0;
      if(left==16)state<=3;else state<=1;
     end else beat<=beat+1'b1;
    end
    3:begin
     state<=0;done<=1;
     if(hash!=expected||bytes!=BEATS*16)errors<=errors|2;
     else if(errors==0)frames<=frames+1;
    end
   endcase
  end
 end
endmodule
