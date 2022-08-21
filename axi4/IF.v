`include "lib/defines.vh"
module IF(
    input wire clk,
    input wire rst,
    input wire [`STALLBUS_WD-1:0] stall,

    input wire flush,
    input wire [31:0] new_pc,

    input wire [`BR_WD-1:0] br_bus,

    output wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    output wire inst_sram_en,
    output wire [3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata
);

    reg ce_reg; // 取址使能
    reg re_reg; // 接收使能
    reg [31:0] pc_reg;  // 访存pc 8字节对齐
    reg [31:0] pc_idef; // 要接受的准确pc

    wire br_e;
    wire [31:0] next_pc;
    wire [31:0] br_addr;

    assign {
        br_e,
        br_addr
    } = br_bus;

    always @ (posedge clk) begin
        if (rst) begin
            pc_reg  <= 32'hbfbf_fff8;
            pc_idef <= 32'hbfbf_fff8;
        end
        else if (stall[0]==`NoStop) begin
            pc_reg  <= {next_pc[31:3],3'b0};
            pc_idef <= next_pc;
        end
    end

    always @ (posedge clk) begin
        if (rst) begin
            ce_reg <= 1'b0;
        end
        else if (stall[0]==`NoStop) begin
            ce_reg <= 1'b1;
        end
    end

    always @ (*) begin
        if (rst | stall[0]==`Stop) begin
            re_reg <= 1'b0;
        end
        else if (stall[0]==`NoStop & ~br_e) begin
            re_reg <= 1'b1;
        end
        else begin
            re_reg <= 1'b0;
        end
    end

    assign next_pc = flush ? new_pc  :
                     br_e  ? br_addr : pc_reg + 32'd8;

    assign if_to_id_bus = {
        re_reg,
        pc_idef,
        pc_reg
    };

    assign inst_sram_en    = ce_reg;
    assign inst_sram_wen   = 4'b0;
    assign inst_sram_addr  = pc_reg;
    assign inst_sram_wdata = 32'b0;

endmodule