`include "lib/defines.vh"
module mycpu_top(
    input wire aclk,
    input wire aresetn,
    input wire [5:0] ext_int,

    output wire[3:0]   arid,
    output wire[31:0]  araddr,
    output wire[3:0]   arlen,
    output wire[2:0]   arsize,
    output wire[1:0]   arburst,
    output wire[1:0]   arlock,
    output wire[3:0]   arcache,
    output wire[2:0]   arprot,
    output wire        arvalid,
    input  wire        arready,

    input  wire[3:0]   rid,
    input  wire[31:0]  rdata,
    input  wire[1:0]   rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,

    output wire[3:0]   awid,
    output wire[31:0]  awaddr,
    output wire[3:0]   awlen,
    output wire[2:0]   awsize,
    output wire[1:0]   awburst,
    output wire[1:0]   awlock,
    output wire[3:0]   awcache,
    output wire[2:0]   awprot,
    output wire        awvalid,
    input  wire        awready,

    output wire[3:0]   wid,
    output wire[31:0]  wdata,
    output wire[3:0]   wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,

    input  wire[3:0]   bid,
    input  wire[1:0]   bresp,
    input  wire        bvalid,
    output wire        bready,

    output wire [31:0] debug_wb_pc,
    output wire [3 :0] debug_wb_rf_wen,
    output wire [4 :0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata 
);

    //inst sram
    wire        inst_sram_en;
    wire [ 3:0] inst_sram_wen;
    wire [31:0] inst_sram_addr;
    wire [31:0] inst_sram_wdata;
    wire [63:0] inst_sram_rdata;

    //data sram
    wire        data_sram_en;
    wire [ 3:0] data_sram_wen;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire [31:0] data_sram_rdata;

    // icache tag
    wire icache_cached;
    wire icache_uncached;
    wire icache_refresh;
    wire icache_miss;
    wire [31:0] icache_raddr;
    wire icache_write_back;
    wire [31:0] icache_waddr;
    wire [`HIT_WIDTH-1:0] icache_hit;
    wire [`LRU_WIDTH-1:0] icache_lru;

    // icache data
    wire [`CACHELINE_WIDTH-1:0] icache_cacheline_new;
    wire [`CACHELINE_WIDTH-1:0] icache_cacheline_old;

    // dcache tag
    wire dcache_cached;
    wire dcache_uncached;
    wire dcache_refresh;
    wire dcache_miss;
    wire [31:0] dcache_raddr;
    wire dcache_write_back;
    wire [31:0] dcache_waddr;
    wire [`HIT_WIDTH-1:0] dcache_hit;
    wire [`LRU_WIDTH-1:0] dcache_lru;

    // dcache data
    wire [`CACHELINE_WIDTH-1:0] dcache_cacheline_new;
    wire [`CACHELINE_WIDTH-1:0] dcache_cacheline_old;

    // uncache tag
    wire uncache_refresh;
    wire uncache_en;
    wire [3:0] uncache_wen;
    wire [31:0] uncache_addr;
    wire [31:0] uncache_wdata;
    wire uncache_hit;
    
    // uncache data
    wire [31:0] uncache_rdata;

    wire stallreq_from_icache;
    wire stallreq_from_dcache;
    wire stallreq_from_uncache;

    // tlb
    wire [19:0] inst_tag;
    wire [19:0] data_tag;
    wire [31:0] cp0_index;
    wire [31:0] cp0_entrylo0;
    wire [31:0] cp0_entrylo1;
    wire [31:0] cp0_entryhi;
    wire [31:0] tlb_index;
    wire [31:0] tlb_entrylo0;
    wire [31:0] tlb_entrylo1;
    wire [31:0] tlb_entryhi;
    wire i_refill, i_invalid, d_refill, d_invalid, d_modify;
    wire op_tlbp, op_tlbr, op_tlbwi;

    mycpu_core u_mycpu_core(
    	.clk               (aclk              ),
        .rst               (~aresetn          ),
        .int               (ext_int           ),
        .stallreq_icache   (stallreq_from_icache   ),
        .stallreq_dcache   (stallreq_from_dcache   ),
        .stallreq_uncache  (stallreq_from_uncache  ),

        .inst_sram_en      (inst_sram_en      ),
        .inst_sram_wen     (inst_sram_wen     ),
        .inst_sram_addr    (inst_sram_addr    ),
        .inst_sram_wdata   (inst_sram_wdata   ),
        .inst_sram_rdata   (inst_sram_rdata   ),
        
        .data_sram_en      (data_sram_en      ),
        .data_sram_wen     (data_sram_wen     ),
        .data_sram_addr    (data_sram_addr    ),
        .data_sram_wdata   (data_sram_wdata   ),
        .data_sram_rdata   (data_sram_rdata   ),

        .cp0_entrylo0      (cp0_entrylo0      ),
        .cp0_entrylo1      (cp0_entrylo1      ),
        .cp0_entryhi       (cp0_entryhi       ),
        .cp0_index         (cp0_index         ),

        .op_tlbp           (op_tlbp           ),
        .op_tlbr           (op_tlbr           ),
        .op_tlbwi          (op_tlbwi          ),
        .tlb_index         (tlb_index         ),
        .tlb_entryhi       (tlb_entryhi       ),
        .tlb_entrylo0      (tlb_entrylo0      ),
        .tlb_entrylo1      (tlb_entrylo1      ),
        .i_refill          (i_refill          ),
        .i_invalid         (i_invalid         ),
        .d_refill          (d_refill          ),
        .d_invalid         (d_invalid         ),
        .d_modify          (d_modify          ),
        
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata )
    );


    tlb 
    #(
        .TLBNUM (16)
    )
    u_tlb(
    	.clk           (aclk                       ),
        .rst           (~aresetn                   ), 
        .k0            (3'b011                     ),

        .inst_en       (inst_sram_en               ),
        .inst_vaddr    (inst_sram_addr             ),
        .inst_uncached (icache_uncached            ),   //  1 - uncached | 0 - cached
        .inst_tag      (inst_tag                   ),

        .data_ren      (data_sram_en&data_sram_wen==4'b0),
        .data_wen      (data_sram_en&data_sram_wen!=4'b0),
        .data_vaddr    (data_sram_addr             ),
        .data_uncached (dcache_uncached            ),
        .data_tag      (data_tag                   ),
        .p_index       (tlb_index                  ),

        .we            (op_tlbwi                   ),
        .w_index       (cp0_index[3:0]             ),
        .w_hi          (cp0_entryhi                ),
        .w_lo0         (cp0_entrylo0               ),
        .w_lo1         (cp0_entrylo1               ),
        
        .r_index       (cp0_index[3:0]             ),
        .r_hi          (tlb_entryhi                ),
        .r_lo0         (tlb_entrylo0               ),
        .r_lo1         (tlb_entrylo1               ),

        .i_refill      (i_refill                   ),    // excepttype[1]
        .i_invalid     (i_invalid                  ),    // excepttype[2]
        .d_refill      (d_refill                   ),    // excepttype[3]
        .d_invalid     (d_invalid                  ),    // excepttype[4]
        .d_modify      (d_modify                   ),    // excepttype[5]

        .op_tlbp       (op_tlbp                    ),
        .op_tlbr       (1'b0                       ),
        .op_tlbwi      (1'b0                       ),
        .op_tlbwr      (1'b0                       )
    );

    wire [31:0] inst_sram_addr_mmu;
    assign inst_sram_addr_mmu = {inst_tag,inst_sram_addr[11:0]};
    // mmu u_inst_mmu(
    // 	.addr_i  (inst_sram_addr  ),
    //     .addr_o  (inst_sram_addr_mmu  ),
    //     .cache_v (icache_cached )
    // );
    
    cache_tag_v5 u_icache_tag(
    	.clk        (aclk                   ),
        .rst        (~aresetn               ),
        .flush      (1'b0                   ),
        .stallreq   (stallreq_from_icache   ),
        .cached     (1'b1                   ),
        .sram_en    (inst_sram_en & ~i_refill & ~i_invalid ),
        .sram_wen   (inst_sram_wen          ),
        .sram_addr  (inst_sram_addr_mmu     ),
        .refresh    (icache_refresh         ),
        .miss       (icache_miss            ),
        .axi_raddr  (icache_raddr           ),
        .write_back (icache_write_back      ),
        .axi_waddr  (icache_waddr           ),
        .hit        (icache_hit             ),
        .lru        (icache_lru             )
    );

    cache_data_v6 u_icache_data(
    	.clk           (aclk                   ),
        .rst           (~aresetn               ),
        .write_back    (1'b0                   ),
        .hit           (icache_hit             ),
        .lru           (icache_lru             ),
        .cached        (1'b1                   ),
        .sram_en       (inst_sram_en & ~i_refill & ~i_invalid ),
        .sram_wen      (inst_sram_wen          ),
        .sram_addr     (inst_sram_addr_mmu     ),
        .sram_wdata    (inst_sram_wdata        ),
        .sram_rdata    (inst_sram_rdata        ),
        .refresh       (icache_refresh         ),
        .cacheline_new (icache_cacheline_new   ),
        .cacheline_old (icache_cacheline_old   )
    );

    wire [31:0] data_sram_addr_mmu;
    wire [31:0] dcache_temp_rdata;
    wire [31:0] uncache_temp_rdata;
    assign data_sram_addr_mmu = {data_tag,data_sram_addr[11:0]};
    // mmu u_data_mmu(
    // 	.addr_i  (data_sram_addr  ),
    //     .addr_o  (data_sram_addr_mmu  ),
    //     .cache_v (dcache_cached )
    // );

    cache_tag_v5 u_dcache_tag(
    	.clk        (aclk                   ),
        .rst        (~aresetn               ),
        .flush      (1'b0                   ),
        .stallreq   (stallreq_from_dcache   ),
        .cached     (~dcache_uncached       ),
        .sram_en    (data_sram_en & ~d_refill & ~d_invalid & ~d_modify),
        .sram_wen   (data_sram_wen          ),
        .sram_addr  (data_sram_addr_mmu     ),
        .refresh    (dcache_refresh         ),
        .miss       (dcache_miss            ),
        .axi_raddr  (dcache_raddr           ),
        .write_back (dcache_write_back      ),
        .axi_waddr  (dcache_waddr           ),
        .hit        (dcache_hit             ),
        .lru        (dcache_lru             )
    );

    cache_data_v5 u_dcache_data(
    	.clk           (aclk                   ),
        .rst           (~aresetn               ),
        .write_back    (dcache_write_back      ),
        .hit           (dcache_hit             ),
        .lru           (dcache_lru             ),
        .cached        (~dcache_uncached       ),
        .sram_en       (data_sram_en & ~d_refill & ~d_invalid & ~d_modify),
        .sram_wen      (data_sram_wen          ),
        .sram_addr     (data_sram_addr_mmu     ),
        .sram_wdata    (data_sram_wdata        ),
        .sram_rdata    (dcache_temp_rdata      ),
        .refresh       (dcache_refresh         ),
        .cacheline_new (dcache_cacheline_new   ),
        .cacheline_old (dcache_cacheline_old   )
    );

    uncache u_uncache(
    	.clk        (aclk                             ),
        .resetn     (aresetn                          ),
        .stallreq   (stallreq_from_uncache            ),
        .conf_en    (data_sram_en & ~dcache_cached    ),
        .conf_wen   (data_sram_wen                    ),
        .conf_addr  (data_sram_addr_mmu               ),
        .conf_wdata (data_sram_wdata                  ),
        .conf_rdata (uncache_temp_rdata               ),
        .axi_en     (uncache_en                       ),
        .axi_wsel   (uncache_wen                      ),
        .axi_addr   (uncache_addr                     ),
        .axi_wdata  (uncache_wdata                    ),
        .reload     (uncache_refresh                  ),
        .axi_rdata  (uncache_rdata                    )
    );

    reg dcache_cached_r;
    assign dcache_cached = ~dcache_uncached;
    always @ (posedge aclk) begin
        dcache_cached_r <= dcache_cached;
    end
    assign data_sram_rdata = dcache_cached_r ? dcache_temp_rdata : uncache_temp_rdata;
    
    axi_control_v5 u_axi_control(
    	.clk                  (aclk                 ),
        .rstn                 (aresetn              ),

        .icache_ren           (icache_miss          ),
        .icache_raddr         (icache_raddr         ),
        .icache_cacheline_new (icache_cacheline_new ),
        .icache_wen           (1'b0                 ),
        .icache_waddr         (icache_waddr         ),
        .icache_cacheline_old (icache_cacheline_old ),
        .icache_refresh       (icache_refresh       ),

        .dcache_ren           (dcache_miss          ),
        .dcache_raddr         (dcache_raddr         ),
        .dcache_cacheline_new (dcache_cacheline_new ),
        .dcache_wen           (dcache_write_back    ),
        .dcache_waddr         (dcache_waddr         ),
        .dcache_cacheline_old (dcache_cacheline_old ),
        .dcache_refresh       (dcache_refresh       ),

        .uncache_en           (uncache_en           ),
        .uncache_wen          (uncache_wen          ),
        .uncache_addr         (uncache_addr         ),
        .uncache_wdata        (uncache_wdata        ),
        .uncache_rdata        (uncache_rdata        ),
        .uncache_refresh      (uncache_refresh      ),

        .arid                 (arid                 ),
        .araddr               (araddr               ),
        .arlen                (arlen                ),
        .arsize               (arsize               ),
        .arburst              (arburst              ),
        .arlock               (arlock               ),
        .arcache              (arcache              ),
        .arprot               (arprot               ),
        .arvalid              (arvalid              ),
        .arready              (arready              ),
        .rid                  (rid                  ),
        .rdata                (rdata                ),
        .rresp                (rresp                ),
        .rlast                (rlast                ),
        .rvalid               (rvalid               ),
        .rready               (rready               ),
        .awid                 (awid                 ),
        .awaddr               (awaddr               ),
        .awlen                (awlen                ),
        .awsize               (awsize               ),
        .awburst              (awburst              ),
        .awlock               (awlock               ),
        .awcache              (awcache              ),
        .awprot               (awprot               ),
        .awvalid              (awvalid              ),
        .awready              (awready              ),
        .wid                  (wid                  ),
        .wdata                (wdata                ),
        .wstrb                (wstrb                ),
        .wlast                (wlast                ),
        .wvalid               (wvalid               ),
        .wready               (wready               ),
        .bid                  (bid                  ),
        .bresp                (bresp                ),
        .bvalid               (bvalid               ),
        .bready               (bready               )
    );
    
    
endmodule 