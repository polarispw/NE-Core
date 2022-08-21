`include "lib/defines.vh"
module DT(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`STALLBUS_WD-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] ex_to_dt_bus,
    input wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus,

    output wire [`EX_TO_MEM_WD-1:0] dt_to_mem_bus,
    output wire [`EX_TO_RF_WD-1:0] dt_to_rf_bus,

    input  wire data_sram_en_i1,
    input  wire data_sram_en_i2,
    input  wire data_sram_wen_i1,
    input  wire data_sram_wen_i2,
    input  wire [11:0] mem_op,
    input  wire [`TTbits_wire] ex_result,
    input  wire [`TTbits_wire] rf_rdata,
    input  wire [`TTbits_wire] inst1_pc,
    input  wire [`TTbits_wire] inst2_pc,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_pc,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_dt_bus_r;
    reg [`EX_TO_RF_WD-1:0]  dt_to_rf_bus_r;

    always @ (posedge clk) begin
        if (rst | flush) begin
            ex_to_dt_bus_r <= `EX_TO_MEM_WD'b0;
            dt_to_rf_bus_r <= `EX_TO_RF_WD'b0;
        end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin
            ex_to_dt_bus_r <= `EX_TO_MEM_WD'b0;
            dt_to_rf_bus_r <= `EX_TO_RF_WD'b0;
        end
        else if (stall[4]==`NoStop) begin
            ex_to_dt_bus_r <= ex_to_dt_bus;
            dt_to_rf_bus_r <= ex_to_rf_bus;
        end
    end

// output
    wire [3:0] byte_sel, data_sram_sel_i1, data_sram_sel_i2;
    
    assign data_sram_sel_i1 = {4{data_sram_en_i1}} & byte_sel; 
    assign data_sram_sel_i2 = {4{data_sram_en_i2}} & byte_sel;

    assign dt_to_mem_bus = {
        ex_to_dt_bus_r[412:248],
        data_sram_sel_i2,
        ex_to_dt_bus_r[243: 43],
        data_sram_sel_i1,
        ex_to_dt_bus_r[ 38:  0]
    };
    assign dt_to_rf_bus  = dt_to_rf_bus_r;

// RW ram data
    reg data_sram_en_i1_r;
    reg data_sram_en_i2_r;
    reg data_sram_wen_i1_r;
    reg data_sram_wen_i2_r;
    reg [11:0] mem_op_r;
    reg [`TTbits_wire] ex_result_r;
    reg [`TTbits_wire] rf_rdata_r;
    reg [`TTbits_wire] inst1_pc_r;
    reg [`TTbits_wire] inst2_pc_r;

    always @(posedge clk ) begin
        if (rst | flush) begin
            data_sram_en_i1_r  <= 1'b0;
            data_sram_en_i2_r  <= 1'b0;
            data_sram_wen_i1_r <= 4'b0;
            data_sram_wen_i2_r <= 4'b0;
            mem_op_r           <= 12'b0;
            ex_result_r        <= `ZeroWord;
            rf_rdata_r         <= `ZeroWord;
            inst1_pc_r         <= `ZeroWord;
            inst2_pc_r         <= `ZeroWord;
        end
        else if (stall[4]==`Stop && stall[5]==`NoStop) begin
            data_sram_en_i1_r  <= 1'b0;
            data_sram_en_i2_r  <= 1'b0;
            data_sram_wen_i1_r <= 4'b0;
            data_sram_wen_i2_r <= 4'b0;
            mem_op_r           <= 12'b0;
            ex_result_r        <= `ZeroWord;
            rf_rdata_r         <= `ZeroWord;
            inst1_pc_r         <= `ZeroWord;
            inst2_pc_r         <= `ZeroWord;
        end
        else if (stall[4]==`NoStop) begin
            data_sram_en_i1_r  <= data_sram_en_i1;
            data_sram_en_i2_r  <= data_sram_en_i2;
            data_sram_wen_i1_r <= data_sram_wen_i1;
            data_sram_wen_i2_r <= data_sram_wen_i2;
            mem_op_r           <= mem_op;
            ex_result_r        <= ex_result;
            rf_rdata_r         <= rf_rdata;
            inst1_pc_r         <= inst1_pc;
            inst2_pc_r         <= inst2_pc;
        end
    end

    reg exist_except;
    wire [31:0] excepttype, exc_i1, exc_i2;
    always @(posedge clk ) begin
        if(rst | flush) begin
            exist_except <= 1'b0;
        end
        else if(excepttype != `ZeroWord) begin
            exist_except <= 1'b1;   //当前流水线有未处理的异常
        end
    end

    assign exc_i1 = ex_to_dt_bus_r[186:155];
    assign exc_i2 = ex_to_dt_bus_r[391:360];
    assign excepttype = exc_i1 != `ZeroWord ? exc_i1 :
                        exc_i2 != `ZeroWord ? exc_i2 : `ZeroWord;

    decoder_2_4 u_decoder_2_4(
    	.in            (ex_result_r[1:0] ),
        .mem_op        (mem_op_r         ),
        .ex_result     (ex_result_r      ),
        .rf_rdata2     (rf_rdata_r       ),
        .out           (byte_sel         ),
        .data_sram_addr(data_sram_addr   ),
        .wdata         (data_sram_wdata  )
    );

    assign data_sram_en  = exist_except | (exc_i1 != `ZeroWord) | (exc_i2 != `ZeroWord & data_sram_en_i2_r) ?
                           1'b0 : data_sram_en_i1_r | data_sram_en_i2_r;
    assign data_sram_wen = data_sram_wen_i1_r | data_sram_wen_i2_r ? byte_sel : 4'b0;
    assign data_sram_pc  = data_sram_en_i1_r ? inst1_pc_r :
                           data_sram_en_i2_r ? inst2_pc_r : `ZeroWord;

endmodule