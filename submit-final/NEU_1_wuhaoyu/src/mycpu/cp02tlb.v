`include "lib/defines.vh"
module CTRelay(
    input  wire rst,
    input  wire clk,
    input  wire flush,

    input  wire [31:0] cp0_index_c2r,
    input  wire [31:0] cp0_entrylo0_c2r,
    input  wire [31:0] cp0_entrylo1_c2r,
    input  wire [31:0] cp0_entryhi_c2r,
    input  wire op_tlbp_c2r, 
    input  wire op_tlbr_c2r, 
    input  wire op_tlbwi_c2r,

    output reg  [31:0] cp0_index_r2t,
    output reg  [31:0] cp0_entrylo0_r2t,
    output reg  [31:0] cp0_entrylo1_r2t,
    output reg  [31:0] cp0_entryhi_r2t,
    output reg  op_tlbp_r2t, 
    output reg  op_tlbr_r2t, 
    output reg  op_tlbwi_r2t,

    input  wire [31:0] tlb_index_t2r,
    input  wire [31:0] tlb_entryhi_t2r,
    input  wire [31:0] tlb_entrylo0_t2r,
    input  wire [31:0] tlb_entrylo1_t2r,
    input  wire i_refill_t2r,
    input  wire i_invalid_t2r,
    input  wire d_refill_t2r,
    input  wire d_invalid_t2r,
    input  wire d_modify_t2r, 

    output reg  [31:0] tlb_index_r2c,
    output reg  [31:0] tlb_entryhi_r2c,
    output reg  [31:0] tlb_entrylo0_r2c,
    output reg  [31:0] tlb_entrylo1_r2c,
    output reg  i_refill_r2c,
    output reg  i_invalid_r2c,
    output reg  d_refill_r2c,
    output reg  d_invalid_r2c,
    output reg  d_modify_r2c,

    input  wire [31:0] inst_sram_addr,
    input  wire [31:0] data_sram_addr,
    input  wire [31:0] data_sram_pc,

    output reg  [31:0] tlbexc_iaddr,
    output reg  [31:0] tlbexc_daddr,
    output reg  [31:0] tlbexc_dpc,
    output wire stallreq_for_tlb
);
// 对于tlb指令涉及的操作在此进行交换，当前发出的请求在其后的第二个周期返回结果（| tlb op | ---- | res back |）
// 对于可能出现的例外情况，在此模块进行记录异常类型和造成例外的地址，并分发给相应的流水段
// 由取址和访存引起的例外在下一周期才会返回给流水线，因此取址例外分给ID段处理，访存例外直接交给在MEM段的CP0

reg [1:0] tlb_op_stage;

// relay to TLB
always @(posedge clk ) begin
    if (rst) begin
        cp0_index_r2t    <= `ZeroWord;
        cp0_entrylo0_r2t <= `ZeroWord;
        cp0_entrylo1_r2t <= `ZeroWord;
        cp0_entryhi_r2t  <= `ZeroWord;
        op_tlbp_r2t      <= 1'b0;
        op_tlbr_r2t      <= 1'b0;
        op_tlbwi_r2t     <= 1'b0;
        tlb_op_stage     <= 2'b00;
    end
    else if(flush) begin
        op_tlbp_r2t      <= 1'b0;
        op_tlbr_r2t      <= 1'b0;
        op_tlbwi_r2t     <= 1'b0;
        tlb_op_stage     <= 2'b00;
    end
    else begin
        cp0_index_r2t    <= cp0_index_c2r;
        cp0_entrylo0_r2t <= cp0_entrylo0_c2r;
        cp0_entrylo1_r2t <= cp0_entrylo1_c2r;
        cp0_entryhi_r2t  <= cp0_entryhi_c2r;
        op_tlbp_r2t      <= op_tlbp_c2r;
        op_tlbr_r2t      <= op_tlbr_c2r;
        op_tlbwi_r2t     <= op_tlbwi_c2r;
    end

    if((op_tlbp_c2r | op_tlbr_c2r | op_tlbwi_c2r) & tlb_op_stage==2'b00) begin
        tlb_op_stage <= 2'b01;// 指令抄送tlb
    end
    else if(tlb_op_stage==2'b01) begin
        tlb_op_stage <= 2'b10;// tlb发回信息
    end
    else if(tlb_op_stage==2'b10) begin
        tlb_op_stage <= 2'b11;// 信息抄送cp0
    end
    else if(tlb_op_stage==2'b11) begin
        tlb_op_stage <= 2'b00;// stall释放
    end
end
assign stallreq_for_tlb = ((op_tlbp_c2r | op_tlbr_c2r | op_tlbwi_c2r) & tlb_op_stage==2'b00) ? 1'b1 :
                          tlb_op_stage==2'b01 ? 1'b1 :
                          tlb_op_stage==2'b10 ? 1'b1 : 1'b0;

// relay to CP0
always @(posedge clk ) begin
    if (rst | flush) begin
        tlb_index_r2c    <= `ZeroWord;
        tlb_entrylo0_r2c <= `ZeroWord;
        tlb_entrylo1_r2c <= `ZeroWord;
        tlb_entryhi_r2c  <= `ZeroWord;
    end
    else begin
        tlb_index_r2c    <= tlb_index_t2r;
        tlb_entrylo0_r2c <= tlb_entrylo0_t2r;
        tlb_entrylo1_r2c <= tlb_entrylo1_t2r;
        tlb_entryhi_r2c  <= tlb_entryhi_t2r;
    end
end


// except part
reg keep_first_pc;
always @(posedge clk ) begin
    if (rst | flush) begin
        i_refill_r2c  <= 1'b0;
        i_invalid_r2c <= 1'b0;
        d_refill_r2c  <= 1'b0;
        d_invalid_r2c <= 1'b0;
        d_modify_r2c  <= 1'b0;
        keep_first_pc <= 1'b0;
        tlbexc_iaddr  <= `ZeroWord;
        tlbexc_daddr  <= `ZeroWord;
        tlbexc_dpc    <= `ZeroWord;
    end
    else if(i_refill_t2r & ~keep_first_pc) begin
        i_refill_r2c <= 1'b1;
        keep_first_pc <= 1'b1;
        tlbexc_iaddr <= inst_sram_addr;
    end
    else if(i_invalid_t2r & ~keep_first_pc) begin
        i_invalid_r2c <= 1'b1;
        keep_first_pc <= 1'b1;
        tlbexc_iaddr <= inst_sram_addr;
    end
    else if(d_refill_t2r) begin
        d_refill_r2c <= 1'b1;
        tlbexc_daddr <= data_sram_addr;
        tlbexc_dpc   <= data_sram_pc;
    end
    else if(d_invalid_t2r) begin
        d_invalid_r2c <= 1'b1;
        tlbexc_daddr <= data_sram_addr;
        tlbexc_dpc   <= data_sram_pc;
    end
    else if(d_modify_t2r) begin
        d_modify_r2c <= 1'b1;
        tlbexc_daddr <= data_sram_addr;
        tlbexc_dpc   <= data_sram_pc;
    end
end


endmodule