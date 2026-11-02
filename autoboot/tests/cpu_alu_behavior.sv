// Simulation-only RV32 ALU behaviors, keyed by enums in the generated SoC.
// Never included in the synthesized FPGA project.
module BootAlu1(input[31:0]src1,src2,input[1:0]bitCtrl,ctrl,input less,input[31:0]addSub,output reg[31:0]result);
always @* case(ctrl)
 0:result=addSub;
 1:result={31'd0,less};
 2:case(bitCtrl)0:result=src1^src2;1:result=src1|src2;2:result=src1&src2;default:result=0;endcase
 default:result=0;
endcase
endmodule
module BootAlu2(input[1:0]ctrl,input[31:0]src1,src2,output reg[31:0]result);
wire[31:0] reversed;
for(genvar i=0;i<32;i++)assign reversed[i]=src1[31-i];
always @* case(ctrl)
 1:result=reversed>>src2[4:0]; // CPU reverses this intermediate in its next stage.
 2:result=src1>>src2[4:0];
 3:result=$signed(src1)>>>src2[4:0];
 default:result=src1;
endcase
endmodule
