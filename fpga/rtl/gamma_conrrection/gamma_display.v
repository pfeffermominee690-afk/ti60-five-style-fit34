// Four-stage display correction: shadow lift/highlight shoulder, saturation 1.125.
// RGB and DE/HS/VS have identical latency. This project uses DATA_WIDTH=8.
module gamma_correction #(
    parameter DATA_WIDTH = 8,
    parameter GAMMA_CURVE = "./rtl/gamma_conrrection/display_balanced.mem"
)(
    input i_pclk, i_rstn, i_valid, i_hs, i_vs,
    input [DATA_WIDTH-1:0] i_red, i_green, i_blue,
    output reg [DATA_WIDTH-1:0] o_red, o_green, o_blue,
    output o_valid, o_hs, o_vs
);
    reg [7:0] curve [0:255];
    initial $readmemh(GAMMA_CURVE, curve);
    reg [7:0] r1, g1, b1, r2, g2, b2, y2;
    reg signed [12:0] r3, g3, b3;
    reg [3:0] de_pipe, hs_pipe, vs_pipe;
    assign o_valid = de_pipe[3];
    assign o_hs = hs_pipe[3];
    assign o_vs = vs_pipe[3];
    function [7:0] clamp_scaled;
        input signed [12:0] value;
        begin
            if (value < 0) clamp_scaled = 0;
            else if (value > 1880) clamp_scaled = 235;
            else clamp_scaled = value[10:3];
        end
    endfunction
    always @(posedge i_pclk) begin
        if (!i_rstn) begin
            r1 <= 0; g1 <= 0; b1 <= 0;
            r2 <= 0; g2 <= 0; b2 <= 0; y2 <= 0;
            r3 <= 0; g3 <= 0; b3 <= 0;
            o_red <= 0; o_green <= 0; o_blue <= 0;
            de_pipe <= 0; hs_pipe <= 0; vs_pipe <= 0;
        end else begin
            de_pipe <= {de_pipe[2:0], i_valid};
            hs_pipe <= {hs_pipe[2:0], i_hs};
            vs_pipe <= {vs_pipe[2:0], i_vs};
            r1 <= curve[i_red]; g1 <= curve[i_green]; b1 <= curve[i_blue];
            r2 <= r1; g2 <= g1; b2 <= b1;
            // Symmetric red/blue weighting preserves the board's BGR order.
            y2 <= ({2'b0,r1} + {1'b0,g1,1'b0} + {2'b0,b1}) >> 2;
            r3 <= $signed({2'b0,r2,3'b0}) + $signed({5'b0,r2}) - $signed({5'b0,y2});
            g3 <= $signed({2'b0,g2,3'b0}) + $signed({5'b0,g2}) - $signed({5'b0,y2});
            b3 <= $signed({2'b0,b2,3'b0}) + $signed({5'b0,b2}) - $signed({5'b0,y2});
            o_red <= de_pipe[2] ? clamp_scaled(r3) : 0;
            o_green <= de_pipe[2] ? clamp_scaled(g3) : 0;
            o_blue <= de_pipe[2] ? clamp_scaled(b3) : 0;
        end
    end
endmodule
