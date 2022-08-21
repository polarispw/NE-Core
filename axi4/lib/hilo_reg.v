`include "defines.vh"
module hilo_reg(
    input wire clk,
    input wire rst,

    input wire hi_we_i1,
    input wire lo_we_i1,
    input wire hi_we_i2,
    input wire lo_we_i2,
    input wire [31:0] hi_i_i1,
    input wire [31:0] lo_i_i1,
    input wire [31:0] hi_i_i2,
    input wire [31:0] lo_i_i2,

    output wire [31:0] hi_o,
    output wire [31:0] lo_o
);

    reg [31:0] hi_reg, lo_reg;

    // write 
    always @ (posedge clk) begin
        if (rst) begin
            hi_reg <= 32'b0;
            lo_reg <= 32'b0;
        end
        else if (hi_we_i1 & lo_we_i1) begin
            hi_reg <= hi_i_i1;
            lo_reg <= lo_i_i1;
        end
        else if (hi_we_i1 & ~lo_we_i1) begin
            hi_reg <= hi_i_i1;
        end 
        else if (~hi_we_i1 & lo_we_i1) begin
            lo_reg <= lo_i_i1;
        end
        else if (hi_we_i2 & lo_we_i2) begin
            hi_reg <= hi_i_i2;
            lo_reg <= lo_i_i2;
        end
        else if (hi_we_i2 & ~lo_we_i2) begin
            hi_reg <= hi_i_i2;
        end 
        else if (~hi_we_i1 & lo_we_i1) begin
            lo_reg <= lo_i_i2;
        end
    end

    assign hi_o = hi_reg;
    assign lo_o = lo_reg;

endmodule