// Shared bit-serial arithmetic with one register file and one carry chain.
// Same low-80-bit product, unsigned division and floor sqrt contract as rev2.
module p2_scalar_math(input clk,rst_n,start,input[1:0]op,input[79:0]a,b,
 output reg busy,done,error,output wire[79:0]value,remainder);
 reg[1:0]mode;reg[6:0]count;reg[79:0]x,y,acc;reg[39:0]q;
 assign value=error?80'd0:mode==0?acc:mode==1?x:{40'd0,q};
 assign remainder=error||mode==0?80'd0:acc;
 reg[80:0]lhs,rhs;wire subtract=mode!=0;
 always @*begin
  lhs={1'b0,acc};rhs={1'b0,x};
  if(mode==1)begin lhs={acc,x[79]};rhs={1'b0,y};end
  else if(mode==2)begin lhs={39'd0,acc[39:0],x[79:78]};rhs={39'd0,q[39:0],2'b01};end
 end
 wire[81:0]result={1'b0,lhs}+{1'b0,(subtract?~rhs:rhs)}+subtract;
 wire ge=result[81];
 always @(posedge clk)begin
  if(!rst_n)begin busy<=0;done<=0;error<=0;mode<=0;count<=0;x<=0;y<=0;acc<=0;q<=0;end
  else begin
   done<=0;
   if(start&&!busy)begin
    error<=0;mode<=op;x<=a;y<=b;acc<=0;q<=0;count<=0;
    if(op==3||(op==1&&b==0))begin error<=1;done<=1;end
    else busy<=1;
   end else if(busy)case(mode)
    0:begin
     if(y[0])acc<=result[79:0];x<=x<<1;y<=y>>1;count<=count+1'b1;
     if(count==79||y[79:1]==0)begin busy<=0;done<=1;end
    end
    1:begin
     x<={x[78:0],ge};count<=count+1'b1;acc<=ge?result[79:0]:lhs[79:0];
     if(count==79)begin busy<=0;done<=1;end
    end
    2:begin
     x<=x<<2;count<=count+1'b1;acc<=ge?{38'd0,result[41:0]}:{38'd0,lhs[41:0]};q<={q[38:0],ge};
     if(count==39)begin busy<=0;done<=1;end
    end
   endcase
  end
 end
endmodule
