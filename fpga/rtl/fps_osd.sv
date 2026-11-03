// One-pixel-per-clock, two-register-stage overlay for a video RGB stream.
// All inputs must be in clk domain. fps_bcd must come from measured completed
// frames (or a CPU register). This candidate receives user-requested 3x scaled
// display values; the label is unchanged. Do not use OSD for performance reports.
// frame_start is a one-cycle pulse before the visible overlay region.
module fps_osd #(
    parameter X0=16, Y0=16, ROTATE_180=0, FRAME_WIDTH=1280, FRAME_HEIGHT=720
)(
    input wire clk,rst_n,frame_start,
    input wire [11:0] x,y,
    input wire de,hs,vs,
    input wire [23:0] rgb,
    input wire [11:0] fps_bcd,
    input wire fps_valid,
    input wire [2:0] style_id,
    output reg out_de,out_hs,out_vs,
    output reg [23:0] out_rgb
);
    // Rotate only the overlay sampling coordinates. Video sync and the
    // unmodified input coordinates still define the physical raster/frame start.
    wire [11:0] display_x=ROTATE_180 ? (FRAME_WIDTH-1-x) : x;
    wire [11:0] display_y=ROTATE_180 ? (FRAME_HEIGHT-1-y) : y;
    reg [11:0] shown_bcd;
    reg shown_valid;
    reg [2:0] shown_style;
    wire original_label=(display_x>=16 && display_x<80 && display_y>=48 && display_y<80);
    wire style_label=(display_x>=656 && display_x<912 && display_y>=16 && display_y<48 && shown_style>=1 && shown_style<=5);
    wire label_panel=original_label || style_label;
    wire [11:0] label_x=original_label ? (display_x-12'd16) : (display_x-12'd656);
    wire [11:0] label_y=original_label ? (display_y-12'd48) : (display_y-12'd16);
    wire [2:0] label_id=original_label ? 3'd0 : shown_style;
    reg title_font [0:16383];
    initial $readmemh("title-font.hex",title_font);
    reg title_ink_q;
    always @(posedge clk) title_ink_q<=title_font[{label_id,label_y[4:1],label_x[7:1]}];
    reg label_panel_q,de_q,hs_q,vs_q;
    reg [23:0] rgb_q;

    reg [34:0] glyph;
    reg [7:0] ch;
    integer dx,dy,character,column,row;
    reg in_panel,ink;
    function automatic [34:0] font(input [7:0] c);
      begin
        case(c)
          "F":font={5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000};
          "P":font={5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000};
          "S":font={5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110};
          "0":font={5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110};
          "1":font={5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110};
          "2":font={5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111};
          "3":font={5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110};
          "4":font={5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010};
          "5":font={5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110};
          "6":font={5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110};
          "7":font={5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000};
          "8":font={5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110};
          "9":font={5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110};
          "-":font={5'b00000,5'b00000,5'b00000,5'b11111,5'b00000,5'b00000,5'b00000};
          default:font=0;
        endcase
      end
    endfunction
    function automatic [7:0] digit(input [3:0] d);
      digit=d<=9 ? 8'd48+{4'd0,d} : "-";
    endfunction
    always @* begin
      dx=0;dy=0;character=0;column=0;row=0;ch=" ";glyph=0;ink=0;
      in_panel=(display_x>=X0 && display_x<X0+84 && display_y>=Y0 && display_y<Y0+14);
      if(in_panel) begin
        dx=(display_x-X0)>>1;dy=(display_y-Y0)>>1;
        // Constant compare/subtract avoids a synthesized divider for /6.
        if(dx<6) begin character=0;column=dx;end
        else if(dx<12) begin character=1;column=dx-6;end
        else if(dx<18) begin character=2;column=dx-12;end
        else if(dx<24) begin character=3;column=dx-18;end
        else if(dx<30) begin character=4;column=dx-24;end
        else if(dx<36) begin character=5;column=dx-30;end
        else begin character=6;column=dx-36;end
        row=dy;
        case(character)
          0:ch="F";
          1:ch="P";
          2:ch="S";
          4:ch=shown_valid?digit(shown_bcd[11:8]):"-";
          5:ch=shown_valid?digit(shown_bcd[7:4]):"-";
          6:ch=shown_valid?digit(shown_bcd[3:0]):"-";
          default:ch=" ";
        endcase
        glyph=font(ch);
        if(column<5) ink=glyph[34-row*5-column];
      end
    end
    always @(posedge clk) begin
      if(!rst_n) begin
        shown_bcd<=0;shown_valid<=0;shown_style<=0;
        out_de<=0;out_hs<=0;out_vs<=0;out_rgb<=0;
        de_q<=0;hs_q<=0;vs_q<=0;rgb_q<=0;label_panel_q<=0;
      end else begin
        if(frame_start) begin shown_bcd<=fps_bcd;shown_valid<=fps_valid;end
        if(de && x==0 && y==0)shown_style<=style_id;
        de_q<=de;hs_q<=hs;vs_q<=vs;label_panel_q<=de && label_panel && !in_panel;
        if(de && in_panel)
          rgb_q<=ink?24'hffffff:{2'b0,rgb[23:18],2'b0,rgb[15:10],2'b0,rgb[7:2]};
        else rgb_q<=rgb;
        out_de<=de_q;out_hs<=hs_q;out_vs<=vs_q;
        if(label_panel_q)out_rgb<=title_ink_q?24'hffffff:{2'b0,rgb_q[23:18],2'b0,rgb_q[15:10],2'b0,rgb_q[7:2]};
        else out_rgb<=rgb_q;
      end
    end
endmodule
