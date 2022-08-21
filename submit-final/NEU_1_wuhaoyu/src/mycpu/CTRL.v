`include "lib/defines.vh"
module CTRL(
    input wire rst,
    input wire stallreq_for_ex,
    input wire stallreq_for_load,
    input wire stallreq_for_excp0,
    input wire stallreq_for_dtcp0,
    input wire stallreq_for_fifo,
    input wire stallreq_for_tlb,
    input wire stallreq_for_cache,
    input wire [`CP0_TO_CTRL_WD-1:0] CP0_to_ctrl_bus,

    output reg flush,
    output reg [31:0] new_pc,
    output reg [`STALLBUS_WD-1:0] stall
);  
    always @ (*) begin
        if (rst | flush) begin
            stall = `STALLBUS_WD'b0;
        end
        else if (stallreq_for_ex | stallreq_for_cache | stallreq_for_tlb) begin
            stall = `STALLBUS_WD'b1111_111;
        end
        else if (stallreq_for_dtcp0 | stallreq_for_excp0 | stallreq_for_load) begin
            stall = `STALLBUS_WD'b0000_101;
        end
        else if (stallreq_for_fifo) begin
            stall = `STALLBUS_WD'b0000_001;
        end
        else begin
            stall = `STALLBUS_WD'b0000_000;
        end
    end

    always @ (*) begin
        if (rst) begin
            flush <= 1'b0;
            new_pc <= 32'b0;
        end
        else if ((CP0_to_ctrl_bus[32] == 1'b1) && ~stallreq_for_cache) begin
            flush <= 1'b1;
            new_pc <= CP0_to_ctrl_bus[31:0];
        end
        else begin
            flush <= 1'b0;
            new_pc <= 32'b0;
        end
    end
endmodule