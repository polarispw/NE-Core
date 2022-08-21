`include "lib/defines.vh"
module mycpu_core(
    input wire clk,
    input wire rst,
    input wire [5:0] int,
    input wire stallreq_icache,
    input wire stallreq_dcache,
    input wire stallreq_uncache,

    output wire inst_sram_en,
    output wire [3:0] inst_sram_wen,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [63:0] inst_sram_rdata,

    output wire data_sram_en,
    output wire [3:0] data_sram_wen,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,

    output wire [31:0] cp0_index,
    output wire [31:0] cp0_entrylo0,
    output wire [31:0] cp0_entrylo1,
    output wire [31:0] cp0_entryhi,
    output wire op_tlbp, 
    output wire op_tlbr, 
    output wire op_tlbwi,
    input  wire [31:0] tlb_index,
    input  wire [31:0] tlb_entryhi,
    input  wire [31:0] tlb_entrylo0,
    input  wire [31:0] tlb_entrylo1,
    input  wire i_refill,
    input  wire i_invalid,
    input  wire d_refill,
    input  wire d_invalid,
    input  wire d_modify, 

    output wire [31:0] debug_wb_pc,
    output wire [3:0] debug_wb_rf_wen,
    output wire [4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);

    // forward
    wire [`IF_TO_ID_WD-1 :0] if_to_id_bus;
    wire [`ID_TO_EX_WD-1 :0] id_to_ex_bus;
    wire [`EX_TO_MEM_WD-1:0] ex_to_dt_bus;
    wire [`EX_TO_MEM_WD-1:0] dt_to_mem_bus;
    wire [`MEM_TO_WB_WD-1:0] mem_to_wb_bus;

    // backward
    wire [`BR_WD-1       :0] br_bus; 
    wire [`EX_TO_RF_WD-1 :0] ex_to_rf_bus;
    wire [`EX_TO_RF_WD-1 :0] dt_to_rf_bus;
    wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus;
    wire [`WB_TO_RF_WD-1 :0] wb_to_rf_bus;

    // stall
    wire [`STALLBUS_WD-1:0] stall;
    wire stallreq_for_load;
    wire stallreq_for_excp0;
    wire stallreq_for_dtcp0;
    wire stallreq_for_ex;
    wire stallreq_for_fifo;

    // except
    wire [`CP0_TO_CTRL_WD-1:0] CP0_to_ctrl_bus;
    wire [`TTbits_wire] new_pc;
    wire flush;
    wire data_sram_en_dt;
    assign data_sram_en = data_sram_en_dt & ~CP0_to_ctrl_bus[32];

    // CP0 & MEM
    wire [31:0] data_sram_pc;
    wire op_load, op_store;
    wire [`EXCEPT_WD-1:0] exceptinfo_i1;
    wire [`EXCEPT_WD-1:0] exceptinfo_i2;
    wire [31:0] current_pc_i1;
    wire [31:0] current_pc_i2;
    wire [31:0] rt_rdata_i1;
    wire [31:0] rt_rdata_i2;
    wire caused_by_i1;
    wire caused_by_i2;
    wire [31:0] cp0_rdata;

    // relay for core and tlb
    wire [31:0] cp0_index_c2r, cp0_entrylo0_c2r, cp0_entrylo1_c2r, cp0_entryhi_c2r;
    wire op_tlbp_c2r, op_tlbr_c2r, op_tlbwi_c2r;
    wire [31:0] tlb_index_r2c, tlb_entrylo0_r2c, tlb_entrylo1_r2c, tlb_entryhi_r2c;
    wire i_refill_r2c, i_invalid_r2c, d_refill_r2c, d_invalid_r2c, d_modify_r2c;
    wire [31:0] tlbexc_iaddr;
    wire [31:0] tlbexc_daddr;
    wire [31:0] tlbexc_dpc;
    wire stallreq_for_tlb;

    // cache
    wire stallreq_for_cache = stallreq_icache | stallreq_dcache | stallreq_uncache;


    // flow line
    IF u_IF(
    	.clk             (clk             ),
        .rst             (rst             ),
        .stall           (stall           ),
        .flush           (flush           ),
        .new_pc          (new_pc          ),   
        .br_bus          (br_bus          ),
        .if_to_id_bus    (if_to_id_bus    ),
        .inst_sram_en    (inst_sram_en    ),
        .inst_sram_wen   (inst_sram_wen   ),
        .inst_sram_addr  (inst_sram_addr  ),
        .inst_sram_wdata (inst_sram_wdata )
    );
    
    ID u_ID(
    	.clk                (clk                ),
        .rst                (rst                ),
        .flush              (flush              ),
        .stall              (stall              ),
        .stallreq_for_load  (stallreq_for_load  ),
        .stallreq_for_excp0 (stallreq_for_excp0 ),
        .stallreq_for_dtcp0 (stallreq_for_dtcp0 ),
        .stallreq_for_fifo  (stallreq_for_fifo  ),
        .stallreq_for_cache (stallreq_for_cache ),
        .if_to_id_bus       (if_to_id_bus       ),
        .tlbexc_pc          (tlbexc_iaddr       ), 
        .i_refill           (i_refill_r2c       ),
        .i_invalid          (i_invalid_r2c      ),
        .new_pc             (new_pc             ),
        .inst_sram_rdata    (inst_sram_rdata    ),
        .ex_to_rf_bus       (ex_to_rf_bus       ),
        .dt_to_rf_bus       (dt_to_rf_bus       ),
        .mem_to_rf_bus      (mem_to_rf_bus      ),
        .wb_to_rf_bus       (wb_to_rf_bus       ),
        .id_to_ex_bus       (id_to_ex_bus       ),
        .br_bus             (br_bus             )
    );

    wire data_sram_en_i1, data_sram_en_i2;
    wire data_sram_wen_i1, data_sram_wen_i2;
    wire [11:0] mem_op_2dt;
    wire [31:0] ex_result_2dt;
    wire [31:0] rf_rdata_2dt;
    wire [31:0] inst1_pc_2dt, inst2_pc_2dt;

    EX u_EX(
    	.clk             (clk             ),
        .rst             (rst             ),
        .flush           (flush           ),
        .stall           (stall           ),
        .stallreq_for_ex (stallreq_for_ex ),
        .id_to_ex_bus    (id_to_ex_bus    ),
        .ex_to_dt_bus    (ex_to_dt_bus    ),
        .ex_to_rf_bus    (ex_to_rf_bus    ),
        
        .data_sram_en_i1 (data_sram_en_i1 ),
        .data_sram_en_i2 (data_sram_en_i2 ),
        .data_sram_wen_i1(data_sram_wen_i1),
        .data_sram_wen_i2(data_sram_wen_i2),
        .mem_op          (mem_op_2dt      ),
        .ex_result       (ex_result_2dt   ),
        .rf_rdata        (rf_rdata_2dt    ),
        .inst1_pc        (inst1_pc_2dt    ),
        .inst2_pc        (inst2_pc_2dt    )
    );

    DT u_DT(
        .clk             (clk             ),
        .rst             (rst             ),
        .flush           (flush           ),
        .stall           (stall           ),

        .ex_to_dt_bus    (ex_to_dt_bus    ),
        .ex_to_rf_bus    (ex_to_rf_bus    ),
        .dt_to_mem_bus   (dt_to_mem_bus   ),
        .dt_to_rf_bus    (dt_to_rf_bus    ),

        .data_sram_en_i1 (data_sram_en_i1 ),
        .data_sram_en_i2 (data_sram_en_i2 ),
        .data_sram_wen_i1(data_sram_wen_i1),
        .data_sram_wen_i2(data_sram_wen_i2),
        .mem_op          (mem_op_2dt      ),
        .ex_result       (ex_result_2dt   ),
        .rf_rdata        (rf_rdata_2dt    ),
        .inst1_pc        (inst1_pc_2dt    ),
        .inst2_pc        (inst2_pc_2dt    ),

        .data_sram_pc    (data_sram_pc    ),
        .data_sram_en    (data_sram_en_dt ),
        .data_sram_wen   (data_sram_wen   ),
        .data_sram_addr  (data_sram_addr  ),
        .data_sram_wdata (data_sram_wdata )
    );

    MEM u_MEM(
    	.clk               (clk             ),
        .rst               (rst             ),
        .flush             (flush           ),
        .stall             (stall           ),

        .caused_by_i1      (caused_by_i1    ),
        .caused_by_i2      (caused_by_i2    ),
        .cp0_rdata         (cp0_rdata       ),
        .exceptinfo_i1     (exceptinfo_i1   ),
        .exceptinfo_i2     (exceptinfo_i2   ),
        .current_pc_i1     (current_pc_i1   ),
        .current_pc_i2     (current_pc_i2   ),
        .rt_rdata_i1       (rt_rdata_i1     ),
        .rt_rdata_i2       (rt_rdata_i2     ),

        .op_tlbp           (op_tlbp_c2r     ),
        .op_tlbr           (op_tlbr_c2r     ),
        .op_tlbwi          (op_tlbwi_c2r    ),
        .op_load           (op_load         ),
        .op_store          (op_store        ),

        .dt_to_mem_bus     (dt_to_mem_bus   ),
        .data_sram_rdata_i (data_sram_rdata ),
        .mem_to_wb_bus     (mem_to_wb_bus   ),
        .mem_to_rf_bus     (mem_to_rf_bus   )
    );
    
    WB u_WB(
    	.clk               (clk               ),
        .rst               (rst               ),
        .flush             (flush             ),
        .stall             (stall             ),
        .mem_to_wb_bus     (mem_to_wb_bus     ),
        .wb_to_rf_bus      (wb_to_rf_bus      ),
        .debug_wb_pc       (debug_wb_pc       ),
        .debug_wb_rf_wen   (debug_wb_rf_wen   ),
        .debug_wb_rf_wnum  (debug_wb_rf_wnum  ),
        .debug_wb_rf_wdata (debug_wb_rf_wdata )
    );

    CTRL u_CTRL(
    	.rst               (rst               ),
        .stallreq_for_ex   (stallreq_for_ex   ),
        .stallreq_for_load (stallreq_for_load ),
        .stallreq_for_excp0(stallreq_for_excp0),
        .stallreq_for_dtcp0(stallreq_for_dtcp0),
        .stallreq_for_fifo (stallreq_for_fifo ),
        .stallreq_for_tlb  (stallreq_for_tlb  ),
        .stallreq_for_cache(stallreq_for_cache),
        .CP0_to_ctrl_bus   (CP0_to_ctrl_bus   ), 
        .new_pc            (new_pc            ),
        .flush             (flush             ),  
        .stall             (stall             )
    );

    CP0 u_CP0(
        .rst            (rst             ),
        .clk            (clk             ),
        .int            (int             ),
        .exceptinfo_i1  (exceptinfo_i1   ),
        .exceptinfo_i2  (exceptinfo_i2   ),
        .current_pc_i1  (current_pc_i1   ),
        .current_pc_i2  (current_pc_i2   ),
        .rt_rdata_i1    (rt_rdata_i1     ),
        .rt_rdata_i2    (rt_rdata_i2     ),
        
        .o_rdata        (cp0_rdata       ),
        .caused_by_i1   (caused_by_i1    ),
        .caused_by_i2   (caused_by_i2    ),
        .CP0_to_ctrl_bus(CP0_to_ctrl_bus ),

        .entrylo0       (cp0_entrylo0_c2r),
        .entrylo1       (cp0_entrylo1_c2r),
        .entryhi        (cp0_entryhi_c2r ),
        .index          (cp0_index_c2r   ),

        .d_refill       (d_refill_r2c    ),
        .d_invalid      (d_invalid_r2c   ),
        .d_modify       (d_modify_r2c    ),
        .op_load        (op_load         ),
        .op_store       (op_store        ),

        .op_tlbp        (op_tlbp_c2r     ),
        .op_tlbr        (op_tlbr_c2r     ),
        .op_tlbwi       (op_tlbwi_c2r    ),
        .tlb_index      (tlb_index_r2c   ),
        .tlb_entryhi    (tlb_entryhi_r2c ),
        .tlb_entrylo0   (tlb_entrylo0_r2c),
        .tlb_entrylo1   (tlb_entrylo1_r2c),
        .tlbexc_pc      (tlbexc_dpc      )
    );


    CTRelay u_CTRelay(
        .rst             (rst                 ),
        .clk             (clk                 ),
        .flush           (flush               ),

        .cp0_index_c2r   (cp0_index_c2r       ),
        .cp0_entrylo0_c2r(cp0_entrylo0_c2r    ),
        .cp0_entrylo1_c2r(cp0_entrylo1_c2r    ),
        .cp0_entryhi_c2r (cp0_entryhi_c2r     ),
        .op_tlbp_c2r     (op_tlbp_c2r         ), 
        .op_tlbr_c2r     (op_tlbr_c2r         ), 
        .op_tlbwi_c2r    (op_tlbwi_c2r        ),

        .cp0_index_r2t   (cp0_index           ),
        .cp0_entrylo0_r2t(cp0_entrylo0        ),
        .cp0_entrylo1_r2t(cp0_entrylo1        ),
        .cp0_entryhi_r2t (cp0_entryhi         ),
        .op_tlbp_r2t     (op_tlbp             ), 
        .op_tlbr_r2t     (op_tlbr             ), 
        .op_tlbwi_r2t    (op_tlbwi            ),

        .tlb_index_t2r   (tlb_index           ),
        .tlb_entryhi_t2r (tlb_entryhi         ),
        .tlb_entrylo0_t2r(tlb_entrylo0        ),
        .tlb_entrylo1_t2r(tlb_entrylo1        ),
        .i_refill_t2r    (i_refill            ),
        .i_invalid_t2r   (i_invalid           ),
        .d_refill_t2r    (d_refill            ),
        .d_invalid_t2r   (d_invalid           ),
        .d_modify_t2r    (d_modify            ), 

        .tlb_index_r2c   (tlb_index_r2c       ),
        .tlb_entryhi_r2c (tlb_entryhi_r2c     ),
        .tlb_entrylo0_r2c(tlb_entrylo0_r2c    ),
        .tlb_entrylo1_r2c(tlb_entrylo1_r2c    ),
        .i_refill_r2c    (i_refill_r2c        ),
        .i_invalid_r2c   (i_invalid_r2c       ),
        .d_refill_r2c    (d_refill_r2c        ),
        .d_invalid_r2c   (d_invalid_r2c       ),
        .d_modify_r2c    (d_modify_r2c        ),

        .inst_sram_addr  (if_to_id_bus[63:32] ),
        .data_sram_addr  (data_sram_addr      ),
        .data_sram_pc    (data_sram_pc        ),
        .tlbexc_iaddr    (tlbexc_iaddr        ),
        .tlbexc_daddr    (tlbexc_daddr        ),
        .tlbexc_dpc      (tlbexc_dpc          ),
        .stallreq_for_tlb(stallreq_for_tlb    )
    );


endmodule