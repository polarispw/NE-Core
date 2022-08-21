`include "defines.vh"
module decoder_2_4 (
    input wire [1:0] in,
    input wire [11:0] mem_op,
    input wire [`TTbits_wire] ex_result,
    input wire [`TTbits_wire] rf_rdata2,
    output reg [3:0] out,
    output reg [`TTbits_wire] data_sram_addr,
    output reg [`TTbits_wire] wdata
);

    wire inst_lb, inst_lbu, inst_lh, inst_lhu, inst_lw, inst_lwl, inst_lwr;
    wire inst_sb, inst_sh, inst_sw, inst_swl, inst_swr;
    assign {
        inst_lwl,inst_lwr, inst_swl, inst_swr,
        inst_lb, inst_lbu, inst_lh, inst_lhu,
        inst_lw, inst_sb, inst_sh, inst_sw
    } = mem_op;

    always @ (*) begin
        case(1'b1)
            inst_lb,inst_lbu:begin
                data_sram_addr <= ex_result; 
                wdata <= 32'b0;
                case(in)
                    2'b00:begin
                        out <= 4'b0001;
                    end
                    2'b01:begin
                        out <= 4'b0010;
                    end
                    2'b10:begin
                        out <= 4'b0100;
                    end
                    2'b11:begin
                        out <= 4'b1000;
                    end
                    default:begin
                        out <= 4'b0;
                    end
                endcase
            end
            inst_lh,inst_lhu:begin
                data_sram_addr <= ex_result; 
                wdata <= 32'b0;
                case(in)
                    2'b00:begin
                        out <= 4'b0011;
                    end
                    2'b10:begin
                        out <= 4'b1100;
                    end
                    default:begin
                        out <= 4'b0000;
                    end
                endcase
            end
            inst_lw:begin
                data_sram_addr <= ex_result; 
                wdata <= 32'b0;
                out <= 4'b1111;
            end
            inst_lwl:begin
                data_sram_addr <= {ex_result[31:2],2'b0}; 
                wdata <= 32'b0;
                case(in)
                    2'b00:begin
                        out <= 4'b0001;
                    end
                    2'b01:begin
                        out <= 4'b0011;
                    end
                    2'b10:begin
                        out <= 4'b0111;
                    end
                    2'b11:begin
                        out <= 4'b1111;
                    end
                    default:begin
                        out <= 4'b0;
                    end
                endcase
            end
            inst_lwr:begin
                data_sram_addr <= ex_result; 
                wdata <= 32'b0;
                case(in)
                    2'b00:begin
                        out <= 4'b1111;
                    end
                    2'b01:begin
                        out <= 4'b1110;
                    end
                    2'b10:begin
                        out <= 4'b1100;
                    end
                    2'b11:begin
                        out <= 4'b1000;
                    end
                    default:begin
                        out <= 4'b0;
                    end
                endcase
            end
            inst_sb:begin
                data_sram_addr <= ex_result; 
                wdata <= {4{rf_rdata2[7:0]}};
                case(in)
                    2'b00:begin
                        out <= 4'b0001;
                    end
                    2'b01:begin
                        out <= 4'b0010;
                    end
                    2'b10:begin
                        out <= 4'b0100;
                    end
                    2'b11:begin
                        out <= 4'b1000;
                    end
                    default:begin
                        out <= 4'b0;
                    end
                endcase
            end
            inst_sh:begin
                data_sram_addr <= ex_result; 
                wdata <= {2{rf_rdata2[15:0]}};
                case(in)
                    2'b00:begin
                        out <= 4'b0011;
                    end
                    2'b10:begin
                        out <= 4'b1100;
                    end
                    default:begin
                        out <= 4'b0000;
                    end
                endcase
            end
            inst_sw:begin
                data_sram_addr <= ex_result; 
                wdata <= rf_rdata2;
                out <= 4'b1111;
            end
            inst_swl:begin
               data_sram_addr <= {ex_result[31:2],2'b0}; 
               case(in)
                    2'b00:begin
                        out <= 4'b0001;
                        wdata <= {24'b0,rf_rdata2[31:24]};
                    end
                    2'b01:begin
                        out <= 4'b0011;
                        wdata <= {16'b0,rf_rdata2[31:16]};
                    end
                    2'b10:begin
                        out <= 4'b0111;
                        wdata <= {8'b0,rf_rdata2[31:8]};
                    end
                    2'b11:begin
                        out <= 4'b1111;
                        wdata <= rf_rdata2;
                    end
                    default:begin
                        out <= 4'b0;
                    end
                endcase
            end
            inst_swr:begin
                data_sram_addr <= ex_result; 
                case(in)
                    2'b00:begin
                        out <= 4'b1111;
                        wdata <= rf_rdata2;
                    end
                    2'b01:begin
                        out <= 4'b1110;
                        wdata <= {rf_rdata2[23:0],8'b0};
                    end
                    2'b10:begin
                        out <= 4'b1100;
                        wdata <= {rf_rdata2[15:0],16'b0};
                    end
                    2'b11:begin
                        out <= 4'b1000;
                        wdata <= {rf_rdata2[7:0],24'b0};
                    end
                    default:begin
                        out <= 4'b0;
                    end
                endcase
            end
            default:begin
                data_sram_addr <= 32'b0;
                wdata <= 32'b0;
                out <= 4'b0000;
            end
        endcase
    end
endmodule 