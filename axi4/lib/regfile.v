`include "defines.vh"
module regfile(
    input wire clk,

    input wire we_i1,
    input wire we_i2,
    input wire [4:0] waddr_i1,
    input wire [4:0] waddr_i2,
    input wire [31:0] wdata_i1,
    input wire [31:0] wdata_i2,

    input wire [4:0] raddr1_i1,
    input wire [4:0] raddr2_i1,
    input wire [4:0] raddr1_i2,
    input wire [4:0] raddr2_i2,

    output wire [31:0] rdata1_i1,
    output wire [31:0] rdata2_i1,
    output wire [31:0] rdata1_i2,
    output wire [31:0] rdata2_i2
);

    reg [31:0] reg_array [31:0];

    // write
    always @ (posedge clk) begin
        reg_array[0] <= `ZeroWord;
        if (we_i1 && waddr_i1!=5'b0) begin
            reg_array[waddr_i1] <= wdata_i1;
        end
        if (we_i2 && waddr_i2!=5'b0) begin
            reg_array[waddr_i2] <= wdata_i2;
        end
    end

    // read
    assign rdata1_i1 = (raddr1_i1 == 5'b0) ? 32'b0 : reg_array[raddr1_i1];
    assign rdata2_i1 = (raddr2_i1 == 5'b0) ? 32'b0 : reg_array[raddr2_i1];
    assign rdata1_i2 = (raddr1_i2 == 5'b0) ? 32'b0 : reg_array[raddr1_i2];
    assign rdata2_i2 = (raddr2_i2 == 5'b0) ? 32'b0 : reg_array[raddr2_i2];

endmodule