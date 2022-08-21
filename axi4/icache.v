`include "lib/defines.vh"
`define TAG_WD 21
`define INDEX_WD 6
`define LRU_WD 64
`define OFFSET_WD 6
module icache(
    input wire clk,
    input wire resetn,
    output wire stallreq,

    input wire inst_sram_en,
    input wire [3:0] inst_sram_wen,
    input wire [31:0] inst_sram_addr,
    input wire [31:0] inst_sram_wdata,
    output wire [63:0] inst_sram_rdata,

    output wire rd_req,
    output wire [31:0] rd_addr,

    input wire reload,
    input wire [511:0] cacheline_new
);
    reg [`LRU_WD-1:0] lru;
    wire [`TAG_WD-2:0] tag;
    wire [`INDEX_WD-1:0] index;
    wire [`OFFSET_WD-1:0] offset;
    wire hit;
    wire miss;
    wire [63:0] rdata_way0, rdata_way1;

    wire hit_way0, hit_way1;
    reg [1:0] hit_r;
    wire [`TAG_WD-1:0] tag_way0, tag_way1;
    always @ (posedge clk) begin
        if (!resetn) begin
            lru <= `LRU_WD'b0;
        end
        else if (hit_way0) begin
            lru[index] <= 1'b1;
        end
        else if (hit_way1) begin
            lru[index] <= 1'b0;
        end
        else if (reload) begin
            lru[index] <= ~lru[index];
        end
    end

    icache_tag u0_tag(
        .clk    (clk        ),
        .we     (reload&~lru[index]     ),
        .a      (index      ),
        .d      ({1'b1, tag}),
        .spo    (tag_way0   )
    );
    icache_tag u1_tag(
        .clk    (clk        ),
        .we     (reload&lru[index]     ),
        .a      (index      ),
        .d      ({1'b1, tag}),
        .spo    (tag_way1   )
    );

    assign {tag, index, offset} = inst_sram_addr;
    assign hit_way0 = inst_sram_en & {1'b1, tag} == tag_way0;
    assign hit_way1 = inst_sram_en & {1'b1, tag} == tag_way1;
    assign hit = hit_way0 | hit_way1;
    assign miss = inst_sram_en & ~hit;
    assign stallreq = miss;
    assign rd_req = inst_sram_en & miss;
    assign rd_addr = {inst_sram_addr[31:6],6'b0};

    double_line u0_double_line(
    	.clk           (clk                 ),
        .en            (inst_sram_en        ),
        .addr          (inst_sram_addr      ),
        .dout          (rdata_way0          ),
        .reload        (reload&~lru[index]              ),
        .cacheline_new (cacheline_new       )
    );

    double_line u1_double_line(
    	.clk           (clk                 ),
        .en            (inst_sram_en        ),
        .addr          (inst_sram_addr      ),
        .dout          (rdata_way1          ),
        .reload        (reload&lru[index]              ),
        .cacheline_new (cacheline_new       )
    );

    always @ (posedge clk) begin
        hit_r <= {hit_way1, hit_way0};
    end
    assign inst_sram_rdata = {64{hit_r[0]}} & rdata_way0 
                            |{64{hit_r[1]}} & rdata_way1;
    
endmodule