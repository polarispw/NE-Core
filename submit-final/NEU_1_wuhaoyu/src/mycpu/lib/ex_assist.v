`include "defines.vh"
module ex_e(
    input wire rst,
    input wire clk,
    input wire [`ID_INST_INFO-1:0] inst_bus,

    output wire [`EX_INST_INFO-1:0] ex_to_mem_bus,
    output wire [`EX_INFO_BACK-1:0] ex_to_rf_bus,

    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata 
);

    wire [31:0] ex_pc, inst;
    wire [11:0] alu_op;
    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;

    wire rf_we, data_sram_en, data_sram_wen;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [31:0] rf_rdata1, rf_rdata2;

    wire [31:0] hi_i, lo_i;
    wire [8:0] hilo_op;
    wire [11:0] mem_op;

    wire [`EXCEPT_WD-1:0] exceptinfo_i;
    wire [`EXCEPT_WD-1:0] exceptinfo_o;
    wire [31:0] excepttype;

    assign {
        exceptinfo_i,   // 290:241
        mem_op,         // 240:229
        hilo_op,        // 228:220
        hi_i, lo_i,     // 219:156
        ex_pc,          // 155:124
        inst,           // 123:92
        alu_op,         // 91:80 
        sel_alu_src1,   // 79:77
        sel_alu_src2,   // 76:73
        data_sram_en,   // 72
        data_sram_wen,  // 71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rf_rdata2,      // 63:32
        rf_rdata1       // 31:0
    } = inst_bus;


// alu
    wire [31:0] imm_sign_extend, imm_zero_extend, sa_zero_extend;
    assign imm_sign_extend = {{16{inst[15]}},inst[15:0]};
    assign imm_zero_extend = {16'b0, inst[15:0]};
    assign sa_zero_extend = {27'b0,inst[10:6]};

    wire [31:0] alu_src1, alu_src2;
    wire [31:0] alu_result, ex_result;

    assign alu_src1 = sel_alu_src1[1] ? ex_pc :
                      sel_alu_src1[2] ? sa_zero_extend :
                      exceptinfo_i[42]? 32'b0 : rf_rdata1;

    assign alu_src2 = sel_alu_src2[1] ? imm_sign_extend :
                      sel_alu_src2[2] ? 32'd8 :
                      sel_alu_src2[3] ? imm_zero_extend : rf_rdata2;
    
    alu u_alu(
    	.alu_control (alu_op ),
        .alu_src1    (alu_src1    ),
        .alu_src2    (alu_src2    ),
        .alu_result  (alu_result  )
    );


// load & store  
    wire inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw, inst_lwl, inst_lwr;
    wire inst_sb, inst_sh, inst_sw, inst_swl, inst_swr;

    wire [3:0] byte_sel;
    wire is_load = inst_lw | inst_lh | inst_lhu | inst_lb | inst_lbu;

    assign {
        inst_lwl,inst_lwr, inst_swl, inst_swr,
        inst_lb, inst_lbu, inst_lh, inst_lhu,
        inst_lw, inst_sb, inst_sh, inst_sw
    } = mem_op;
    
    assign data_sram_addr  = ex_result;
    assign data_sram_wdata = rf_rdata2;
    assign byte_sel = 4'b0;


// hilo reg ralated
    wire inst_mfhi, inst_mflo,  inst_mthi,  inst_mtlo;
    wire inst_mul , inst_mult, inst_multu,  inst_div,   inst_divu;

    wire hi_we, lo_we;
    wire [31:0] hi_o, lo_o;
    wire [`HILO_WD-1:0] hilo_bus;

    assign {
        inst_mul,
        inst_mfhi, inst_mflo, inst_mthi, inst_mtlo,
        inst_mult, inst_multu, inst_div, inst_divu
    } = hilo_op;

    assign hi_we = inst_mthi;
    assign lo_we = inst_mtlo;

    assign hi_o = inst_mthi ? rf_rdata1 : 32'b0;
    assign lo_o = inst_mtlo ? rf_rdata1 : 
                  inst_lwl|inst_lwr ? rf_rdata2 : 32'b0;

    assign hilo_bus = {
        hi_we, hi_o,
        lo_we, lo_o
    };


// except
    wire [31:0] alu_src2_mux;
    wire [32:0] result_sum;
    wire ov_sum, ov;
    wire adel, ades;
    wire is_mfc0;
    wire int_overflow_pos;
    wire except_of_overflow;

    assign is_mfc0 = exceptinfo_i[43];
    assign int_overflow_pos = (inst[31:26]==6'b0 && inst[10:6]==5'b0 && inst[5:0]==6'b10_0000) |
                              (inst[31:26]==6'b0 && inst[10:6]==5'b0 && inst[5:0]==6'b10_0010) |  
                              (inst[31:26]==6'b00_1000) ? 1'b1:1'b0;

    assign alu_src2_mux = alu_op[10] ? (~alu_src2)+1 : alu_src2;
    assign result_sum = alu_src1 + alu_src2_mux;
    assign ov_sum = ((!alu_src1[31] && !alu_src2_mux[31]) && result_sum[31]) || ((alu_src1[31] && alu_src2_mux[31]) && (!result_sum[31]));

    assign ov = ((int_overflow_pos==1'b1) && (ov_sum == 1'b1)) ? 1'b1 : 1'b0;
    assign adel = ((inst_lw && data_sram_addr[1:0] != 2'b0) || ((inst_lh||inst_lhu) && data_sram_addr[0] != 1'b0)) ? 1'b1 : 1'b0;
    assign ades = ((inst_sw && data_sram_addr[1:0] != 2'b0) || ( inst_sh            && data_sram_addr[0] != 1'b0)) ? 1'b1 : 1'b0; 

    assign excepttype = ov   && (exceptinfo_i[`PrioCode] < 4'h2) ? `OV          :
                        adel && (exceptinfo_i[`PrioCode] < 4'h1) ? `LOADASSERT  :
                        ades && (exceptinfo_i[`PrioCode] < 4'h1) ? `STOREASSERT : exceptinfo_i[31:0];// 这里要考虑例外优先级

    assign exceptinfo_o = {exceptinfo_i[49:32], excepttype};


// output

    assign ex_result = inst_mflo ? lo_i : 
                       inst_mfhi ? hi_i : alu_result;

    assign ex_to_mem_bus = {
        exceptinfo_o,   // 204:155    
        mem_op,         // 154:143
        hilo_bus,       // 142:77
        ex_pc,          // 76:45
        data_sram_en,   // 44
        data_sram_wen,  // 43
        byte_sel,       // 42:39
        sel_rf_res,     // 38
        rf_we,          // 37
        rf_waddr,       // 36:32
        ex_result       // 31:0
    };

    assign ex_to_rf_bus = {
        is_load,
        is_mfc0,
        hilo_bus,
        rf_we,
        rf_waddr,
        ex_result
    };
    
endmodule