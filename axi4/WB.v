`include "lib/defines.vh"
module WB(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`STALLBUS_WD-1:0] stall,

    input wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,

    output wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,

    output wire [31:0] debug_wb_pc,
    output wire [3:0]  debug_wb_rf_wen,
    output wire [4:0]  debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata 
);

    reg [`MEM_TO_WB_WD-1:0] mem_to_wb_bus_r;
    
    reg [31:0] debug_wb_pc_r;
    reg [3:0]  debug_wb_rf_wen_r;
    reg [4:0]  debug_wb_rf_wnum_r;
    reg [31:0] debug_wb_rf_wdata_r;

    wire [31:0] wb_pc_i1, wb_pc_i2;
    wire rf_we_i1, rf_we_i2;
    wire [4:0] rf_waddr_i1, rf_waddr_i2;
    wire [31:0] rf_wdata_i1, rf_wdata_i2;
    wire [`HILO_WD-1:0] hilo_bus_i1, hilo_bus_i2;

    always @ (posedge clk) begin
        if (rst) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        end
        else if (stall[6]==`Stop) begin
            mem_to_wb_bus_r <= `MEM_TO_WB_WD'b0;
        end
        else if (stall[6]==`NoStop) begin
            mem_to_wb_bus_r <= mem_to_wb_bus;
        end
    end

    assign {
        hilo_bus_i2,
        wb_pc_i2,
        rf_we_i2,
        rf_waddr_i2,
        rf_wdata_i2,
        hilo_bus_i1,
        wb_pc_i1,
        rf_we_i1,
        rf_waddr_i1,
        rf_wdata_i1
    } = mem_to_wb_bus_r;

    assign wb_to_rf_bus = {
        hilo_bus_i2,
        rf_we_i2,
        rf_waddr_i2,
        rf_wdata_i2,
        hilo_bus_i1,
        rf_we_i1,
        rf_waddr_i1,
        rf_wdata_i1
    };
    
//debug output

    always @ (posedge clk or negedge clk) begin
        #2
        debug_wb_pc_r       <= clk ? wb_pc_i1      : wb_pc_i2;
        debug_wb_rf_wen_r   <= clk ? {4{rf_we_i1}} : {4{rf_we_i2}};
        debug_wb_rf_wnum_r  <= clk ? rf_waddr_i1   : rf_waddr_i2;
        debug_wb_rf_wdata_r <= clk ? rf_wdata_i1   : rf_wdata_i2;
    end

    assign debug_wb_pc       = debug_wb_pc_r;
    assign debug_wb_rf_wen   = debug_wb_rf_wen_r;
    assign debug_wb_rf_wnum  = debug_wb_rf_wnum_r;
    assign debug_wb_rf_wdata = debug_wb_rf_wdata_r;
    
endmodule