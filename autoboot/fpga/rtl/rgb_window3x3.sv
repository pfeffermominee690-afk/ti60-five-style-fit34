// Padded raster generator plus two synchronous line memories. Memory contents
// need not be reset: zero border rows flush stale data before the first window.
module rgb_window3x3 #(parameter WIDTH=640, HEIGHT=480)(
    input wire clk,rst_n,start,
    output wire start_ready,
    input wire s_valid,
    output wire s_ready,
    input wire [23:0] s_rgb,
    output reg m_valid,
    input wire m_ready,
    output reg [215:0] m_window,
    output reg m_last,
    output reg frame_done,
    output wire busy
);
    reg active, phase;
    reg [15:0] x,y;
    reg [23:0] line1[0:WIDTH+1],line2[0:WIDTH+1];
    reg [23:0] r1,r2,pixel;
    reg [23:0] top0,top1,mid0,mid1,bot0,bot1;
    wire interior = x>0 && x<=WIDTH && y>0 && y<=HEIGHT;
    wire can_read = active && !phase && (!m_valid || m_ready);
    assign s_ready = can_read && interior;
    assign start_ready = !active && !phase && !m_valid;
    assign busy = !start_ready;
    always @(posedge clk) begin
        if (!rst_n) begin
            active<=0; phase<=0; m_valid<=0; m_last<=0;
            frame_done<=0; x<=0; y<=0;
            top0<=0;top1<=0;mid0<=0;mid1<=0;bot0<=0;bot1<=0;
        end else begin
            frame_done<=0;
            if(m_valid && m_ready) begin
                m_valid<=0;
                if(m_last) frame_done<=1;
            end
            if(start && start_ready) begin
                active<=1;x<=0;y<=0;
                top0<=0;top1<=0;mid0<=0;mid1<=0;bot0<=0;bot1<=0;
            end else if(can_read && (!interior || s_valid)) begin
                r1<=line1[x]; r2<=line2[x];
                pixel<=interior?s_rgb:24'b0;
                phase<=1;
            end else if(phase) begin
                line1[x]<=pixel; line2[x]<=r1;
                top0<=top1;top1<=r2;
                mid0<=mid1;mid1<=r1;
                bot0<=bot1;bot1<=pixel;
                if(x>=2 && y>=2) begin
                    m_window<={pixel,bot1,bot0,r1,mid1,mid0,r2,top1,top0};
                    m_valid<=1;
                    m_last<=(x==WIDTH+1 && y==HEIGHT+1);
                end
                phase<=0;
                if(x==WIDTH+1) begin
                    x<=0;
                    top0<=0;top1<=0;mid0<=0;mid1<=0;bot0<=0;bot1<=0;
                    if(y==HEIGHT+1) active<=0;
                    else y<=y+1;
                end else x<=x+1;
            end
        end
    end
endmodule
