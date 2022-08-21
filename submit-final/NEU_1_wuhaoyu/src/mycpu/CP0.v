`include "lib/defines.vh"
module CP0(
    input wire rst,
    input wire clk,
    input wire [5:0] int,
    input wire [`EXCEPT_WD-1:0] exceptinfo_i1,
    input wire [`EXCEPT_WD-1:0] exceptinfo_i2,
    input wire [31:0] current_pc_i1,
    input wire [31:0] current_pc_i2,
    input wire [31:0] rt_rdata_i1,
    input wire [31:0] rt_rdata_i2,

    output wire [31:0] o_rdata,
    output wire [32:0] CP0_to_ctrl_bus,
    output wire caused_by_i1, 
    output wire caused_by_i2,

    output reg [31:0] entrylo0,
    output reg [31:0] entrylo1,
    output reg [31:0] entryhi,
    output reg [31:0] index,

    input  wire d_refill,
    input  wire d_invalid,
    input  wire d_modify,
    input  wire op_load,
    input  wire op_store,

    // tlb
    input wire        op_tlbp,
    input wire        op_tlbr,
    input wire        op_tlbwi,
    input wire [31:0] tlb_index,
    input wire [31:0] tlb_entryhi,
    input wire [31:0] tlb_entrylo0,
    input wire [31:0] tlb_entrylo1,
    input wire [31:0] tlbexc_pc
);


    reg [31:0] badvaddr;
    reg [31:0] count;//$9
    reg [31:0] status;
    reg [31:0] cause;
    reg [31:0] epc;
    reg [31:0] compare;//$11
    reg [31:0] configr;
    reg [31:0] cp0_rdata;

    wire [31:0] current_pc;
    wire [31:0] rt_rdata;
    wire [31:0] bad_addr;
    wire is_delayslot;
    wire except_happen;
    wire [4:0] waddr, raddr;
    wire [31:0] excepttype_i, excepttype;
    wire [`EXCEPT_WD-1:0] exceptinfo;

    assign except_happen = (exceptinfo_i1[31:0] | exceptinfo_i2[31:0]) != `ZeroWord            ? 1'b1 :
                           (((cause[15:8] & status[15:8]) != 8'b0) && status[0] && ~status[1]) ? 1'b1 :
                           (d_refill | d_invalid | d_modify) & (current_pc_i1==tlbexc_pc | current_pc_i2==tlbexc_pc) ? 1'b1 : 1'b0;

    assign excepttype    = (((cause[15:8] & status[15:8]) != 8'b0) && status[0] && ~status[1]) ? `INTERRUPT :
                           d_refill  & op_load  ? `TLBLR :
                           d_refill  & op_store ? `TLBSR :
                           d_invalid & op_load  ? `TLBLI :
                           d_invalid & op_store ? `TLBSI :
                           d_modify             ? `TLBMOD: excepttype_i;

    assign caused_by_i1 = (d_refill | d_invalid | d_modify) & (current_pc_i1==tlbexc_pc ) ? 1'b1 :
                          exceptinfo_i1[31:0]==`ZeroWord ? 1'b0 : 1'b1;
    assign caused_by_i2 = (d_refill | d_invalid | d_modify) & (current_pc_i2==tlbexc_pc ) ? 1'b1 :
                          exceptinfo_i2[31:0]==`ZeroWord ? 1'b0 : 1'b1;

    assign exceptinfo = caused_by_i2 ? exceptinfo_i2 : exceptinfo_i1;
    assign current_pc = caused_by_i2 ? current_pc_i2 : current_pc_i1;
    assign rt_rdata   = rt_rdata_i1;
    assign bad_addr   = caused_by_i2 ? rt_rdata_i2 : rt_rdata_i1;

    wire inst_cache, inst_tlbp, inst_tlbr, inst_tlbwi, inst_tlbwr, inst_mfc0, inst_mtc0;

    assign {
        is_delayslot, // 49
        inst_cache,   // 48
        inst_tlbp,    // 47
        inst_tlbr,    // 46
        inst_tlbwi,   // 45
        inst_tlbwr,   // 45
        inst_mfc0,    // 43
        inst_mtc0,    // 42
        waddr,        // 41:37
        raddr,        // 36:32
        excepttype_i  // 31:0
    } = exceptinfo;
    wire we_i = inst_mtc0;

    reg tick;
    always @ (posedge clk) begin
        if (rst) begin
            tick <= 1'b0;
        end
        else begin
            tick <= ~tick;
        end
    end

    always @ (posedge clk) begin
        if (rst) begin
            badvaddr <= `ZeroWord;
            count    <= `ZeroWord;
            status   <= {4'b0001,28'd0};
            cause    <= `ZeroWord;
            epc      <= `ZeroWord;
            compare  <= `ZeroWord;
            entrylo0 <= `ZeroWord;
            entrylo1 <= `ZeroWord;
            entryhi  <= `ZeroWord;
            index    <= `ZeroWord;
            configr  <= 32'b1_000000000000000_0_00_000_001_0000_010;
        end

        else begin
            if (tick) begin
                count <= count + 1'b1;
            end
            cause[15:10] <= int;

            if (compare != 32'b0 && count == compare) begin
                cause[15] <= 1'b1;
            end

            if (inst_tlbr) begin
                entryhi  <= {tlb_entryhi[31:13],5'b0,tlb_entryhi[7:0]};
                entrylo0 <= {6'b0,tlb_entrylo0[25:0]};
                entrylo1 <= {6'b0,tlb_entrylo1[25:0]};
            end

            if (inst_tlbp) begin
                index <= {tlb_index[31],27'b0,tlb_index[3:0]};
            end

            if (we_i) begin
                case (waddr)
                    `CP0_REG_COUNT:begin
                        count <= rt_rdata;
                    end
                    `CP0_REG_STATUS:begin
                        status <= rt_rdata;
                    end
                    `CP0_REG_CAUSE:begin
                        cause <= rt_rdata;
                    end
                    `CP0_REG_EPC:begin
                        epc <= rt_rdata;
                    end
                    `CP0_REG_COMPARE:begin
                        compare <= rt_rdata;
                        cause[30] <= 1'b0;
                    end
                    `CP0_REG_INDEX:begin
                        index <= {28'b0,rt_rdata[3:0]};
                    end
                    `CP0_REG_ENTRYLO0:begin
                        entrylo0 <= {6'b0,rt_rdata[25:0]};
                    end
                    `CP0_REG_ENTRYLO1:begin
                        entrylo1 <= {6'b0,rt_rdata[25:0]};
                    end
                    `CP0_REG_ENTRYHI:begin
                        entryhi <= {rt_rdata[31:13],5'b0,rt_rdata[7:0]};
                    end 
                    default:begin
                        
                    end
                endcase
            end

            if(except_happen) begin 
                if (~status[1] && (excepttype!=`ERET) && excepttype!=`TLBmark) begin
                    status[1] <= 1'b1;
                    cause[31] <= is_delayslot ? 1'b1 : 1'b0;
                    epc       <= is_delayslot ? current_pc-32'h4 : current_pc;
                end
                case (excepttype)
                    `INTERRUPT:begin
                        cause[`ExcCode] <= 5'h0;
                        badvaddr <= current_pc; 
                    end
                    `PCASSERT:begin
                        cause[`ExcCode] <= 5'h4;
                        badvaddr <= current_pc; 
                    end
                    `LOADASSERT:begin
                        cause[`ExcCode] <= 5'h4;
                        badvaddr <= bad_addr; 
                    end
                    `STOREASSERT:begin
                        cause[`ExcCode] <= 5'h5;
                        badvaddr <= bad_addr; 
                    end
                    `SYSCALL:begin
                        cause[`ExcCode] <= 5'h8;
                    end
                    `BREAK:begin
                        cause[`ExcCode] <= 5'h9;
                    end
                    `INVALIDINST:begin
                        cause[`ExcCode] <= 5'ha;
                    end
                    `OV:begin
                        cause[`ExcCode] <= 5'hc;
                    end
                    `TLBLR:begin
                        cause[`ExcCode] <= 5'h2; 
                        if(op_load) begin
                            badvaddr <= bad_addr;
                            entryhi[31:13] <= bad_addr[31:13];// 如果pc和data同时出例外要考虑
                        end
                        else begin
                            badvaddr <= current_pc;
                            entryhi[31:13] <= current_pc[31:13];// 如果pc和data同时出例外要考虑
                        end
                    end
                    `TLBLI:begin
                        cause[`ExcCode] <= 5'h2; 
                        if(op_load) begin
                            badvaddr <= bad_addr;
                            entryhi[31:13] <= bad_addr[31:13];// 如果pc和data同时出例外要考虑
                        end
                        else begin
                            badvaddr <= current_pc;
                            entryhi[31:13] <= current_pc[31:13];// 如果pc和data同时出例外要考虑
                        end
                    end
                    `TLBSR:begin
                        cause[`ExcCode] <= 5'h3;
                        badvaddr <= bad_addr;
                        entryhi[31:13] <= bad_addr[31:13];
                    end
                    `TLBSI:begin
                        cause[`ExcCode] <= 5'h3;
                        badvaddr <= bad_addr;
                        entryhi[31:13] <= bad_addr[31:13];
                    end
                    `TLBMOD:begin
                        cause[`ExcCode] <= 5'h1;
                        badvaddr <= bad_addr;
                        entryhi[31:13] <= bad_addr[31:13];
                    end
                    `ERET:begin
                        status[1] <= 1'b0;
                    end
                    default:begin
                        
                    end
                endcase
            end
        end
    end
    
    always @ (*) begin
        if (rst) begin
            cp0_rdata <= `ZeroWord;
        end
        else begin
            case (raddr)
                `CP0_REG_BADADDR:begin
                    cp0_rdata <= badvaddr;
                end 
                `CP0_REG_COUNT:begin
                    cp0_rdata <= count;
                end
                `CP0_REG_STATUS:begin
                    cp0_rdata <= status;
                end
                `CP0_REG_CAUSE:begin
                    cp0_rdata <= cause;
                end
                `CP0_REG_EPC:begin
                    cp0_rdata <= epc;
                end
                `CP0_REG_INDEX:begin
                    cp0_rdata <= index;
                end
                `CP0_REG_ENTRYLO0:begin
                    cp0_rdata <= entrylo0;
                end
                `CP0_REG_ENTRYLO1:begin
                    cp0_rdata <= entrylo1;
                end
                `CP0_REG_ENTRYHI:begin
                    cp0_rdata <= entryhi;
                end
                default:begin
                    cp0_rdata <= `ZeroWord;
                end
            endcase
        end
    end

    wire [31:0] new_pc;
    assign o_rdata = cp0_rdata;
    assign new_pc  = excepttype==`ERET    ? epc[31:0]    :
                     excepttype==`TLBLR   ? 32'hbfc00200 :
                     excepttype==`TLBSR   ? 32'hbfc00200 :
                     excepttype==`TLBmark ? current_pc_i1 :
                     except_happen        ? 32'hbfc00380 : `ZeroWord;
    assign CP0_to_ctrl_bus = {except_happen, new_pc};

endmodule