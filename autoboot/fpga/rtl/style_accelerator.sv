// Same-clock APB3 control + CNN + AXI32 DMA. No CDC implied by this wrapper.
// AXI sidebands are INCR, 4-byte beats, ID=0, non-cacheable, non-exclusive.
module style_accelerator #(parameter WIDTH=640,HEIGHT=480,CLOCK_HZ=100000000)(
    input wire clk,rst_n,
    input wire [15:0] paddr,input wire psel,penable,pwrite,
    input wire [31:0] pwdata,output reg [31:0] prdata,
    output wire pready,output wire pslverror,output wire irq,
    output wire [31:0] completed_frames,
    output wire [31:0] araddr,output wire [7:0] arlen,
    output wire arvalid,input wire arready,
    input wire [31:0] rdata,input wire [1:0] rresp,
    input wire rlast,rvalid,output wire rready,
    output wire [31:0] awaddr,output wire [7:0] awlen,
    output wire awvalid,input wire awready,
    output wire [31:0] wdata,output wire [3:0] wstrb,
    output wire wlast,wvalid,input wire wready,
    input wire [1:0] bresp,input wire bvalid,output wire bready
);
    localparam [32:0] FRAME_BYTES=WIDTH*HEIGHT*4;
    reg [31:0] src,dst,job_id,active_job,completed_job;
    reg completed,recover;
    wire dma_ready,busy,dma_done,core_ready,model_valid,cfg_ready;
    wire [31:0] error,cycles,frames,read_pixels,written_pixels;
    assign completed_frames=frames;
    wire si_valid,si_ready,so_valid,so_ready;
    wire [23:0] si_rgb,so_rgb;
    wire cnn_ready,facet_ready,nn_valid,nn_ready;
    wire [23:0] nn_rgb;
    assign core_ready=cnn_ready && facet_ready;
    wire access=psel && penable;
    wire param_access=paddr>=16'h400 && paddr<16'h800;
    wire [7:0] index=paddr[9:2];
    wire param_index_valid=index<108 || (index>=128 && index<132) ||
        (index>=136 && index<144) || (index>=160 && index<172) ||
        (index>=176 && index<179) || index==255;
    wire [32:0] src_end={1'b0,src}+FRAME_BYTES,dst_end={1'b0,dst}+FRAME_BYTES;
    wire addresses_ok=src[1:0]==0 && dst[1:0]==0 && !src_end[32] && !dst_end[32] &&
        (src_end<={1'b0,dst} || dst_end<={1'b0,src});
    reg invalid;
    always @* begin
        invalid=0;prdata=0;
        if(paddr[1:0]!=0) invalid=1;
        else if(param_access) begin
            if(!pwrite || !param_index_valid || busy || dma_done || !cfg_ready || recover) invalid=1;
        end else begin
            case(paddr)
                16'h00:begin prdata=32'h53545931;if(pwrite) invalid=1;end
                16'h04:if(pwrite) begin
                    if((pwdata & ~32'h3)!=0 ||
                       (pwdata[0] && (!dma_ready || !core_ready || !addresses_ok || dma_done || recover))) invalid=1;
                end
                16'h08:begin prdata={28'b0,model_valid,(error!=0),completed,(busy || dma_done || recover)};if(pwrite) invalid=1;end
                16'h0c:begin prdata=src;if(pwrite && busy) invalid=1;end
                16'h10:begin prdata=dst;if(pwrite && busy) invalid=1;end
                16'h14:begin prdata=job_id;if(pwrite && busy) invalid=1;end
                16'h18:begin prdata=completed_job;if(pwrite) invalid=1;end
                16'h1c:begin prdata=frames;if(pwrite) invalid=1;end
                16'h20:begin prdata=cycles;if(pwrite) invalid=1;end
                16'h24:begin prdata=error;if(pwrite) invalid=1;end
                16'h28:begin prdata=read_pixels;if(pwrite) invalid=1;end
                16'h2c:begin prdata=written_pixels;if(pwrite) invalid=1;end
                16'h30:begin prdata=WIDTH;if(pwrite) invalid=1;end
                16'h34:begin prdata=HEIGHT;if(pwrite) invalid=1;end
                16'h38:begin prdata=CLOCK_HZ;if(pwrite) invalid=1;end
                default:invalid=1;
            endcase
        end
    end
    assign pready=1'b1;
    assign pslverror=access && invalid;
    wire write_fire=access && pwrite && !invalid;
    // Keep CFG independent of start validation: core_ready itself includes
    // !cfg_valid. Feeding CFG from write_fire would create a structural loop
    // through invalid -> write_fire -> core_ready -> invalid in synthesis.
    wire config_fire=access && pwrite && param_access && paddr[1:0]==0 &&
        param_index_valid && !busy && !dma_done && !recover && cfg_ready;
    wire launch=write_fire && paddr==16'h04 && pwdata[0];
    assign irq=completed;
    always @(posedge clk) begin
        if(!rst_n) begin
            src<=0;dst<=0;job_id<=0;active_job<=0;completed_job<=0;completed<=0;recover<=0;
        end else begin
            recover<=0;
            if(write_fire) case(paddr)
                16'h04:if(pwdata[1]) completed<=0;
                16'h0c:src<=pwdata;
                16'h10:dst<=pwdata;
                16'h14:job_id<=pwdata;
                default:;
            endcase
            if(launch) begin completed<=0;active_job<=job_id;end
            if(dma_done) begin
                completed<=1;completed_job<=active_job;
                // Drain bus first, then reset the aborted CNN. Reload weights after error.
                if(error!=0) recover<=1;
            end
        end
    end
    cnn_stream_q8 #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) core(
        .clk(clk),.rst_n(rst_n && !recover),.start(launch),.start_ready(cnn_ready),
        .cfg_valid(config_fire),.cfg_ready(cfg_ready),.cfg_addr(index),.cfg_data(pwdata),
        .model_valid(model_valid),.s_valid(si_valid),.s_ready(si_ready),.s_rgb(si_rgb),
        .m_valid(nn_valid),.m_ready(nn_ready),.m_rgb(nn_rgb),.m_last(),
        .frame_done(),.frame_cycles(),.compute_frames());
    lowpoly_stream #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.BLOCK(16)) facets(
        .clk(clk),.rst_n(rst_n && !recover),.start(launch),.start_ready(facet_ready),
        .s_valid(nn_valid),.s_ready(nn_ready),.s_rgb(nn_rgb),
        .m_valid(so_valid),.m_ready(so_ready),.m_rgb(so_rgb),.m_last(),.done(),.busy());
    rgb_frame_dma #(.PIXELS(WIDTH*HEIGHT)) dma(
        .clk(clk),.rst_n(rst_n),.start(launch),.src_addr(src),.dst_addr(dst),.start_ready(dma_ready),
        .busy(busy),.done(dma_done),.error(error),.cycles(cycles),.frames(frames),
        .read_pixels(read_pixels),.written_pixels(written_pixels),
        .s_valid(si_valid),.s_ready(si_ready),.s_rgb(si_rgb),.m_valid(so_valid),.m_ready(so_ready),.m_rgb(so_rgb),
        .araddr(araddr),.arlen(arlen),.arvalid(arvalid),.arready(arready),
        .rdata(rdata),.rresp(rresp),.rlast(rlast),.rvalid(rvalid),.rready(rready),
        .awaddr(awaddr),.awlen(awlen),.awvalid(awvalid),.awready(awready),
        .wdata(wdata),.wstrb(wstrb),.wlast(wlast),.wvalid(wvalid),.wready(wready),
        .bresp(bresp),.bvalid(bvalid),.bready(bready));
endmodule
