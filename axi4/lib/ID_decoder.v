`include "defines.vh"
module decoder(
    input wire [31:0] inst_sram_rdata,
    input wire [31:0] id_pc,

    output wire [`INST_INFO-1:0] inst_info,
    output wire [32:0] br_bus,
    output wire is_br,
    output wire [2:0] inst_flag
);

    wire [31:0] inst;
    assign inst = inst_sram_rdata;

    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;
    wire [8:0] hilo_op;
    wire [11:0] mem_op;

    wire data_ram_en;
    wire data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire inst_valid;
    wire [`EXCEPTINFO_WD-1:0] exceptinfo;

//decode part
    assign opcode      = inst[31:26];
    assign rs          = inst[25:21];
    assign rt          = inst[20:16];
    assign rd          = inst[15:11];
    assign sa          = inst[10:6];
    assign func        = inst[5:0];
    assign imm         = inst[15:0];
    assign instr_index = inst[25:0];
    assign code        = inst[25:6];
    assign base        = inst[25:21];
    assign offset      = inst[15:0];
    assign sel         = inst[2:0];

    wire inst_add,  inst_addi,  inst_addu,  inst_addiu;
    wire inst_sub,  inst_subu,  inst_slt,   inst_slti;
    wire inst_sltu, inst_sltiu, inst_div,   inst_divu;
    wire inst_mult, inst_multu, inst_and,   inst_andi;
    wire inst_lui,  inst_nor,   inst_or,    inst_ori;
    wire inst_xor,  inst_xori,  inst_sllv,  inst_sll;
    wire inst_srav, inst_sra,   inst_srlv,  inst_srl;
    wire inst_beq,  inst_bne,   inst_bgez,  inst_bgtz;
    wire inst_blez, inst_bltz,  inst_bgezal,inst_bltzal;
    wire inst_j,    inst_jal,   inst_jr,    inst_jalr;
    wire inst_mfhi, inst_mflo,  inst_mthi,  inst_mtlo;
    wire inst_break,inst_syscall;
    wire inst_lb,   inst_lbu,   inst_lh,    inst_lhu,   inst_lw;
    wire inst_sb,   inst_sh,    inst_sw;
    wire inst_eret, inst_mfc0,  inst_mtc0;
    wire inst_mul;
    wire inst_lwl, inst_lwr, inst_swl, inst_swr;
    wire inst_tlbp, inst_tlbr,  inst_tlbwi, inst_tlbwr;
    wire inst_jalx;
    wire inst_cache;

    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;

    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode    ),
        .out (op_d      )
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func      ),
        .out (func_d    )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs        ),
        .out (rs_d      )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt        ),
        .out (rt_d      )
    );

    decoder_5_32 u2_decoder_5_32(
    	.in  (rd        ),
        .out (rd_d      )
    );

    decoder_5_32 u3_decoder_5_32(
    	.in  (sa        ),
        .out (sa_d      )
    );
    
//inst launch
    assign inst_add     = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b10_0000];
    assign inst_addi    = op_d[6'b00_1000];
    assign inst_addu    = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b10_0001];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_sub     = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b10_0010];
    assign inst_subu    = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b10_0011];
    assign inst_slt     = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b10_1010];
    assign inst_slti    = op_d[6'b00_1010];
    assign inst_sltu    = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b10_1011];
    assign inst_sltiu   = op_d[6'b00_1011];
    assign inst_div     = op_d[6'b00_0000] & rd_d[5'b0_0000] & sa_d[5'b0_0000] & func_d[6'b01_1010];
    assign inst_divu    = op_d[6'b00_0000] & rd_d[5'b0_0000] & sa_d[5'b0_0000] & func_d[6'b01_1011];
    assign inst_mult    = op_d[6'b00_0000] & rd_d[5'b0_0000] & sa_d[5'b0_0000] & func_d[6'b01_1000];
    assign inst_multu   = op_d[6'b00_0000] & rd_d[5'b0_0000] & sa_d[5'b0_0000] & func_d[6'b01_1001];
    assign inst_and     = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b10_0100];
    assign inst_andi    = op_d[6'b00_1100];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_nor     = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b10_0111];
    assign inst_or      = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b10_0101];
    assign inst_ori     = op_d[6'b00_1101];
    assign inst_xor     = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b10_0110];
    assign inst_xori    = op_d[6'b00_1110];
    assign inst_sllv    = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b00_0100];
    assign inst_sll     = op_d[6'b00_0000] & rs_d[5'b0_0000] & func_d[6'b00_0000];
    assign inst_srav    = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b00_0111];
    assign inst_sra     = op_d[6'b00_0000] & rs_d[5'b0_0000] & func_d[6'b00_0011];
    assign inst_srlv    = op_d[6'b00_0000] & sa_d[5'b0_0000] & func_d[6'b00_0110];
    assign inst_srl     = op_d[6'b00_0000] & rs_d[5'b0_0000] & func_d[6'b00_0010];
    assign inst_beq     = op_d[6'b00_0100];
    assign inst_bne     = op_d[6'b00_0101];
    assign inst_bgez    = op_d[6'b00_0001] & rt_d[5'b0_0001];
    assign inst_bgtz    = op_d[6'b00_0111] & rt_d[5'b0_0000];
    assign inst_blez    = op_d[6'b00_0110] & rt_d[5'b0_0000];
    assign inst_bltz    = op_d[6'b00_0001] & rt_d[5'b0_0000];
    assign inst_bgezal  = op_d[6'b00_0001] & rt_d[5'b1_0001];
    assign inst_bltzal  = op_d[6'b00_0001] & rt_d[5'b1_0000];
    assign inst_j       = op_d[6'b00_0010];
    assign inst_jal     = op_d[6'b00_0011];
    assign inst_jr      = op_d[6'b00_0000] & rt_d[5'b0_0000] & rd_d[5'b0_0000] & sa_d[5'b0_0000] & func_d[6'b00_1000];
    assign inst_jalr    = op_d[6'b00_0000] & rt_d[5'b0_0000] & sa_d[5'b0_0000] & func_d[6'b00_1001];
    assign inst_mfhi    = op_d[6'b00_0000] & rs_d[5'b0_0000] & rt_d[5'b0_0000] & sa_d[5'b0_0000] & func_d[6'b01_0000];
    assign inst_mflo    = op_d[6'b00_0000] & rs_d[5'b0_0000] & rt_d[5'b0_0000] & sa_d[5'b0_0000] & func_d[6'b01_0010];
    assign inst_mthi    = op_d[6'b00_0000] & rt_d[5'b0_0000] & rd_d[5'b0_0000] & sa_d[5'b0_0000] & func_d[6'b01_0001];
    assign inst_mtlo    = op_d[6'b00_0000] & rt_d[5'b0_0000] & rd_d[5'b0_0000] & sa_d[5'b0_0000] & func_d[6'b01_0011];
    assign inst_break   = op_d[6'b00_0000] & func_d[6'b00_1101];
    assign inst_syscall = op_d[6'b00_0000] & func_d[6'b00_1100];
    assign inst_lb      = op_d[6'b10_0000];
    assign inst_lbu     = op_d[6'b10_0100];
    assign inst_lh      = op_d[6'b10_0001];
    assign inst_lhu     = op_d[6'b10_0101];
    assign inst_lw      = op_d[6'b10_0011];
    assign inst_sb      = op_d[6'b10_1000];
    assign inst_sh      = op_d[6'b10_1001];
    assign inst_sw      = op_d[6'b10_1011];
    assign inst_eret    = op_d[6'b01_0000] & func_d[6'b01_1000];
    assign inst_mfc0    = op_d[6'b01_0000] & rs_d[5'b0_0000] & sa_d[5'b0_0000] & (inst[5:3]==3'b000);
    assign inst_mtc0    = op_d[6'b01_0000] & rs_d[5'b0_0100] & sa_d[5'b0_0000] & (inst[5:3]==3'b000);
    assign inst_mul     = op_d[6'b01_1100] & sa_d[5'b0_0000] & func_d[6'b00_0010];
    assign inst_lwl     = op_d[6'b10_0010];
    assign inst_lwr     = op_d[6'b10_0110];
    assign inst_swl     = op_d[6'b10_1010];
    assign inst_swr     = op_d[6'b10_1110];
    assign inst_tlbp    = op_d[6'b01_0000] & rs_d[5'b1_0000] & func_d[6'b00_1000];
    assign inst_tlbr    = op_d[6'b01_0000] & rs_d[5'b1_0000] & func_d[6'b00_0001];
    assign inst_tlbwi   = op_d[6'b01_0000] & rs_d[5'b1_0000] & func_d[6'b00_0010];
    assign inst_tlbwr   = op_d[6'b01_0000] & rs_d[5'b1_0000] & func_d[6'b00_0110];
    assign inst_jalx    = op_d[6'b01_1101];
    assign inst_cache   = op_d[6'b10_1111];
    assign inst_match   = op_d[6'b01_1100] & sa_d[5'b1_1100] & func_d[6'b11_0111];
    
//data select
    // rs to reg1
    assign sel_alu_src1[0] = inst_add | inst_addiu | inst_addu | inst_subu | inst_ori   | inst_or   | inst_sw   | inst_lw 
                           | inst_xor | inst_sltu  | inst_slt  | inst_slti | inst_sltiu | inst_addi | inst_sub 
                           | inst_and | inst_andi  | inst_nor  | inst_xori | inst_sllv  | inst_srav | inst_srlv
                           | inst_lb  | inst_lbu   | inst_lh   | inst_lhu  | inst_sb    | inst_sh   | inst_mtlo | inst_mthi
                           | inst_lwl | inst_lwr   | inst_swl  | inst_swr  | inst_match;

    // pc to reg1
    assign sel_alu_src1[1] = inst_jal | inst_bltzal | inst_bgezal | inst_jalr | inst_jalx;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = inst_sll | inst_sra | inst_srl;

    
    // rt to reg2
    assign sel_alu_src2[0] = inst_add | inst_addu | inst_subu | inst_sll  | inst_or  | inst_xor  | inst_sltu | inst_slt
                           | inst_sub | inst_and  | inst_nor  | inst_sllv | inst_sra | inst_srav | inst_srl  | inst_srlv
                           | inst_sw  | inst_sb   | inst_sh   | inst_mtc0 | inst_lwl | inst_lwr  | inst_swl  | inst_swr | inst_match;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_sw  | inst_lw | inst_slti | inst_sltiu | inst_addi | inst_lb
                           | inst_lbu | inst_lh    | inst_lhu | inst_sb | inst_sh   | inst_lwl   | inst_lwr  | inst_swl  | inst_swr;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = inst_jal | inst_bltzal | inst_bgezal | inst_jalr | inst_jalx;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_ori | inst_andi | inst_xori;


    //op select
    assign op_add  = inst_add  | inst_addi | inst_addiu | inst_addu | inst_jal | inst_sw | inst_lw | inst_bltzal | inst_bgezal |
                     inst_jalr | inst_lb   | inst_lbu   | inst_lh   | inst_lhu | inst_sb | inst_sh | inst_mtc0   |
                     inst_lwl  | inst_lwr  | inst_swl   | inst_swr  | inst_jalx| inst_match;
    assign op_sub  = inst_subu | inst_sub | inst_match;
    assign op_slt  = inst_slt  | inst_slti | inst_match;
    assign op_sltu = inst_sltu | inst_sltiu | inst_match;
    assign op_and  = inst_and  | inst_andi | inst_match;
    assign op_nor  = inst_nor | inst_match;
    assign op_or   = inst_ori  | inst_or | inst_match;
    assign op_xor  = inst_xor  | inst_xori | inst_match;
    assign op_sll  = inst_sll  | inst_sllv | inst_match;
    assign op_srl  = inst_srl  | inst_srlv | inst_match;
    assign op_sra  = inst_sra  | inst_srav | inst_match;
    assign op_lui  = inst_lui  | inst_match;

    assign alu_op = {
        op_add, op_sub, op_slt, op_sltu,
        op_and, op_nor, op_or,  op_xor,
        op_sll, op_srl, op_sra, op_lui
    };

    assign hilo_op = {
        inst_mul ,
        inst_mfhi, inst_mflo, inst_mthi, inst_mtlo,
        inst_mult, inst_multu, inst_div, inst_divu
    };

    assign mem_op = {
        inst_lwl,inst_lwr, inst_swl, inst_swr,
        inst_lb, inst_lbu, inst_lh, inst_lhu, 
        inst_lw, inst_sb, inst_sh, inst_sw
    };

//store select
    // load and store enable
    assign data_ram_en = inst_sw | inst_lw | inst_lb | inst_lbu | inst_lh | inst_lhu | inst_sb | inst_sh | inst_lwl | inst_lwr   | inst_swl  | inst_swr;

    // write enable
    assign data_ram_wen = inst_sw | inst_sb | inst_sh | inst_swl  | inst_swr;

    // 0 from alu_res ; 1 from load_res
    assign sel_rf_res = inst_lw | inst_lh | inst_lhu | inst_lb | inst_lbu | inst_lwl | inst_lwr; 

    // regfile store enable
    assign rf_we = inst_ori | inst_lui  | inst_addiu  | inst_subu   | inst_jal  | inst_addu  | inst_sll | inst_or 
                 | inst_lw  | inst_xor  | inst_sltu   | inst_slt    | inst_slti | inst_sltiu | inst_add | inst_addi
                 | inst_sub | inst_and  | inst_andi   | inst_nor    | inst_xori | inst_sllv  | inst_sra | inst_srav
                 | inst_srl | inst_srlv | inst_bltzal | inst_bgezal | inst_jalr | inst_mflo  | inst_mfhi
                 | inst_lh  | inst_lhu  | inst_lb     | inst_lbu    | inst_mfc0 | inst_mul
                 | inst_lwl | inst_lwr  | inst_jalx   | inst_match;

    // store in [rd]
    assign sel_rf_dst[0] = inst_addu | inst_subu | inst_sll | inst_or   | inst_xor | inst_sltu | inst_slt | inst_add
                         | inst_sub  | inst_and  | inst_nor | inst_sllv | inst_sra | inst_srav | inst_srl | inst_srlv
                         | inst_mflo | inst_mfhi | inst_mul | inst_match;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_ori | inst_lui | inst_addiu | inst_lw | inst_slti | inst_sltiu | inst_addi | inst_andi
                         | inst_xori | inst_lh | inst_lhu   | inst_lb | inst_lbu  | inst_mfc0  | inst_lwl | inst_lwr  ;
    // store in [31]
    assign sel_rf_dst[2] = inst_jal | inst_bltzal | inst_bgezal | inst_jalr | inst_jalx;

    // sel for regfile address
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;


//branch&jump
    wire br_e;
    wire [31:0] br_cls;

    assign br_e   = inst_j | inst_jr | inst_jal | inst_jalr | inst_jalx;
    assign br_cls = inst_beq   ? 32'h0000_0001 : 
                    inst_bne   ? 32'h0000_0002 : 
                    inst_bgez  ? 32'h0000_0003 : 
                    inst_bgtz  ? 32'h0000_0004 : 
                    inst_blez  ? 32'h0000_0005 : 
                    inst_bltz  ? 32'h0000_0006 : 
                    inst_bltzal? 32'h0000_0007 : 
                    inst_bgezal? 32'h0000_0008 :
                    inst_j     ? 32'h0000_0009 :
                    inst_jr    ? 32'h0000_000a :
                    inst_jal   ? 32'h0000_000b :
                    inst_jalr  ? 32'h0000_000c :
                    inst_jalx  ? 32'h0000_000d : 32'h0000_0000;
    
    assign br_bus = {br_e, br_cls};
    assign is_br  = inst_beq  | inst_bne  | inst_bgez   | inst_bgtz   |
                    inst_blez | inst_bltz | inst_bltzal | inst_bgezal |
                    inst_j    | inst_jr   | inst_jal    | inst_jalr   | inst_jalx ? 1'b1 : 1'b0;
    
    
//except
    wire cp0_we, is_delayslot;
    wire [4:0] waddr, raddr;
    wire [31:0] excepttype;
    wire [`EXCEPT_WD-1:0] except_info;

    assign inst_valid = inst_add  | inst_addi  | inst_addu   | inst_addiu |
                        inst_sub  | inst_subu  | inst_slt    | inst_slti  |  
                        inst_sltu | inst_sltiu | inst_div    | inst_divu  |
                        inst_mult | inst_multu | inst_and    | inst_andi  |  
                        inst_lui  | inst_nor   | inst_or     | inst_ori   |
                        inst_xor  | inst_xori  | inst_sll    | inst_sllv  |
                        inst_sra  | inst_srav  | inst_srl    | inst_srlv  |
                        inst_beq  | inst_bne   | inst_bgez   | inst_bgtz  |
                        inst_blez | inst_bltz  | inst_bltzal | inst_bgezal|
                        inst_j    | inst_jal   | inst_jr     | inst_jalr  |  
                        inst_mfhi | inst_mflo  | inst_mthi   | inst_mtlo  |
                        inst_lb   | inst_lbu   | inst_lh     | inst_lhu   |
                        inst_lw   | inst_sb    | inst_sh     | inst_sw    |
                        inst_break| inst_eret  | inst_mfc0   | inst_mtc0  |
                        inst_lwl  | inst_lwr   | inst_swl    | inst_swr   |
                        inst_tlbp | inst_tlbr  | inst_tlbwi  | inst_tlbwr |
                        inst_mul  | inst_jalx  | inst_syscall| inst_match;

    assign cp0_we = inst_mtc0;
    assign is_delayslot = 1'b0;
    assign waddr = inst_mtc0 ? inst[15:11] : 5'b0;
    assign raddr = inst_mfc0 ? inst[15:11] : 5'b0;

    assign excepttype = ~(id_pc[1:0] == 2'b0) ? `PCASSERT    :
                        ~inst_valid           ? `INVALIDINST :
                        inst_syscall          ? `SYSCALL     :
                        inst_break            ? `BREAK       :
                        inst_eret             ? `ERET        : `ZeroWord;

    assign except_info = {
        is_delayslot, // 49
        inst_cache,   // 48
        inst_tlbp,    // 47
        inst_tlbr,    // 46
        inst_tlbwi,   // 45
        inst_tlbwr,   // 44
        inst_mfc0,    // 43
        inst_mtc0,    // 42
        waddr,        // 41:37
        raddr,        // 36:32
        excepttype    // 31:0
    }; 


//output
    assign inst_info = {
        except_info,    // 98:49
        mem_op,         // 48:37
        hilo_op,        // 36:28
        alu_op,         // 27:16
        sel_alu_src1,   // 15:13
        sel_alu_src2,   // 12:9
        data_ram_en,    // 8
        data_ram_wen,   // 7
        rf_we,          // 6
        rf_waddr,       // 5:1
        sel_rf_res      // 0
    };

    assign inst_flag[0] = inst_div  | inst_divu | inst_mult | inst_multu | inst_mul | inst_match;
    assign inst_flag[1] = inst_lb   | inst_lbu  | inst_lh   | inst_lhu |
                          inst_lw   | inst_sb   | inst_sh   | inst_sw  |
                          inst_lwl  | inst_lwr  | inst_swl  | inst_swr ;
    assign inst_flag[2] = inst_mfc0 | inst_mtc0 | inst_syscall | inst_break | inst_eret |
                          inst_tlbp | inst_tlbr |  inst_tlbwi  | inst_tlbwr;

endmodule