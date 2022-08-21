`include "defines.vh"
module match(
    input wire inst_match,
    input wire [31:0] rs_data,
    input wire [31:0] rt_data,
    output wire [31:0] match_result
);

    wire [7:0] target_str;

    assign target_str = rs_data[7:0];

    wire [7:0] rt_00;
    wire [7:0] rt_01;
    wire [7:0] rt_02;
    wire [7:0] rt_03;
    wire [7:0] rt_04;
    wire [7:0] rt_05;
    wire [7:0] rt_06;
    wire [7:0] rt_07;
    wire [7:0] rt_08;
    wire [7:0] rt_09;
    wire [7:0] rt_10;
    wire [7:0] rt_11;
    wire [7:0] rt_12;
    wire [7:0] rt_13;
    wire [7:0] rt_14;
    wire [7:0] rt_15;
    wire [7:0] rt_16;
    wire [7:0] rt_17;
    wire [7:0] rt_18;
    wire [7:0] rt_19;
    wire [7:0] rt_20;
    wire [7:0] rt_21;
    wire [7:0] rt_22;
    wire [7:0] rt_23;
    wire [7:0] rt_24;
    
    assign rt_00 = rt_data[ 7: 0];
    assign rt_01 = rt_data[ 8: 1];
    assign rt_02 = rt_data[ 9: 2];
    assign rt_03 = rt_data[10: 3];
    assign rt_04 = rt_data[11: 4];
    assign rt_05 = rt_data[12: 5];
    assign rt_06 = rt_data[13: 6];
    assign rt_07 = rt_data[14: 7];
    assign rt_08 = rt_data[15: 8];
    assign rt_09 = rt_data[16: 9];
    assign rt_10 = rt_data[17:10];
    assign rt_11 = rt_data[18:11];
    assign rt_12 = rt_data[19:12];
    assign rt_13 = rt_data[20:13];
    assign rt_14 = rt_data[21:14];
    assign rt_15 = rt_data[22:15];
    assign rt_16 = rt_data[23:16];
    assign rt_17 = rt_data[24:17];
    assign rt_18 = rt_data[25:18];
    assign rt_19 = rt_data[26:19];
    assign rt_20 = rt_data[27:20];
    assign rt_21 = rt_data[28:21];
    assign rt_22 = rt_data[29:22];
    assign rt_23 = rt_data[30:23];
    assign rt_24 = rt_data[31:24];

    assign match_result = rt_00==target_str ? 32'h0 :
                          rt_01==target_str ? 32'h1 :
                          rt_02==target_str ? 32'h2 :
                          rt_03==target_str ? 32'h3 :
                          rt_04==target_str ? 32'h4 :
                          rt_05==target_str ? 32'h5 :
                          rt_06==target_str ? 32'h6 :
                          rt_07==target_str ? 32'h7 :
                          rt_08==target_str ? 32'h8 :
                          rt_09==target_str ? 32'h9 :
                          rt_10==target_str ? 32'ha :
                          rt_11==target_str ? 32'hb :
                          rt_12==target_str ? 32'hc :
                          rt_13==target_str ? 32'hd :
                          rt_14==target_str ? 32'he :
                          rt_15==target_str ? 32'hf :
                          rt_16==target_str ? 32'h10:
                          rt_17==target_str ? 32'h11:
                          rt_18==target_str ? 32'h12:
                          rt_19==target_str ? 32'h13:
                          rt_20==target_str ? 32'h14:
                          rt_21==target_str ? 32'h15:
                          rt_22==target_str ? 32'h16:
                          rt_23==target_str ? 32'h17:
                          rt_24==target_str ? 32'h18: 32'hffff_ffff;


endmodule