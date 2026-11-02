// AXI4 32-bit burst DMA: RGBx in DDR, RGB streams to/from the CNN.
// One read burst and one write burst may be outstanding concurrently.
// On an AXI error, drain issued transactions before reporting terminal error.
// Never withdraw VALID on error; no local timeout can cancel an AXI request.
module rgb_frame_dma #(parameter PIXELS=640*480, FIFO_DEPTH=64)(
    input wire clk,rst_n,start,
    input wire [31:0] src_addr,dst_addr,
    output wire start_ready,
    output reg busy,done,
    output reg [31:0] error,cycles,frames,read_pixels,written_pixels,
    output wire s_valid, input wire s_ready, output wire [23:0] s_rgb,
    input wire m_valid, output wire m_ready, input wire [23:0] m_rgb,
    output wire [31:0] araddr, output wire [7:0] arlen,
    output wire arvalid, input wire arready,
    input wire [31:0] rdata, input wire [1:0] rresp,
    input wire rlast,rvalid, output wire rready,
    output wire [31:0] awaddr, output wire [7:0] awlen,
    output wire awvalid, input wire awready,
    output wire [31:0] wdata, output wire [3:0] wstrb,
    output wire wlast,wvalid, input wire wready,
    input wire [1:0] bresp, input wire bvalid, output wire bready
);
    localparam RI=0,RA=1,RR=2, WI=0,WA=1,WW=2,WB=3;
    reg [1:0] rs,ws;
    reg [31:0] rptr,wptr,read_left,write_left,ticks;
    reg [4:0] rn,wn,rbeat,wbeat;
    wire [31:0] rq_data,wq_data;
    wire rq_valid,rq_ready,rq_push,wq_valid,wq_ready,wq_pop;
    wire [$clog2(FIFO_DEPTH):0] rq_level,wq_level;
    wire fire=start && start_ready;
    wire fault=(error!=0);
    // Limit every burst to 16 words and to the current 4 KiB page.
    function automatic [4:0] burst_words(input [31:0] addr,input [31:0] left);
        reg [10:0] page_words; reg [31:0] n;
        begin
            page_words=(13'd4096-{1'b0,addr[11:0]})>>2;
            n=left<16?left:16;
            if(n>page_words) n=page_words;
            burst_words=n[4:0];
        end
    endfunction
    wire [4:0] next_rn=burst_words(rptr,read_left);
    wire [4:0] next_wn=burst_words(wptr,write_left);
    wire rfault=(rvalid && rready &&
        (rresp!=0 || (rlast!=(rbeat==rn-1))));
    wire wfault=bvalid && bready && bresp!=0;
    assign start_ready=!busy;
    assign s_valid=busy && !fault && rq_valid;
    assign s_rgb=rq_data[23:0];
    assign rq_ready=s_valid && s_ready;
    assign m_ready=busy && !fault && wq_ready;
    assign rq_push=rvalid && rready && !fault && !rfault;
    stream_fifo32 #(.DEPTH(FIFO_DEPTH)) input_queue(
        .clk(clk),.rst_n(rst_n),.clear(fire),
        .s_valid(rq_push),.s_ready(),.s_data(rdata),
        .m_valid(rq_valid),.m_ready(rq_ready),.m_data(rq_data),.level(rq_level));
    stream_fifo32 #(.DEPTH(FIFO_DEPTH)) output_queue(
        .clk(clk),.rst_n(rst_n),.clear(fire),
        .s_valid(m_valid && m_ready),.s_ready(wq_ready),.s_data({8'b0,m_rgb}),
        .m_valid(wq_valid),.m_ready(wq_pop),.m_data(wq_data),.level(wq_level));
    assign araddr=rptr; assign arlen=rn-1'b1; assign arvalid=(rs==RA);
    // A whole burst is reserved before AR, hence R cannot overflow the FIFO.
    assign rready=(rs==RR) && (fault || rq_level<FIFO_DEPTH);
    assign awaddr=wptr; assign awlen=wn-1'b1; assign awvalid=(ws==WA);
    assign wdata=wq_data; assign wstrb=4'hf;
    assign wvalid=(ws==WW) && wq_valid;
    assign wlast=(wbeat==wn-1);
    assign wq_pop=wvalid && wready;
    assign bready=(ws==WB);
    always @(posedge clk) begin
        if(!rst_n) begin
            rs<=RI;ws<=WI;busy<=0;done<=0;error<=0;cycles<=0;frames<=0;
            read_pixels<=0;written_pixels<=0;rptr<=0;wptr<=0;
            read_left<=0;write_left<=0;rn<=0;wn<=0;rbeat<=0;wbeat<=0;ticks<=0;
        end else begin
            done<=0;
            if(fire) begin
                busy<=1;error<=0;ticks<=0;read_pixels<=0;written_pixels<=0;
                rptr<=src_addr;wptr<=dst_addr;read_left<=PIXELS;write_left<=PIXELS;
            end else if(busy) begin
                ticks<=ticks+1;
                if(s_valid && s_ready) read_pixels<=read_pixels+1;
                if(rfault || wfault) error<=error |
                    (rfault ? (rresp!=0?32'd1:32'd4):32'd0) |
                    (wfault ? 32'd2:32'd0);
                case(rs)
                    RI:if(!fault && !rfault && !wfault && read_left!=0 &&
                          FIFO_DEPTH-rq_level>=next_rn) begin rn<=next_rn;rbeat<=0;rs<=RA;end
                    RA:if(arready) rs<=RR;
                    RR:if(rvalid && rready) begin
                        // Wait for actual RLAST, including a malformed long burst.
                        if(rlast) begin
                            rs<=RI;rptr<=rptr+{25'b0,rn,2'b0};read_left<=read_left-rn;
                        end else rbeat<=rbeat+1'b1;
                    end
                    default:rs<=RI;
                endcase
                case(ws)
                    WI:if(!fault && !rfault && !wfault && write_left!=0 && wq_level>=next_wn)
                        begin wn<=next_wn;wbeat<=0;ws<=WA;end
                    WA:if(awready) ws<=WW;
                    WW:if(wvalid && wready) begin
                        if(wlast) ws<=WB;
                        else wbeat<=wbeat+1'b1;
                    end
                    WB:if(bvalid) begin
                        ws<=WI;wptr<=wptr+{25'b0,wn,2'b0};write_left<=write_left-wn;
                        if(bresp==0) written_pixels<=written_pixels+wn;
                    end
                    default:ws<=WI;
                endcase
                if(rs==RI && ws==WI &&
                   (fault || (write_left==0 && read_left==0 && read_pixels==PIXELS))) begin
                    busy<=0;done<=1;cycles<=ticks+1;
                    if(!fault) frames<=frames+1;
                end
            end
        end
    end
endmodule
