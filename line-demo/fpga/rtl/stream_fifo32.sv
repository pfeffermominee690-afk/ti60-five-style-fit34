// Small elastic queue. Depth must be a power of two (at least two).
module stream_fifo32 #(parameter DEPTH=64, AW=$clog2(DEPTH))(
    input wire clk,rst_n,clear,
    input wire s_valid, output wire s_ready, input wire [31:0] s_data,
    output wire m_valid, input wire m_ready, output wire [31:0] m_data,
    output reg [AW:0] level
);
    reg [31:0] mem[0:DEPTH-1];
    reg [AW-1:0] wr,rd;
    assign s_ready=level<DEPTH;
    assign m_valid=level!=0;
    assign m_data=mem[rd];
    wire push=s_valid && s_ready, pop=m_valid && m_ready;
    always @(posedge clk) begin
        if(!rst_n || clear) begin wr<=0;rd<=0;level<=0;end
        else begin
            if(push) begin mem[wr]<=s_data;wr<=wr+1'b1;end
            if(pop) rd<=rd+1'b1;
            case({push,pop})
                2'b10:level<=level+1'b1;
                2'b01:level<=level-1'b1;
                default:;
            endcase
        end
    end
endmodule
