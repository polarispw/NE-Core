`include "lib/defines.vh"
module MEM(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`STALLBUS_WD-1:0] stall,

    input wire [`EX_TO_MEM_WD-1:0] dt_to_mem_bus,
    input wire [31:0] data_sram_rdata_i,

    input  wire caused_by_i1,
    input  wire caused_by_i2,
    input  wire [31:0] cp0_rdata,
    output wire [`EXCEPT_WD-1:0] exceptinfo_i1,
    output wire [`EXCEPT_WD-1:0] exceptinfo_i2,
    output wire [31:0] current_pc_i1,
    output wire [31:0] current_pc_i2,
    output wire [31:0] rt_rdata_i1,
    output wire [31:0] rt_rdata_i2,

    output wire op_tlbp,
    output wire op_tlbr,
    output wire op_tlbwi,
    output wire op_load,
    output wire op_store,

    output wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus,
    output wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus
);

    reg [`EX_TO_MEM_WD-1:0] ex_to_mem_bus_r;

    always @ (posedge clk) begin
        if (rst | flush) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[5]==`Stop && stall[6]==`NoStop) begin
            ex_to_mem_bus_r <= `EX_TO_MEM_WD'b0;
        end
        else if (stall[5]==`NoStop) begin
            ex_to_mem_bus_r <= dt_to_mem_bus;
        end
    end

    wire [31:0] mem_pc_i1, mem_pc_i2;
    wire data_ram_en_i1, data_ram_en_i2;
    wire data_ram_wen_i1, data_ram_wen_i2;
    wire [3:0] data_ram_sel_i1, data_ram_sel_i2;
    wire sel_rf_res_i1, sel_rf_res_i2;
    wire rf_we_i1, rf_we_i2;
    wire [4:0] rf_waddr_i1, rf_waddr_i2;
    wire [31:0] rf_wdata_i1, rf_wdata_i2;
    wire [31:0] ex_result_i1, ex_result_i2;
    wire [31:0] mem_result;
    wire [`HILO_WD-1:0] hilo_bus_i1, hilo_bus_i2;
    wire [11:0] mem_op_i1, mem_op_i2;
    wire [`EXCEPT_WD -1:0] exceptinfo_i_i1, exceptinfo_i_i2;
    wire inst1_valid, inst2_valid;
    wire switch;

    assign {
        switch,            // 412
        inst2_valid,       // 411
        inst1_valid,       // 410
        exceptinfo_i_i2,   // 409:360
        mem_op_i2,         // 359:348
        hilo_bus_i2,       // 347:284
        mem_pc_i2,         // 283:250
        data_ram_en_i2,    // 249
        data_ram_wen_i2,   // 248
        data_ram_sel_i2,   // 247:244
        sel_rf_res_i2,     // 243
        rf_we_i2,          // 242
        rf_waddr_i2,       // 241:237
        ex_result_i2,      // 236:205
        exceptinfo_i_i1,   // 204:155
        mem_op_i1,         // 154:143
        hilo_bus_i1,       // 142:77
        mem_pc_i1,         // 76:45
        data_ram_en_i1,    // 44
        data_ram_wen_i1,   // 43
        data_ram_sel_i1,   // 42:39
        sel_rf_res_i1,     // 38
        rf_we_i1,          // 37
        rf_waddr_i1,       // 36:32
        ex_result_i1       // 31:0
    } =  ex_to_mem_bus_r;


// load data

    wire [31:0] data_sram_rdata;
    reg  [31:0] data_sram_r;
    reg stall_flag;

    always @(posedge clk ) begin
        stall_flag <= stall[4];
    end

    always @(posedge clk ) begin
        if (rst | flush) begin
            data_sram_r <= 32'b0;
        end
        else if(~stall_flag) begin
            data_sram_r <= data_sram_rdata_i;
        end
    end

    assign data_sram_rdata = stall_flag ? data_sram_r : data_sram_rdata_i;

    wire inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw;
    wire inst_sb, inst_sh, inst_sw;
    wire inst_lwl, inst_lwr;
    wire inst_swl, inst_swr;
    wire [31:0] ex_result, rt_data;

    assign ex_result = data_ram_en_i1 ? ex_result_i1 :
                       data_ram_en_i2 ? ex_result_i2 : `ZeroWord;
    assign rt_data   = data_ram_en_i1 ? hilo_bus_i1[31:0] :
                       data_ram_en_i2 ? hilo_bus_i2[31:0] : `ZeroWord;
    wire [1:0] l2b   = ex_result[1:0];

    assign {
        inst_lwl,inst_lwr, inst_swl, inst_swr,
        inst_lb, inst_lbu, inst_lh, inst_lhu, 
        inst_lw, inst_sb,  inst_sh, inst_sw
    } = data_ram_en_i1 ? mem_op_i1 :
        data_ram_en_i2 ? mem_op_i2 : 12'b0;

    wire [31:0] lb_res, lbu_res, lh_res, lhu_res, lw_res, lwl_res, lwr_res;

    assign lb_res  = l2b==2'b00 ? {{24{data_sram_rdata[ 7]}}, data_sram_rdata[ 7: 0]} :
                     l2b==2'b01 ? {{24{data_sram_rdata[15]}}, data_sram_rdata[15: 8]} :
                     l2b==2'b10 ? {{24{data_sram_rdata[23]}}, data_sram_rdata[23:16]} :
                     l2b==2'b11 ? {{24{data_sram_rdata[31]}}, data_sram_rdata[31:24]} : `ZeroWord;
    assign lbu_res = l2b==2'b00 ? {24'b0, data_sram_rdata[ 7: 0]} :
                     l2b==2'b01 ? {24'b0, data_sram_rdata[15: 8]} :
                     l2b==2'b10 ? {24'b0, data_sram_rdata[23:16]} :
                     l2b==2'b11 ? {24'b0, data_sram_rdata[31:24]} : `ZeroWord;

    assign lh_res  = l2b==2'b00 ? {{16{data_sram_rdata[15]}}, data_sram_rdata[15: 0]} :
                     l2b==2'b10 ? {{16{data_sram_rdata[31]}}, data_sram_rdata[31:16]} : `ZeroWord;
    assign lhu_res = l2b==2'b00 ? {16'b0, data_sram_rdata[15: 0]} :
                     l2b==2'b10 ? {16'b0, data_sram_rdata[31:16]} : `ZeroWord;
    assign lw_res  = data_sram_rdata;

    assign lwl_res = l2b==2'b00 ? {data_sram_rdata[ 7:0], rt_data[23:0]} :
                     l2b==2'b01 ? {data_sram_rdata[15:0], rt_data[15:0]} :
                     l2b==2'b10 ? {data_sram_rdata[23:0], rt_data[ 7:0]} :
                     l2b==2'b11 ? data_sram_rdata : `ZeroWord;
    assign lwr_res = l2b==2'b00 ? data_sram_rdata :
                     l2b==2'b01 ? {rt_data[31:24], data_sram_rdata[31: 8]} :
                     l2b==2'b10 ? {rt_data[31:16], data_sram_rdata[31:16]} :
                     l2b==2'b11 ? {rt_data[31: 8], data_sram_rdata[31:24]} : `ZeroWord;

    assign mem_result = inst_lb  ? lb_res  :
                        inst_lbu ? lbu_res :
                        inst_lh  ? lh_res  :
                        inst_lhu ? lhu_res :
                        inst_lw  ? lw_res  :
                        inst_lwl ? lwl_res :
                        inst_lwr ? lwr_res : `ZeroWord;


// CP0
    assign exceptinfo_i1 = exceptinfo_i_i1;
    assign exceptinfo_i2 = exceptinfo_i_i2;
    assign current_pc_i1 = mem_pc_i1;
    assign current_pc_i2 = mem_pc_i2;
    assign rt_rdata_i1   = ex_result_i1;
    assign rt_rdata_i2   = ex_result_i2;

    assign op_tlbp  = exceptinfo_i1[47];
    assign op_tlbr  = exceptinfo_i1[46];
    assign op_tlbwi = exceptinfo_i1[45];

    assign op_load  = inst_lwl | inst_lwr | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lw;
    assign op_store = inst_sb  | inst_sh  | inst_sw | inst_swl | inst_swr;

// output
    wire [`MEM_INST_INFO-1:0] mem_to_wb_bus_i1, mem_to_wb_bus_i2;

    assign rf_wdata_i1 = sel_rf_res_i1 & data_ram_en_i1 ? mem_result : 
                         exceptinfo_i_i1[43] ? cp0_rdata  : ex_result_i1;
    assign rf_wdata_i2 = sel_rf_res_i2 & data_ram_en_i2 ? mem_result : ex_result_i2;

    assign mem_to_wb_bus_i1 = (inst1_valid & ~caused_by_i1) ? //解决有写回要求的跳转指令延迟槽造成例外时flush导致跳转指令写回失败
    {
        hilo_bus_i1,   // 135:70
        mem_pc_i1,     // 69:38
        rf_we_i1,      // 37
        rf_waddr_i1,   // 36:32
        rf_wdata_i1    // 31:0
    } : `MEM_INST_INFO'b0;

    assign mem_to_wb_bus_i2 = (inst2_valid & ~(caused_by_i1 | caused_by_i2)) | (inst2_valid & switch & ~caused_by_i2) ?
    {
        hilo_bus_i2,
        mem_pc_i2,
        rf_we_i2,
        rf_waddr_i2,
        rf_wdata_i2
    } : `MEM_INST_INFO'b0;

    assign mem_to_wb_bus = switch ? {mem_to_wb_bus_i1, mem_to_wb_bus_i2} :
                                    {mem_to_wb_bus_i2, mem_to_wb_bus_i1} ;

    assign mem_to_rf_bus = {
        hilo_bus_i2,
        rf_we_i2,
        rf_waddr_i2,
        rf_wdata_i2,
        hilo_bus_i1,
        rf_we_i1,
        rf_waddr_i1,
        rf_wdata_i1
    };

endmodule