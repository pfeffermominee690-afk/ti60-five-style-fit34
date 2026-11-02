module capture_gray_counter(input sclk,dclk,rst_n,input[31:0]value,output[31:0]result);
 reg[31:0]gray;
 (* async_reg="true" *)reg[31:0]g1,g2;
 always @(posedge sclk)if(!rst_n)gray<=0;else gray<=value^(value>>1);
 always @(posedge dclk)if(!rst_n)begin g1<=0;g2<=0;end else begin g1<=gray;g2<=g1;end
 genvar k;generate for(k=0;k<32;k=k+1)begin:g assign result[k]=^g2[31:k];end endgenerate
endmodule
