module tb_alu;
reg[31:0]src1,src2,addSub;reg[1:0]ctrl,bitCtrl,shift;reg less;
wire[31:0]r1,r2,e1,e2;
EfxCPUSp1 vendor1(.src1(src1),.src2(src2),.addSub(addSub),.ctrl(ctrl),.bitCtrl(bitCtrl),.less(less),.result(r1));
EfxCPUSp2 vendor2(.src1(src1),.src2(src2),.ctrl(shift),.result(r2));
BootAlu1 model1(.src1(src1),.src2(src2),.addSub(addSub),.ctrl(ctrl),.bitCtrl(bitCtrl),.less(less),.result(e1));
BootAlu2 model2(.src1(src1),.src2(src2),.ctrl(shift),.result(e2));
initial begin
for(integer i=0;i<1000;i++)begin
 src1=$random;src2=$random;addSub=$random;less=i%2;
 for(integer c=0;c<3;c++)for(integer b=0;b<3;b++)for(integer k=1;k<=3;k++)begin
 ctrl=c;bitCtrl=b;shift=k;#1;
 if(r1!==e1||r2!==e2)$fatal(1,"ALU mismatch ctrl=%d bit=%d shift=%d r1=%h e1=%h r2=%h e2=%h",ctrl,bitCtrl,shift,r1,e1,r2,e2);
 end
end
$display("VENDOR_ALU_PASS 27000 valid control/input combinations");$finish;
end
endmodule
