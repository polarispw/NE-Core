`include "lib/defines.vh"
module EX(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`STALLBUS_WD-1:0] stall,
    output wire stallreq_for_ex,

    input wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`EX_TO_MEM_WD-1:0] ex_to_dt_bus,
    output wire [`EX_TO_RF_WD-1:0] ex_to_rf_bus,

    output wire data_sram_en_i1,
    output wire data_sram_en_i2,
    output wire data_sram_wen_i1,
    output wire data_sram_wen_i2,
    output wire [11:0] mem_op,
    output wire [31:0] ex_result,
    output wire [31:0] rf_rdata,
    output wire [31:0] inst1_pc,
    output wire [31:0] inst2_pc
);

    reg [`ID_TO_EX_WD-1:0] id_to_ex_bus_r;

    always @ (posedge clk) begin
        if (rst | flush) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[3]==`Stop && stall[4]==`NoStop) begin
            id_to_ex_bus_r <= `ID_TO_EX_WD'b0;
        end
        else if (stall[3]==`NoStop) begin
            id_to_ex_bus_r <= id_to_ex_bus;
        end
    end

    wire [`ID_INST_INFO-1:0] inst1_bus, inst2_bus;
    wire inst1_valid, inst2_valid;
    wire switch;

    wire [`TTbits_wire]data_sram_addr_i1, data_sram_addr_i2;
    wire [`TTbits_wire]data_sram_wdata_i1, data_sram_wdata_i2;
    wire [`EX_INST_INFO-1:0] ex_to_mem_bus_i1, ex_to_mem_bus_i2;
    wire [`EX_INFO_BACK-1:0] ex_to_rf_bus_i1, ex_to_rf_bus_i2;

    assign {inst2_valid, inst1_valid} = id_to_ex_bus_r[1:0];
    assign inst1_bus = id_to_ex_bus_r[292:2];
    assign inst2_bus = id_to_ex_bus_r[583:293];
    assign switch    = id_to_ex_bus_r[584];

    ex_p u_ex_p(
        .rst            (rst               ),
        .clk            (clk               ),
        .inst_bus       (inst1_bus         ),
        .stallreq_for_ex(stallreq_for_ex   ),
        .ex_to_mem_bus  (ex_to_mem_bus_i1  ),
        .ex_to_rf_bus   (ex_to_rf_bus_i1   ),
        .data_sram_addr (data_sram_addr_i1 ),
        .data_sram_wdata(data_sram_wdata_i1)
    );// inst1

    ex_e u_ex_e(
        .rst            (rst               ),
        .clk            (clk               ),
        .inst_bus       (inst2_bus         ),
        .ex_to_mem_bus  (ex_to_mem_bus_i2  ),
        .ex_to_rf_bus   (ex_to_rf_bus_i2   ),
        .data_sram_addr (data_sram_addr_i2 ),
        .data_sram_wdata(data_sram_wdata_i2) 
    );// inst2
    

// output

    assign ex_to_dt_bus = {switch, inst2_valid, inst1_valid, ex_to_mem_bus_i2, ex_to_mem_bus_i1} ;
    assign ex_to_rf_bus  = {ex_to_rf_bus_i2, ex_to_rf_bus_i1};

    assign data_sram_en_i1  = inst1_bus[72];
    assign data_sram_en_i2  = inst2_bus[72];
    assign data_sram_wen_i1 = inst1_bus[71];
    assign data_sram_wen_i2 = inst2_bus[71];
    
    assign mem_op    = data_sram_en_i1 ? inst1_bus[240:229] :
                       data_sram_en_i2 ? inst2_bus[240:229] : 12'b0;
    assign ex_result = data_sram_en_i1 ? data_sram_addr_i1 :
                       data_sram_en_i2 ? data_sram_addr_i2 : `ZeroWord;
    assign rf_rdata  = data_sram_en_i1 ? data_sram_wdata_i1 :
                       data_sram_en_i2 ? data_sram_wdata_i2 : `ZeroWord;

    assign inst1_pc  = inst1_bus[155:124];
    assign inst2_pc  = inst2_bus[155:124];


endmodule