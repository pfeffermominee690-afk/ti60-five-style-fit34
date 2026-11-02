module p2_norm_coeff(input clk,rst_n,start,input[18:0]n,input signed[26:0]sum,input[32:0]sumsq,
 input signed[31:0]gamma_q20,beta_q18,input[63:0]epsilon_q24,
 output reg busy,done,error,output reg signed[18:0]coefficient,output reg signed[31:0]offset,output reg[5:0]adjust,
 output reg[15:0]cycles);
 reg go;reg[1:0]op;reg[79:0]ma,mb;wire mbusy,mdone,merror;wire[79:0]value,rem;
 p2_scalar_math math(clk,rst_n,go,op,ma,mb,mbusy,mdone,merror,value,rem);
 reg[3:0]state;reg[18:0]nn;reg signed[26:0]ss;reg signed[31:0]gg,bb;reg[63:0]ee;
 reg[79:0]prod,diff;reg[39:0]root;
 reg signed[42:0]full_coef,rounded_coef;reg signed[45:0]mean_value;reg signed[31:0]beta_scaled;
 wire[26:0]sum_mag=ss[26]?-ss:ss;
 wire[31:0]gamma_mag=gg[31]?-gg:gg;
 wire[42:0]coef_mag=full_coef[42]?-full_coef:full_coef;
 wire[42:0]round_mag=rounded_coef[42]?-rounded_coef:rounded_coef;
 wire[42:0]coef_rounded={1'b0,value[41:0]}+(({rem[39:0],1'b0}>{1'b0,root})||(({rem[39:0],1'b0}=={1'b0,root})&&value[0]));
 wire[45:0]mean_rounded={1'b0,value[44:0]}+(({rem[18:0],1'b0}>{1'b0,nn})||(({rem[18:0],1'b0}=={1'b0,nn})&&value[0]));
 wire signed[46:0]offset_value={{15{beta_scaled[31]}},beta_scaled}-{mean_value[45],mean_value};
 function automatic signed[42:0]rne43(input signed[42:0]v,input[5:0]sh);
 reg[42:0]m,q,r,d,z;
 begin m=v<0?-v:v;d=43'd1<<sh;q=m>>sh;r=m&(d-1'b1);z=q+(({r,1'b0}>{1'b0,d})||(({r,1'b0}=={1'b0,d})&&q[0]));rne43=v<0?-$signed(z):$signed(z);end
 endfunction
 function automatic signed[31:0]rne32(input signed[31:0]v,input[5:0]sh);
 reg[31:0]m,q,r,d,z;
 begin
 m=v<0?-v:v;d=32'd1<<sh;q=m>>sh;r=m&(d-1'b1);
 z=q+(({r,1'b0}>{1'b0,d})||(({r,1'b0}=={1'b0,d})&&q[0]));
 rne32=sh>=32?32'sd0:(v<0?-$signed(z):$signed(z));end
 endfunction
 reg[5:0]next_adj;integer k;
 always @*begin next_adj=0;for(k=18;k<43;k=k+1)if(coef_mag[k])next_adj=k-17;end
 always @(posedge clk)begin
 if(!rst_n)begin
 busy<=0;done<=0;error<=0;coefficient<=0;offset<=0;adjust<=0;cycles<=0;go<=0;op<=0;ma<=0;mb<=0;state<=0;
 nn<=0;ss<=0;gg<=0;bb<=0;ee<=0;prod<=0;diff<=0;root<=0;full_coef<=0;rounded_coef<=0;beta_scaled<=0;mean_value<=0;
 end else begin
 go<=0;done<=0;
 if(start&&!busy)begin
 error<=0;cycles<=0;nn<=n;ss<=sum;gg<=gamma_q20;bb<=beta_q18;ee<=epsilon_q24;
 if(n==0||n>307200)begin error<=1;done<=1;end
 else begin busy<=1;state<=1;op<=0;ma<={47'd0,sumsq};mb<={61'd0,n};go<=1;end
 end else if(busy)begin
 cycles<=cycles+1'b1;
 if(mdone&&merror)begin busy<=0;done<=1;error<=1;end
 else case(state)
 1:if(mdone)begin prod<=value;op<=0;ma<={53'd0,sum_mag};mb<={53'd0,sum_mag};go<=1;state<=2;end
 2:if(mdone)begin
 if(value>prod)begin busy<=0;done<=1;error<=1;end
 else begin diff<=prod-value;op<=0;ma<={61'd0,nn};mb<={61'd0,nn};go<=1;state<=3;end
 end
 3:if(mdone)begin op<=1;ma<=diff<<24;mb<=value;go<=1;state<=4;end
 4:if(mdone)begin op<=2;ma<=value+{16'd0,ee};mb<=0;go<=1;state<=5;end
 5:if(mdone)begin root<=value==0?40'd1:value[39:0];op<=1;ma<={38'd0,gamma_mag,10'd0};mb<=value==0?80'd1:value;go<=1;state<=6;end
 6:if(mdone)begin
 if(|value[79:42])begin busy<=0;done<=1;error<=1;end
 else begin full_coef<=gg[31]?-$signed(coef_rounded):$signed(coef_rounded);state<=7;end
 end
 7:begin adjust<=next_adj;state<=10;end
 10:begin rounded_coef<=rne43(full_coef,adjust);beta_scaled<=rne32(bb,adjust);state<=11;end
 11:begin
 if(rounded_coef>43'sd262143||rounded_coef< -43'sd262144)begin busy<=0;done<=1;error<=1;end
 else begin coefficient<=rounded_coef[18:0];op<=0;ma<={53'd0,sum_mag};mb<={37'd0,round_mag};go<=1;state<=8;end
 end
 8:if(mdone)begin op<=1;ma<=value;mb<={61'd0,nn};go<=1;state<=9;end
 9:if(mdone)begin
 if(|value[79:45])begin busy<=0;done<=1;error<=1;end
 else begin mean_value<=(ss[26]^coefficient[18])?-$signed(mean_rounded):$signed(mean_rounded);state<=12;end
 end
 12:begin busy<=0;done<=1;if(offset_value>47'sd2147483647||offset_value< -47'sd2147483648)error<=1;else offset<=offset_value[31:0];end
 endcase
 end
 end end
endmodule
