`include "lib/defines.vh"
`define STAGE_WIDTH 12
module axi_ctrl(
    input wire clk,
    input wire resetn,

    input wire ird_req,
    input wire [31:0] ird_addr,
    output reg i_reload,
    output reg [511:0] icacheline_new, 

    input wire drd_req,
    input wire [31:0] drd_addr,
    output reg d_reload,
    output reg [255:0] dcacheline_new,
    input wire dwr_req,
    input wire [31:0] dwr_addr,
    input wire [255:0] dcacheline_old,

    input wire unrd_req,
    input wire [31:0] unrd_addr,
    input wire unwr_req,
    input wire [3:0] unwr_wstrb,
    input wire [31:0] unwr_addr,
    input wire [31:0] unwr_data,
    output reg un_reload,
    output reg [31:0] unrd_data,

    //总线侧接口
    //读地址通道信号
    output reg [3:0]	    arid,//读地址ID，用来标志一组写信号
    output reg [31:0]	    araddr,//读地址，给出一次写突发传输的读地址
    output reg [3:0]	    arlen,//突发长度，给出突发传输的次数
    output reg [2:0]	    arsize,//突发大小，给出每次突发传输的字节数
    output reg [1:0]	    arburst,//突发类型
    output reg [1:0]	    arlock,//总线锁信号，可提供操作的原子性
    output reg [3:0]	    arcache,//内存类型，表明一次传输是怎样通过系统的
    output reg [2:0]	    arprot,//保护类型，表明一次传输的特权级及安全等级
    output reg 		        arvalid,//有效信号，表明此通道的地址控制信号有效
    input  wire		        arready,//表明"从"可以接收地址和对应的控制信号
    //读数据通道信号
    input  wire [3:0]	    rid,//读ID tag
    input  wire [31:0]	    rdata,//读数据
    input  wire [1:0]	    rresp,//读响应，表明读传输的状态
    input  wire		        rlast,//表明读突发的最后一次传输
    input  wire		        rvalid,//表明此通道信号有效
    output reg		        rready,//表明主机能够接收读数据和响应信息

    //写地址通道信号
    output reg [3:0]	    awid,//写地址ID，用来标志一组写信号
    output reg [31:0]	    awaddr,//写地址，给出一次写突发传输的写地址
    output reg [3:0]	    awlen,//突发长度，给出突发传输的次数
    output reg [2:0]	    awsize,//突发大小，给出每次突发传输的字节数
    output reg [1:0]	    awburst,//突发类型
    output reg [1:0]	    awlock,//总线锁信号，可提供操作的原子性
    output reg [3:0]	    awcache,//内存类型，表明一次传输是怎样通过系统的
    output reg [2:0]	    awprot,//保护类型，表明一次传输的特权级及安全等级
    output reg 		        awvalid,//有效信号，表明此通道的地址控制信号有效
    input  wire		        awready,//表明"从"可以接收地址和对应的控制信号

    //写数据通道信号
    output reg [3:0]	    wid,//一次写传输的ID tag
    output reg [31:0]	    wdata,//写数据
    output reg [3:0]	    wstrb,//写数据有效的字节线，用来表明哪8bits数据是有效的
    output reg 		        wlast,//表明此次传输是最后一个突发传输
    output reg		        wvalid,//写有效，表明此次写有效
    input  wire		        wready,//表明从机可以接收写数据
    //写响应通道信号
    input  wire [3:0]	    bid,//写响应ID tag
    input  wire [1:0]	    bresp,//写响应，表明写传输的状态 00为正常，当然可以不理会
    input  wire		        bvalid,//写响应有效
    output reg		        bready//表明主机能够接收写响应
);
    reg [`STAGE_WIDTH-1:0] stage;
    reg [`STAGE_WIDTH-1:0] stage_w;

    reg [3:0] icache_offset;
    reg [3:0] dcache_offset;
    reg [3:0] dcache_offset_w;

    reg ird_req_r, drd_req_r, unrd_req_r;
    reg dwr_req_r, unwr_req_r;

    always @ (posedge clk) begin
        if (!resetn) begin
            arid <= 4'b0000;
            araddr <= `ZeroWord;
            arlen <= 4'b0000;
            arsize <= 3'b010;
            arburst <= 2'b01;
            arlock <= 2'b00;
            arcache <= 4'b0000;
            arprot <= 3'b000;
            arvalid <= 1'b0;

            rready <= 1'b0;

            stage <= `STAGE_WIDTH'b1;

            ird_req_r <= 1'b0;
            drd_req_r <= 1'b0;
            unrd_req_r <= 1'b0;
            dwr_req_r <= 1'b0;
            unwr_req_r <= 1'b0;

            i_reload <= 1'b0;
            d_reload <= 1'b0;
            un_reload <= 1'b0;
            icacheline_new <= 512'b0;
            dcacheline_new <= 255'b0;
            unrd_data <= 32'b0;
        end
        else begin
            case (1'b1)
                stage[0]:begin
                    i_reload <= 1'b0;
                    d_reload <= 1'b0;
                    un_reload <= 1'b0;
                    
                    ird_req_r <= ird_req;
                    drd_req_r <= drd_req;
                    unrd_req_r <= unrd_req;
                    dwr_req_r <= dwr_req;
                    unwr_req_r <= unwr_req;
                    if (dwr_req|unwr_req) begin
                        stage <= stage << 1;
                    end
                    else if (ird_req) begin
                        stage <= stage << 2;
                    end
                    else if (drd_req|unrd_req) begin
                        stage <= stage << 5; 
                    end
                end
                stage[1]:begin
                    if (ird_req_r) begin
                        stage <= stage << 1; 
                    end
                    else if (drd_req_r|unrd_req_r) begin
                        stage <= stage << 4;
                    end
                    else begin
                        stage <= {1'b0,1'b1,10'b0};
                    end
                end
                stage[2]:begin
                    if (ird_req_r) begin
                        arid <= 4'b0;
                        araddr <= ird_addr;
                        arlen <= 4'hf;
                        arsize <= 3'b010;
                        arvalid <= 1'b1;

                        stage <= stage << 1;
                    end
                end
                stage[3]:begin
                    if (arready) begin
                        arvalid <= 1'b0;
                        araddr <= 32'b0;
                        rready <= 1'b1;
                        icache_offset <= 4'd0;
                        stage <= stage << 1;
                    end
                end
                stage[4]:begin
                    if (!rlast & rvalid) begin
                        icacheline_new[icache_offset*32+:32] <= rdata;
                        icache_offset <= icache_offset + 1'b1;
                    end
                    else if (rlast) begin
                        icacheline_new[icache_offset*32+:32] <= rdata;
                        rready <= 1'b0;
                        if (drd_req|unrd_req) begin
                            stage <= stage << 1;    
                        end
                        else begin
                            stage <= {1'b0,1'b1,10'b0};
                        end
                    end
                end
                stage[5]:begin
                    if (drd_req_r) begin
                        arid <= 4'b1;
                        araddr <= drd_addr;
                        arlen <= 4'h7;
                        arsize <= 3'b010;
                        arvalid <= 1'b1;
                        
                        stage <= stage << 1;
                    end
                    else if (unrd_req_r) begin
                        arid <= 4'd2;
                        araddr <= unrd_addr;
                        arlen <= 4'b0;
                        arsize <= 3'b010;
                        arvalid <= 1'b1;
                        stage <= stage << 3;
                    end
                    else begin
                        stage <= {1'b0,1'b1,10'b0};
                    end
                end
                stage[6]:begin
                    if (arready) begin
                        arvalid <= 1'b0;
                        araddr <= 32'b0;
                        rready <= 1'b1;
                        dcache_offset <= 4'd0;
                        stage <= stage << 1;
                    end
                end
                stage[7]:begin
                    if (!rlast & rvalid) begin
                        dcacheline_new[dcache_offset*32+:32] <= rdata;
                        dcache_offset <= dcache_offset + 1'b1;
                    end
                    else if (rlast) begin
                        dcacheline_new[dcache_offset*32+:32] <= rdata;
                        rready <= 1'b0;
                        stage <= {1'b0,1'b1,10'b0};
                    end
                end
                stage[8]:begin
                    if (arready) begin
                        arvalid <= 1'b0;
                        araddr <= 32'b0;
                        rready <= 1'b1;
                        stage <= stage << 1;
                    end
                end
                stage[9]:begin
                    if (rlast & rvalid) begin
                        unrd_data <= rdata;
                        rready <= 1'b0;
                        stage <= {1'b0,1'b1,10'b0};
                    end
                end
                stage[10]:begin
                    if (stage_w[10]|stage_w[0]) begin
                        stage <= stage << 1;
                    end
                end
                stage[11]:begin
                    if (ird_req_r) begin
                        i_reload <= 1'b1;
                    end
                    if (drd_req_r) begin
                        d_reload <= 1'b1;
                    end
                    if (unrd_req_r|unwr_req_r) begin
                        un_reload <= 1'b1;
                    end
                    stage <= 0;
                end
                default:begin
                    stage <= 1;
                    i_reload <= 1'b0;
                    d_reload <= 1'b0;
                    un_reload <= 1'b0;
                end
            endcase
        end
    end

    always @ (posedge clk) begin
        if (!resetn) begin
            awid <= 4'b0001;
            awaddr <= `ZeroWord;
            awlen <= 4'b0000;
            awsize <= 3'b010;
            awburst <= 2'b01;
            awlock <= 2'b00;
            awcache <= 4'b0000;
            awprot <= 3'b000;
            awvalid <= 1'b0;

            wid <= 4'b0001;
            wdata <= `ZeroWord;
            wstrb <= 4'b0000;
            wlast <= 1'b0;
            wvalid <= 1'b0;

            bready <= 1'b0;

            stage_w <= `STAGE_WIDTH'b1;
            dcache_offset_w <= 4'b0;
        end
        else begin
            case (1'b1) 
                stage_w[0]:begin
                    if (stage[1]) begin
                        if (dwr_req_r) begin
                            awid <= 4'b1;
                            awaddr <= dwr_addr;
                            awlen <= 4'h7;
                            awsize <= 3'b010;
                            awvalid <= 1'b1;
                            wstrb <= 4'b1111;
                            wlast <= 1'b0;
                            bready <= 1'b1;
                            dcache_offset_w <= 4'b0;
                            stage_w <= stage_w << 1;
                        end
                        else if (unwr_req_r) begin
                            awid <= 4'd2;
                            awaddr <= unwr_addr;
                            awlen <= 4'b0;
                            case (unwr_wstrb)
                                4'b0001,4'b0010,4'b0100,4'b1000:begin
                                    awsize <= 3'b000;
                                    wstrb <= unwr_wstrb;
                                end
                                4'b0011,4'b1100:begin
                                    awsize <= 3'b001;
                                    wstrb <= unwr_wstrb;
                                end
                                4'b1111:begin
                                    awsize <= 3'b010;
                                    wstrb <= unwr_wstrb;
                                end
                                default:begin
                                    awsize <= 3'b010;
                                    wstrb <= unwr_wstrb;
                                end
                            endcase  
                            awvalid <= 1'b1;
                            wlast <= 1'b0;
                            bready <= 1'b1;
                            stage_w <= stage_w << 4;
                        end
                    end
                end
                stage_w[1]:begin
                    if (awready) begin
                        awvalid <= 1'b0;
                        awaddr <= 32'b0;
                    end
                    if (wready) begin
                        wdata <= dcacheline_old[dcache_offset_w*32+:32];
                        wvalid <= 1'b1;
                        wlast <= dcache_offset_w==4'b0111 ? 1'b1 : 1'b0;
                        dcache_offset_w <= dcache_offset_w + 1'b1;
                        if (dcache_offset_w == 4'b0111) begin
                            stage_w <= stage_w << 1;
                        end
                    end
                end
                stage_w[2]:begin
                    if (wready) begin
                        wdata <= 32'b0;
                        wvalid <= 1'b0;    
                        wlast <= 1'b0;
                        stage_w <= stage_w << 1;
                    end
                end
                stage_w[3]:begin
                    if (bvalid) begin
                        bready <= 1'b0;
                        stage_w <= {1'b0,1'b1,{10{1'b0}}};
                    end
                end
                stage_w[4]:begin
                    if (awready) begin
                        awvalid <= 1'b0;
                        awaddr <= 32'b0;
                        wdata <= unwr_data;
                        wvalid <= 1'b1;
                        wlast <= 1'b1;
                        stage_w <= stage_w << 1;
                    end
                end
                stage_w[5]:begin
                    if (wready) begin
                        wdata <= 32'b0;
                        wvalid <= 1'b0;
                        wlast <= 1'b0;
                        stage_w <= stage_w << 1;
                    end
                end
                stage_w[6]:begin
                    if (bvalid) begin
                        bready <= 1'b0;
                        stage_w <= {1'b0,1'b1,{10{1'b0}}};
                    end
                end
                stage_w[10]:begin
                    if (stage[11]) begin
                        stage_w <= `STAGE_WIDTH'b1;
                    end
                end
                default:begin
                    stage_w <= `STAGE_WIDTH'b1;
                end
            endcase
        end
    end

endmodule