`include "defines.vh"
module Instbuffer(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire stop_pop,
    input wire issue_i,      //whether inst launched
    input wire issue_mode_i, //issue mode of ID
    // input wire [32:0] br_bus,

    input wire [`InstBus] inst1_i,
    input wire [`InstBus] inst2_i,
    input wire [`InstAddrBus] inst1_addr_i,
    input wire [`InstAddrBus] inst2_addr_i, 
    input wire inst1_valid_i,
    input wire inst2_valid_i,

    output wire [`InstBus]  inst1_o,
    output wire [`InstBus]  inst2_o,
    output wire [`InstAddrBus]  inst1_addr_o, 
    output wire [`InstAddrBus]  inst2_addr_o,
    output wire inst1_valid_o,
    output wire inst2_valid_o,
    // output wire br_pc_found,
    // output wire [31:0] br_target_addr, 
    output wire buffer_full_o
);

// fifo structure
    reg [`InstBus] FIFO_data[`FIFOSize-1:0]; // inst
    reg [`InstBus] FIFO_addr[`FIFOSize-1:0]; // pc
    reg [`FIFOSizebits-1:0] tail; // where to write
    reg [`FIFOSizebits-1:0] head; // where to read
    reg [`FIFOSize-1:0] FIFO_valid; // validation

// operate fifo
    always@(posedge clk)begin
        if(rst | flush)begin
            tail <= `FIFOSizebits'h0;
            head <= `FIFOSizebits'h0;
			FIFO_valid <= `FIFOSize'h0;
        end
        else if(inst1_valid_i == `Valid && inst2_valid_i == `Invalid) begin
            FIFO_data[tail]  <= inst1_i;
            FIFO_addr[tail]  <= inst1_addr_i; 
            FIFO_valid[tail] <= `Valid;
            tail <= tail + 1;
		end
        else if(inst1_valid_i == `Invalid && inst2_valid_i == `Valid) begin
            FIFO_data[tail]  <= inst2_i;
            FIFO_addr[tail]  <= inst2_addr_i;
            FIFO_valid[tail] <= `Valid;
            tail <= tail + 1;
        end 
        else if(inst1_valid_i == `Valid && inst2_valid_i == `Valid) begin 
            FIFO_data[tail] <= inst1_i;
            FIFO_data[tail+`FIFOSizebits'h1] <= inst2_i;
            FIFO_addr[tail] <= inst1_addr_i; 
            FIFO_addr[tail+`FIFOSizebits'h1] <= inst2_addr_i; 
            FIFO_valid[tail] <= `Valid;
            FIFO_valid[tail+`FIFOSizebits'h1] <= `Valid;
            tail <= tail + 2;
        end

        if( issue_i == `Valid && issue_mode_i == `SingleIssue )begin
            FIFO_valid[head] <= `Invalid;
            head <= head + 1;
        end
        else if( issue_i == `Valid && issue_mode_i == `DualIssue )begin
            FIFO_valid[head] <= `Invalid;
            FIFO_valid[head+`FIFOSizebits'h1] <= `Invalid;
            head <= head + 2;
        end
    end	


// output	
	assign inst1_o       = FIFO_data[head]; 
	assign inst2_o       = FIFO_data[head+`FIFOSizebits'h1];
	
	assign inst1_addr_o  = FIFO_addr[head];
	assign inst2_addr_o  = FIFO_addr[head+`FIFOSizebits'h1];

    assign inst1_valid_o = stop_pop ? 1'b0 : FIFO_valid[head];
    assign inst2_valid_o = stop_pop ? 1'b0 : FIFO_valid[head+`FIFOSizebits'h1];

	assign buffer_full_o = FIFO_valid[tail+`FIFOSizebits'h5];

endmodule