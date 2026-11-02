// Offline register interface to the actual integer channel-coefficient unit.
// Not a neural job scheduler. Configuration writes rejected while busy.
module p2_coeff_regs(input clk,rst_n,input[11:0]paddr,input psel,penable,pwrite,input[31:0]pwdata,
 output reg[31:0]prdata,output pready,pslverror);
 reg[31:0]cfg[0:7];reg start,finished;wire busy,done,error;wire signed[18:0]coefficient;wire signed[31:0]offset;wire[5:0]adjust;wire[15:0]cycles;
 wire access=psel&&penable;wire[9:0]idx=paddr[11:2];
 assign pready=1;assign pslverror=access&&(paddr[1:0]!=0||(pwrite&&busy));
 p2_norm_coeff coeff(.clk(clk),.rst_n(rst_n),.start(start),.n(cfg[0][18:0]),.sum(cfg[1][26:0]),.sumsq({cfg[3][0],cfg[2]}),.gamma_q20(cfg[4]),.beta_q18(cfg[5]),.epsilon_q24({cfg[7],cfg[6]}),.busy(busy),.done(done),.error(error),.coefficient(coefficient),.offset(offset),.adjust(adjust),.cycles(cycles));
 integer k;
 always @(posedge clk)begin
 if(!rst_n)begin for(k=0;k<8;k=k+1)cfg[k]<=0;start<=0;finished<=0;end
 else begin
 start<=0;if(done)finished<=1;
 if(access&&pwrite&&!pslverror)begin
 for(k=0;k<8;k=k+1)if(idx==k)cfg[k]<=pwdata;
 if(idx==8&&pwdata[0])begin start<=1;finished<=0;end
 end end end
 always @*begin
 prdata=0;
 for(integer j=0;j<8;j=j+1)if(idx==j)prdata=cfg[j];
 case(idx)
 8:prdata={29'd0,error,finished,busy};
 9:prdata={{13{coefficient[18]}},coefficient};10:prdata=offset;
 11:prdata={26'd0,adjust};12:prdata={16'd0,cycles};13:prdata=32'h494e3830;
 endcase end
endmodule
