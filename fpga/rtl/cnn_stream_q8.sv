module cnn_stream_q8 #(parameter WIDTH=640,HEIGHT=480)(
    input wire clk,rst_n,start,
    output wire start_ready,
    input wire cfg_valid,
    output wire cfg_ready,
    input wire [7:0] cfg_addr,
    input wire [31:0] cfg_data,
    output wire model_valid,
    input wire s_valid,
    output wire s_ready,
    input wire [23:0] s_rgb,
    output wire m_valid,
    input wire m_ready,
    output wire [23:0] m_rgb,
    output wire m_last,
    output reg frame_done,
    output reg [31:0] frame_cycles,
    output reg [31:0] compute_frames
);
    reg frame_active;
    reg [31:0] pixel_index,ticks;
    wire win_start_ready,win_valid,win_ready,win_last,win_done,win_busy;
    wire [215:0] win_data;
    wire core_cfg_ready,core_busy;
    wire [31:0] pixels_done;
    wire start_fire=start && start_ready;
    assign start_ready=model_valid && !frame_active && win_start_ready && !core_busy && !cfg_valid;
    assign cfg_ready=core_cfg_ready && !frame_active;
    assign m_last=m_valid && pixel_index==WIDTH*HEIGHT-1;
    rgb_window3x3 #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) windowing(
        .clk(clk),.rst_n(rst_n),.start(start_fire),.start_ready(win_start_ready),
        .s_valid(s_valid),.s_ready(s_ready),.s_rgb(s_rgb),
        .m_valid(win_valid),.m_ready(win_ready),.m_window(win_data),.m_last(win_last),
        .frame_done(win_done),.busy(win_busy));
    cnn_pixel_q8 engine(
        .clk(clk),.rst_n(rst_n),.cfg_valid(cfg_valid && !frame_active),.cfg_ready(core_cfg_ready),
        .cfg_addr(cfg_addr),.cfg_data(cfg_data),.model_valid(model_valid),
        .s_valid(win_valid),.s_ready(win_ready),.s_window(win_data),
        .m_valid(m_valid),.m_ready(m_ready),.m_rgb(m_rgb),.busy(core_busy),.pixels_done(pixels_done));
    always @(posedge clk) begin
        if(!rst_n) begin
            frame_active<=0;pixel_index<=0;ticks<=0;
            frame_done<=0;frame_cycles<=0;compute_frames<=0;
        end else begin
            frame_done<=0;
            if(start_fire) begin frame_active<=1;pixel_index<=0;ticks<=0;end
            else if(frame_active) ticks<=ticks+1;
            if(m_valid && m_ready) begin
                if(m_last) begin
                    frame_active<=0;
                    frame_done<=1;
                    frame_cycles<=ticks+1;
                    compute_frames<=compute_frames+1;
                end else pixel_index<=pixel_index+1;
            end
        end
    end
endmodule
