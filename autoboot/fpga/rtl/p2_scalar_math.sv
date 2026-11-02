// Shared 80-bit bit-serial arithmetic. No multiplier/divider DSP inference.
// op=0 unsigned product (low 80 bits), op=1 unsigned division with remainder,
// op=2 floor integer square root. Inputs held only on start && !busy.
module p2_scalar_math(input clk,rst_n,start,input[1:0]op,input[79:0]a,b,
 output reg busy,done,error,output reg[79:0]value,remainder);
 reg[1:0]mode;reg[6:0]count;reg[79:0]x,y,acc,q;reg[80:0]rem;
 reg[79:0]rad;reg[41:0]sr;reg[39:0]root;
 wire[80:0]div_trial={rem[79:0],x[79]};
 wire[41:0]sqrt_trial={sr[39:0],rad[79:78]};
 wire[41:0]sqrt_sub={root,2'b01};
 always @(posedge clk)begin
 if(!rst_n)begin busy<=0;done<=0;error<=0;value<=0;remainder<=0;mode<=0;count<=0;x<=0;y<=0;acc<=0;q<=0;rem<=0;rad<=0;sr<=0;root<=0;end
 else begin
 done<=0;
 if(start&&!busy)begin
 error<=0;mode<=op;x<=a;y<=b;acc<=0;q<=0;rem<=0;rad<=a;sr<=0;root<=0;count<=0;
 if(op==3||(op==1&&b==0))begin error<=1;done<=1;value<=0;remainder<=0;end
 else busy<=1;
 end else if(busy)case(mode)
 0:begin
 if(y[0])acc<=acc+x;x<=x<<1;y<=y>>1;count<=count+1'b1;
 if(count==79)begin busy<=0;done<=1;value<=y[0]?acc+x:acc;remainder<=0;end
 end
 1:begin
 x<=x<<1;count<=count+1'b1;
 if(div_trial>={1'b0,y})begin rem<=div_trial-{1'b0,y};q<={q[78:0],1'b1};end
 else begin rem<=div_trial;q<={q[78:0],1'b0};end
 if(count==79)begin busy<=0;done<=1;value<={q[78:0],div_trial>={1'b0,y}};remainder<=div_trial>={1'b0,y}?div_trial-{1'b0,y}:div_trial;end
 end
 2:begin
 rad<=rad<<2;count<=count+1'b1;
 if(sqrt_trial>=sqrt_sub)begin sr<=sqrt_trial-sqrt_sub;root<={root[38:0],1'b1};end
 else begin sr<=sqrt_trial;root<={root[38:0],1'b0};end
 if(count==39)begin busy<=0;done<=1;value<={40'd0,root[38:0],sqrt_trial>=sqrt_sub};remainder<=sqrt_trial>=sqrt_sub?sqrt_trial-sqrt_sub:sqrt_trial;end
 end
 endcase
 end end
endmodule
