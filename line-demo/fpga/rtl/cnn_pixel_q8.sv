// V1-CNN-4-Q8: 3x3 RGB->4, affine BN/ReLU, 1x1 4->RGB.
// Window bytes are spatial HWI order, earliest byte at bits [7:0].
// Runtime configuration is allowed only while idle; commit address 255 last.
module cnn_pixel_q8 (
    input wire clk, rst_n,
    input wire cfg_valid,
    output wire cfg_ready,
    input wire [7:0] cfg_addr,
    input wire [31:0] cfg_data,
    output reg model_valid,
    input wire s_valid,
    output wire s_ready,
    input wire [215:0] s_window,
    output reg m_valid,
    input wire m_ready,
    output reg [23:0] m_rgb,
    output wire busy,
    output reg [31:0] pixels_done
);
    localparam IDLE=0, MAC=1;
    reg [2:0] state;
    reg [215:0] window_reg;
    // w1 bank order: output*27 + (ky*3+kx)*3+input_channel.
    reg signed [15:0] w1[0:107], w2[0:11], alpha[0:3];
    reg signed [31:0] bias1[0:3], beta[0:3], bias2[0:2];
    reg signed [24:0] products[0:3][0:3];
    reg signed [39:0] accum[0:3];
    reg signed [31:0] conv_q[0:3];
    reg signed [55:0] bn_product[0:3];
    reg [7:0] hidden[0:3];
    reg signed [24:0] pw_product[0:2][0:3];
    reg [3:0] group_index;
    reg product_valid, product_last;
    reg [3:0] post_valid;
    // A common stall preserves both partial MACs and every backend register.
    // The next 3x3 convolution overlaps BN/ReLU/pointwise of the previous pixel.
    wire advance=!m_valid || m_ready;
    integer o, t, tap;
    reg signed [39:0] total;
    reg signed [55:0] bn_total;
    assign busy = (state != IDLE) || (|post_valid) || m_valid;
    assign cfg_ready = !busy;
    assign s_ready = model_valid && state==IDLE && advance && !cfg_valid;

    function automatic signed [39:0] sx25(input signed [24:0] value);
        sx25 = {{15{value[24]}},value};
    endfunction
    function automatic signed [39:0] sx32(input signed [31:0] value);
        sx32 = {{8{value[31]}},value};
    endfunction
    function automatic [7:0] quant_u8(input signed [55:0] value);
        reg signed [55:0] shifted;
        begin
            shifted = (value + 56'sd128) >>> 8;
            if (shifted < 0) quant_u8 = 0;
            else if (shifted > 255) quant_u8 = 255;
            else quant_u8 = shifted[7:0];
        end
    endfunction

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            model_valid <= 0;
            m_valid <= 0;
            m_rgb <= 0;
            product_valid <= 0;
            product_last <= 0;
            group_index <= 0;
            post_valid <= 0;
            pixels_done <= 0;
        end else begin
            if (m_valid && m_ready) begin
                m_valid <= 0;
                pixels_done <= pixels_done + 1;
            end
            if (cfg_valid && cfg_ready) begin
                if (cfg_addr == 255) model_valid <= cfg_data[0];
                else begin
                    model_valid <= 0;
                    if (cfg_addr < 108) w1[cfg_addr] <= cfg_data[15:0];
                    else if (cfg_addr >= 128 && cfg_addr < 132) bias1[cfg_addr-128] <= cfg_data;
                    else if (cfg_addr >= 136 && cfg_addr < 140) alpha[cfg_addr-136] <= cfg_data[15:0];
                    else if (cfg_addr >= 140 && cfg_addr < 144) beta[cfg_addr-140] <= cfg_data;
                    else if (cfg_addr >= 160 && cfg_addr < 172) w2[cfg_addr-160] <= cfg_data[15:0];
                    else if (cfg_addr >= 176 && cfg_addr < 179) bias2[cfg_addr-176] <= cfg_data;
                end
            end
            if(advance) begin
            post_valid <= {post_valid[2:0],1'b0};
            m_valid <= post_valid[3];
            if(post_valid[0])
                for(o=0;o<4;o=o+1) bn_product[o]<=conv_q[o]*alpha[o];
            if(post_valid[1])
                for(o=0;o<4;o=o+1) begin
                    bn_total=bn_product[o]+{{24{beta[o][31]}},beta[o]};
                    hidden[o]<=quant_u8(bn_total);
                end
            if(post_valid[2])
                for(o=0;o<3;o=o+1)
                    for(t=0;t<4;t=t+1)
                        pw_product[o][t]<=$signed({1'b0,hidden[t]})*w2[o*4+t];
            if(post_valid[3])
                for(o=0;o<3;o=o+1) begin
                    total=sx32(bias2[o])+sx25(pw_product[o][0])+sx25(pw_product[o][1])
                        +sx25(pw_product[o][2])+sx25(pw_product[o][3]);
                    m_rgb[o*8+:8]<=quant_u8({{16{total[39]}},total});
                end
            case (state)
                IDLE: if (s_valid && s_ready) begin
                    window_reg <= s_window;
                    for (o=0;o<4;o=o+1) accum[o] <= sx32(bias1[o]);
                    group_index <= 0;
                    product_valid <= 0;
                    product_last <= 0;
                    state <= MAC;
                end
                MAC: begin
                    product_valid <= group_index < 7;
                    product_last <= group_index == 6;
                    if (group_index < 7) begin
                        for (o=0;o<4;o=o+1) begin
                            for (t=0;t<4;t=t+1) begin
                                tap = group_index*4+t;
                                if (tap < 27)
                                    products[o][t] <= $signed({1'b0,window_reg[tap*8+:8]}) * w1[o*27+tap];
                                else products[o][t] <= 0;
                            end
                        end
                        group_index <= group_index+1;
                    end
                    if (product_valid) begin
                        for (o=0;o<4;o=o+1) begin
                            total = accum[o]+sx25(products[o][0])+sx25(products[o][1])
                                           +sx25(products[o][2])+sx25(products[o][3]);
                            accum[o] <= total;
                            if (product_last) conv_q[o] <= (total + 40'sd128) >>> 8;
                        end
                        if (product_last) begin state<=IDLE;post_valid[0]<=1;end
                    end
                end
                default: state <= IDLE;
            endcase
            end
        end
    end
endmodule
