// Two AXI read masters; one outstanding burst, ownership held through RLAST.
module p2_read_arbiter(input clk,rst_n,
 input[31:0]a0,a1,input[7:0]n0,n1,input v0,v1,output ready0,ready1,
 output valid0,valid1,input take0,take1,
 output[31:0]araddr,output[7:0]arlen,output arvalid,input arready,
 input rvalid,rlast,output rready);
 reg[1:0]state;reg owner,turn;
 assign araddr=owner?a1:a0;assign arlen=owner?n1:n0;assign arvalid=state==1&&(owner?v1:v0);
 assign ready0=state==1&&!owner&&arready;assign ready1=state==1&&owner&&arready;
 assign valid0=state==2&&!owner&&rvalid;assign valid1=state==2&&owner&&rvalid;
 assign rready=state==2&&(owner?take1:take0);
 always @(posedge clk)begin
  if(!rst_n)begin state<=0;owner<=0;turn<=0;end
  else case(state)
   0:if(v0||v1)begin owner<=v1&&(!v0||turn);state<=1;end
   1:if(arvalid&&arready)begin state<=2;turn<=!owner;end
   2:if(rvalid&&rready&&rlast)state<=0;
  endcase
 end
endmodule
