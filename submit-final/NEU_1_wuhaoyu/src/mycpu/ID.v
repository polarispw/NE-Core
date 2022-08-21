`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    input wire flush,
    input wire [`STALLBUS_WD-1:0] stall,
    input wire stallreq_for_cache,
   
    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,
    input wire i_refill,
    input wire i_invalid,
    input wire [31:0] tlbexc_pc,
    input wire [31:0] new_pc,
    input wire [63:0] inst_sram_rdata,

    input wire [`EX_TO_RF_WD-1:0]  ex_to_rf_bus,
    input wire [`EX_TO_RF_WD-1:0]  dt_to_rf_bus,
    input wire [`MEM_TO_RF_WD-1:0] mem_to_rf_bus,
    input wire [`WB_TO_RF_WD-1:0]  wb_to_rf_bus,

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,
    output wire [`BR_WD-1:0] br_bus,
    output wire stallreq_for_load,
    output wire stallreq_for_excp0,
    output wire stallreq_for_dtcp0,
    output wire stallreq_for_fifo
);

// IF to FIFO

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
  
    always @ (posedge clk) begin
        if (rst | flush) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`Stop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
        end
    end


// FIFO inst buffer

    wire [31:0] inst1_in, inst2_in;
    wire [31:0] inst1_in_pc, inst2_in_pc;
    wire inst1_in_val, inst2_in_val;

    wire re;
    wire [31:0] inst_addr, pc_idef;
    wire matched, inst1_matched, inst2_matched;
    wire pc_adel;
    reg [31:0] target_addr;
    reg check_pc;

    wire [31:0] inst1, inst2;
    wire [31:0] inst1_pc, inst2_pc;
    wire inst1_valid, inst2_valid;
    wire fifo_full, stop_pop;

    wire launched; 
    wire launch_mode;
    wire inst1_is_br,inst2_is_br;
    wire br_e;
    wire [31:0] br_addr, br_target_addr;
    wire empty_fifo;
    reg launch_r;
    reg empty_r;

    assign {re, pc_idef, inst_addr} = if_to_id_bus_r;
    assign pc_adel = (pc_idef!=inst_addr) & (pc_idef!=inst_addr+32'd4);

    always @(posedge clk ) begin
        if(rst) begin
            check_pc <= 1'b1;
            target_addr <= 32'hbfc0_0000;
        end
        else if(flush) begin
            check_pc <= 1'b1;
            target_addr <= new_pc;
        end
        else if(br_bus[32] & ~check_pc) begin
            check_pc <= 1'b1;
            target_addr <= br_bus[31:0];
        end
        else if(re & check_pc & (inst1_matched | inst2_matched))begin
            check_pc <= 1'b0;
            target_addr <= `ZeroWord;
        end
        else if(pc_adel) begin
            check_pc <= 1'b0;
            target_addr <= `ZeroWord;
        end
    end

    assign inst1_in = inst_sram_rdata[31: 0];
    assign inst2_in = inst_sram_rdata[63:32];

    assign inst1_in_pc   = pc_adel ? pc_idef : inst_addr;
    assign inst2_in_pc   = pc_adel ? pc_idef : inst_addr + 32'd4;

    assign inst1_matched = (check_pc & (inst1_in_pc!=target_addr)) ? 1'b0 : 1'b1;
    assign inst2_matched = (check_pc & (inst2_in_pc!=target_addr)) & 
                           (check_pc & (inst2_in_pc!=target_addr + 32'd4)) ? 1'b0 :1'b1;
    
    assign inst1_in_val  = ~re            ? 1'b0 :
                           ~inst1_matched ? 1'b0 : 1'b1;
    assign inst2_in_val  = ~re            ? 1'b0 :
                           ~inst2_matched ? 1'b0 : 1'b1;                      

    assign stallreq_for_fifo = fifo_full & ~br_bus[32]; // 队满时要发射的如果恰好是跳转则不能stall 要让IF取址(队列已留出冗余不会真的溢出)
    assign stop_pop = target_addr != `ZeroWord;

    always @(posedge clk) begin
        if(rst) begin
            empty_r <= 1'b0;
        end
        else if(flush) begin
            empty_r <= 1'b1;
        end
        else if(br_bus[32] ) begin
            empty_r <= 1'b1;
        end
        else begin
            empty_r <= 1'b0;
        end
    end
    assign empty_fifo = empty_r;

    Instbuffer FIFO_buffer(
        .clk           (clk               ),
        .rst           (rst               ),
        .flush         (empty_fifo        ),
        .stop_pop      (stop_pop          ),
        // .br_bus        ({br_e, br_addr}   ),
        .issue_i       (launch_r          ),
        .issue_mode_i  (launch_mode       ),
        .inst1_i       (inst1_in          ),
        .inst2_i       (inst2_in          ),
        .inst1_addr_i  (inst1_in_pc       ),
        .inst2_addr_i  (inst2_in_pc       ),
        .inst1_valid_i (inst1_in_val      ),
        .inst2_valid_i (inst2_in_val      ),

        .inst1_o        (inst1             ),
        .inst2_o        (inst2             ),
        .inst1_addr_o   (inst1_pc          ),
        .inst2_addr_o   (inst2_pc          ),
        .inst1_valid_o  (inst1_valid       ),
        .inst2_valid_o  (inst2_valid       ), 
        // .br_target_addr (br_target_addr    ),        
        .buffer_full_o  (fifo_full         )
    );


// bypass and WB signal

    wire ex_rf_we_i1, dt_rf_we_i1, mem_rf_we_i1, wb_rf_we_i1;
    wire ex_rf_we_i2, dt_rf_we_i2, mem_rf_we_i2, wb_rf_we_i2;
    wire [4:0]  ex_rf_waddr_i1, dt_rf_waddr_i1, mem_rf_waddr_i1, wb_rf_waddr_i1;
    wire [4:0]  ex_rf_waddr_i2, dt_rf_waddr_i2, mem_rf_waddr_i2, wb_rf_waddr_i2;
    wire [31:0] ex_rf_wdata_i1, dt_rf_wdata_i1, mem_rf_wdata_i1, wb_rf_wdata_i1;
    wire [31:0] ex_rf_wdata_i2, dt_rf_wdata_i2, mem_rf_wdata_i2, wb_rf_wdata_i2;

    wire ex_hi_we_i1, dt_hi_we_i1, mem_hi_we_i1, wb_hi_we_i1;
    wire ex_hi_we_i2, dt_hi_we_i2, mem_hi_we_i2, wb_hi_we_i2;
    wire ex_lo_we_i1, dt_lo_we_i1, mem_lo_we_i1, wb_lo_we_i1;
    wire ex_lo_we_i2, dt_lo_we_i2, mem_lo_we_i2, wb_lo_we_i2;
    wire [31:0] ex_hi_i1_i, dt_hi_i1_i, mem_hi_i1_i, wb_hi_i1_i;
    wire [31:0] ex_hi_i2_i, dt_hi_i2_i, mem_hi_i2_i, wb_hi_i2_i;
    wire [31:0] ex_lo_i1_i, dt_lo_i1_i, mem_lo_i1_i, wb_lo_i1_i;
    wire [31:0] ex_lo_i2_i, dt_lo_i2_i, mem_lo_i2_i, wb_lo_i2_i;
    wire ex_inst_is_load_i1, ex_inst_is_load_i2;
    wire dt_inst_is_load_i1, dt_inst_is_load_i2;
    wire ex_inst_is_cp0_i1, ex_inst_is_cp0_i2;
    wire dt_inst_is_cp0_i1, dt_inst_is_cp0_i2;
    
    assign {
        ex_inst_is_load_i2,
        ex_inst_is_cp0_i2,
        ex_hi_we_i2,
        ex_hi_i2_i,
        ex_lo_we_i2,
        ex_lo_i2_i,
        ex_rf_we_i2,
        ex_rf_waddr_i2,
        ex_rf_wdata_i2,
        ex_inst_is_load_i1,
        ex_inst_is_cp0_i1,
        ex_hi_we_i1,
        ex_hi_i1_i,
        ex_lo_we_i1,
        ex_lo_i1_i,
        ex_rf_we_i1,
        ex_rf_waddr_i1,
        ex_rf_wdata_i1
    } = ex_to_rf_bus;
    assign {
        dt_inst_is_load_i2,
        dt_inst_is_cp0_i2,
        dt_hi_we_i2,
        dt_hi_i2_i,
        dt_lo_we_i2,
        dt_lo_i2_i,
        dt_rf_we_i2,
        dt_rf_waddr_i2,
        dt_rf_wdata_i2,
        dt_inst_is_load_i1,
        dt_inst_is_cp0_i1,
        dt_hi_we_i1,
        dt_hi_i1_i,
        dt_lo_we_i1,
        dt_lo_i1_i,
        dt_rf_we_i1,
        dt_rf_waddr_i1,
        dt_rf_wdata_i1
    } = dt_to_rf_bus;
    assign {
        mem_hi_we_i2,
        mem_hi_i2_i,
        mem_lo_we_i2,
        mem_lo_i2_i,
        mem_rf_we_i2,
        mem_rf_waddr_i2,
        mem_rf_wdata_i2,
        mem_hi_we_i1,
        mem_hi_i1_i,
        mem_lo_we_i1,
        mem_lo_i1_i,
        mem_rf_we_i1,
        mem_rf_waddr_i1,
        mem_rf_wdata_i1
    } = mem_to_rf_bus;
    assign {
        wb_hi_we_i2,
        wb_hi_i2_i,
        wb_lo_we_i2,
        wb_lo_i2_i,
        wb_rf_we_i2,
        wb_rf_waddr_i2,
        wb_rf_wdata_i2,
        wb_hi_we_i1,
        wb_hi_i1_i,
        wb_lo_we_i1,
        wb_lo_i1_i,
        wb_rf_we_i1,
        wb_rf_waddr_i1,
        wb_rf_wdata_i1
    } = wb_to_rf_bus;


// decode instruction

    wire [`INST_INFO-1:0] inst1_info_o, inst2_info_o, inst2_info_temp;
    wire [`INST_INFO-1:0] inst1_info, inst2_info;
    wire [2:0] inst_flag1, inst_flag2;
    wire [4:0] rs_i1, rs_i2, rt_i1, rt_i2;
    wire stallreq_for_excp0_i1, stallreq_for_excp0_i2;
    wire stallreq_for_dtcp0_i1, stallreq_for_dtcp0_i2;
    wire stallreq_for_load_i1, stallreq_for_load_i2;

    assign rs_i1 = inst1[25:21];
    assign rt_i1 = inst1[20:16];
    assign rs_i2 = inst2[25:21];
    assign rt_i2 = inst2[20:16];

    wire data_corelate, inst_conflict;

    wire [2:0] sel_i1_src1, sel_i2_src1;
    wire [3:0] sel_i1_src2, sel_i2_src2;
    wire rf_we_i1, rf_we_i2;
    wire [4:0] rf_waddr_i1, rf_waddr_i2;

    wire [31:0] rf_rdata1_i1, rf_rdata2_i1;
    wire [31:0] rf_rdata1_i2, rf_rdata2_i2;
    wire [31:0] rdata1_i1, rdata2_i1;
    wire [31:0] rdata1_i2, rdata2_i2;
    
    wire [31:0] hi_o, lo_o;
    wire [31:0] hi_rdata, lo_rdata; 
    wire [32:0] br_bus1, br_bus2;

    reg last_inst_is_tlbwi, last_inst_is_tlbr;

    decoder u1_decoder(
        .inst_sram_rdata  (inst1               ),
        .id_pc            (inst1_pc            ),
        .inst_info        (inst1_info_o        ),
        .br_bus           (br_bus1             ),
        .is_br            (inst1_is_br         ),
        .inst_flag        (inst_flag1          )
    );

    decoder u2_decoder(
        .inst_sram_rdata  (inst2               ),
        .id_pc            (inst2_pc            ),
        .inst_info        (inst2_info_o        ),
        .br_bus           (br_bus2             ),
        .is_br            (inst2_is_br         ),
        .inst_flag        (inst_flag2          )
    );
    
    always @(posedge clk ) begin
        if(rst) begin
            last_inst_is_tlbwi <= 1'b0;
            last_inst_is_tlbr  <= 1'b0;
        end
        else if(inst1_info_o[94]) begin
            last_inst_is_tlbwi <= 1'b1;
        end 
        else if(inst1_info_o[95]) begin
            last_inst_is_tlbr <= 1'b1;
        end 
        else begin
            last_inst_is_tlbwi <= 1'b0;
            last_inst_is_tlbr  <= 1'b0;
        end
    end

    assign inst1_info = (last_inst_is_tlbwi | last_inst_is_tlbr) & inst1_info_o[80:49]==`ZeroWord ? {inst1_info_o[98:81], `TLBmark, inst1_info_o[48:0]} :
                        (i_refill)  & (tlbexc_pc==inst1_pc) ? {inst1_info_o[98:81], `TLBLR, inst1_info_o[48:0]} : 
                        (i_invalid) & (tlbexc_pc==inst1_pc) ? {inst1_info_o[98:81], `TLBLI, inst1_info_o[48:0]} : inst1_info_o; 

    assign inst2_info_temp = (i_refill)  & (tlbexc_pc==inst2_pc) ? {inst2_info_o[98:81], `TLBLR, inst2_info_o[48:0]} : 
                             (i_invalid) & (tlbexc_pc==inst2_pc) ? {inst2_info_o[98:81], `TLBLI, inst2_info_o[48:0]} : inst2_info_o; 
    assign inst2_info = inst1_is_br ? {1'b1, inst2_info_temp[97:0]} : inst2_info_temp;


// RW regfile

    regfile u_regfile(
    	.clk       (clk             ),
        .we_i1     (wb_rf_we_i1     ),
        .we_i2     (wb_rf_we_i2     ),
        .waddr_i1  (wb_rf_waddr_i1  ),
        .waddr_i2  (wb_rf_waddr_i2  ),
        .wdata_i1  (wb_rf_wdata_i1  ),
        .wdata_i2  (wb_rf_wdata_i2  ),
        .raddr1_i1 (rs_i1           ),
        .raddr2_i1 (rt_i1           ),
        .raddr1_i2 (rs_i2           ),
        .raddr2_i2 (rt_i2           ),
        .rdata1_i1 (rf_rdata1_i1    ),
        .rdata2_i1 (rf_rdata2_i1    ),
        .rdata1_i2 (rf_rdata1_i2    ),
        .rdata2_i2 (rf_rdata2_i2    )
    );

    hilo_reg u_hilo_reg(
    	.clk     (clk        ),
        .rst     (rst        ),
        .hi_we_i1(wb_hi_we_i1),
        .lo_we_i1(wb_lo_we_i1),
        .hi_we_i2(wb_hi_we_i2),
        .lo_we_i2(wb_lo_we_i2),
        .hi_i_i1 (wb_hi_i1_i ),
        .lo_i_i1 (wb_lo_i1_i ),
        .hi_i_i2 (wb_hi_i2_i ),
        .lo_i_i2 (wb_lo_i2_i ),
        .hi_o    (hi_o       ),
        .lo_o    (lo_o       )
    );


// bypass corelation

    assign rdata1_i1 = (ex_rf_we_i2  & (ex_rf_waddr_i2  == rs_i1)) ? ex_rf_wdata_i2  :
                       (ex_rf_we_i1  & (ex_rf_waddr_i1  == rs_i1)) ? ex_rf_wdata_i1  :
                       (dt_rf_we_i2  & (dt_rf_waddr_i2  == rs_i1)) ? dt_rf_wdata_i2  :
                       (dt_rf_we_i1  & (dt_rf_waddr_i1  == rs_i1)) ? dt_rf_wdata_i1  :
                       (mem_rf_we_i2 & (mem_rf_waddr_i2 == rs_i1)) ? mem_rf_wdata_i2 :
                       (mem_rf_we_i1 & (mem_rf_waddr_i1 == rs_i1)) ? mem_rf_wdata_i1 :
                       (wb_rf_we_i2  & (wb_rf_waddr_i2  == rs_i1)) ? wb_rf_wdata_i2  : 
                       (wb_rf_we_i1  & (wb_rf_waddr_i1  == rs_i1)) ? wb_rf_wdata_i1  : rf_rdata1_i1;

    assign rdata2_i1 = (ex_rf_we_i2  & (ex_rf_waddr_i2  == rt_i1)) ? ex_rf_wdata_i2  :
                       (ex_rf_we_i1  & (ex_rf_waddr_i1  == rt_i1)) ? ex_rf_wdata_i1  :
                       (dt_rf_we_i2  & (dt_rf_waddr_i2  == rt_i1)) ? dt_rf_wdata_i2  :
                       (dt_rf_we_i1  & (dt_rf_waddr_i1  == rt_i1)) ? dt_rf_wdata_i1  :
                       (mem_rf_we_i2 & (mem_rf_waddr_i2 == rt_i1)) ? mem_rf_wdata_i2 :
                       (mem_rf_we_i1 & (mem_rf_waddr_i1 == rt_i1)) ? mem_rf_wdata_i1 :
                       (wb_rf_we_i2  & (wb_rf_waddr_i2  == rt_i1)) ? wb_rf_wdata_i2  : 
                       (wb_rf_we_i1  & (wb_rf_waddr_i1  == rt_i1)) ? wb_rf_wdata_i1  : rf_rdata2_i1;

    assign rdata1_i2 = (ex_rf_we_i2  & (ex_rf_waddr_i2  == rs_i2)) ? ex_rf_wdata_i2  :
                       (ex_rf_we_i1  & (ex_rf_waddr_i1  == rs_i2)) ? ex_rf_wdata_i1  :
                       (dt_rf_we_i2  & (dt_rf_waddr_i2  == rs_i2)) ? dt_rf_wdata_i2  :
                       (dt_rf_we_i1  & (dt_rf_waddr_i1  == rs_i2)) ? dt_rf_wdata_i1  :
                       (mem_rf_we_i2 & (mem_rf_waddr_i2 == rs_i2)) ? mem_rf_wdata_i2 :
                       (mem_rf_we_i1 & (mem_rf_waddr_i1 == rs_i2)) ? mem_rf_wdata_i1 :
                       (wb_rf_we_i2  & (wb_rf_waddr_i2  == rs_i2)) ? wb_rf_wdata_i2  : 
                       (wb_rf_we_i1  & (wb_rf_waddr_i1  == rs_i2)) ? wb_rf_wdata_i1  : rf_rdata1_i2;

    assign rdata2_i2 = (ex_rf_we_i2  & (ex_rf_waddr_i2  == rt_i2)) ? ex_rf_wdata_i2  :
                       (ex_rf_we_i1  & (ex_rf_waddr_i1  == rt_i2)) ? ex_rf_wdata_i1  :
                       (dt_rf_we_i2  & (dt_rf_waddr_i2  == rt_i2)) ? dt_rf_wdata_i2  :
                       (dt_rf_we_i1  & (dt_rf_waddr_i1  == rt_i2)) ? dt_rf_wdata_i1  :
                       (mem_rf_we_i2 & (mem_rf_waddr_i2 == rt_i2)) ? mem_rf_wdata_i2 :
                       (mem_rf_we_i1 & (mem_rf_waddr_i1 == rt_i2)) ? mem_rf_wdata_i1 :
                       (wb_rf_we_i2  & (wb_rf_waddr_i2  == rt_i2)) ? wb_rf_wdata_i2  :
                       (wb_rf_we_i1  & (wb_rf_waddr_i1  == rt_i2)) ? wb_rf_wdata_i1  : rf_rdata2_i2;

    assign hi_rdata = ex_hi_we_i2  ? ex_hi_i2_i  :
                      ex_hi_we_i1  ? ex_hi_i1_i  :
                      dt_hi_we_i2  ? dt_hi_i2_i  :
                      dt_hi_we_i1  ? dt_hi_i1_i  :
                      mem_hi_we_i2 ? mem_hi_i2_i :
                      mem_hi_we_i1 ? mem_hi_i1_i :
                      wb_hi_we_i2  ? wb_hi_i2_i  : 
                      wb_hi_we_i1  ? wb_hi_i1_i  : hi_o;

    assign lo_rdata = ex_lo_we_i2  ? ex_lo_i2_i  :
                      ex_lo_we_i1  ? ex_lo_i1_i  :
                      dt_lo_we_i2  ? dt_lo_i2_i  :
                      dt_lo_we_i1  ? dt_lo_i1_i  :
                      mem_lo_we_i2 ? mem_lo_i2_i :
                      mem_lo_we_i1 ? mem_lo_i1_i :
                      wb_lo_we_i2  ? wb_lo_i2_i  :
                      wb_lo_we_i1  ? wb_lo_i1_i  : lo_o;

    wire [31:0] br_cls;
    wire [31:0] pc_plus_4;
    wire rs_eq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    
    assign br_cls = br_bus1[31:0];
    assign pc_plus_4 = inst1_pc + 32'h4;

    assign rs_eq_rt = (rdata1_i1 == rdata2_i1);
    assign rs_ge_z  = ~rdata1_i1[31];
    assign rs_gt_z  = ($signed(rdata1_i1) > 0);
    assign rs_le_z  = (rdata1_i1[31] == 1'b1 || rdata1_i1 == 32'b0);
    assign rs_lt_z  = (rdata1_i1[31]);

    assign br_e = (br_cls==32'h0000_0001) & rs_eq_rt |
                  (br_cls==32'h0000_0002) & ~rs_eq_rt|
                  (br_cls==32'h0000_0003) & rs_ge_z  | 
                  (br_cls==32'h0000_0004) & rs_gt_z  |
                  (br_cls==32'h0000_0005) & rs_le_z  | 
                  (br_cls==32'h0000_0006) & rs_lt_z  |
                  (br_cls==32'h0000_0007) & rs_lt_z  |
                  (br_cls==32'h0000_0008) & rs_ge_z  | br_bus1[32];

    assign br_addr = (br_cls==32'h0000_0001) ? (pc_plus_4 + {{14{inst1[15]}},inst1[15:0],2'b0}) :
                     (br_cls==32'h0000_0002) ? (pc_plus_4 + {{14{inst1[15]}},inst1[15:0],2'b0}) :
                     (br_cls==32'h0000_0003) ? (pc_plus_4 + {{14{inst1[15]}},inst1[15:0],2'b0}) :
                     (br_cls==32'h0000_0004) ? (pc_plus_4 + {{14{inst1[15]}},inst1[15:0],2'b0}) : 
                     (br_cls==32'h0000_0005) ? (pc_plus_4 + {{14{inst1[15]}},inst1[15:0],2'b0}) :
                     (br_cls==32'h0000_0006) ? (pc_plus_4 + {{14{inst1[15]}},inst1[15:0],2'b0}) :
                     (br_cls==32'h0000_0007) ? (pc_plus_4 + {{14{inst1[15]}},inst1[15:0],2'b0}) :
                     (br_cls==32'h0000_0008) ? (pc_plus_4 + {{14{inst1[15]}},inst1[15:0],2'b0}) :
                     (br_cls==32'h0000_0009) ? {inst1_pc[31:28],inst1[25:0],2'b0} :
                     (br_cls==32'h0000_000a) ? rdata1_i1 :
                     (br_cls==32'h0000_000b) ? {inst1_pc[31:28],inst1[25:0],2'b0} :
                     (br_cls==32'h0000_000c) ? rdata1_i1 : 32'b0;


// launch check

    wire inst1_launch, inst2_launch;
    wire [8:0] hilo_op_i1, hilo_op_i2;

    assign stallreq_for_load_i1 = ((ex_rf_waddr_i1  == rs_i1) | (ex_rf_waddr_i1  == rt_i1)) & ex_inst_is_load_i1
                                | ((ex_rf_waddr_i2  == rs_i1) | (ex_rf_waddr_i2  == rt_i1)) & ex_inst_is_load_i2
                                | ((dt_rf_waddr_i1  == rs_i1) | (dt_rf_waddr_i1  == rt_i1)) & dt_inst_is_load_i1
                                | ((dt_rf_waddr_i2  == rs_i1) | (dt_rf_waddr_i2  == rt_i1)) & dt_inst_is_load_i2;

    assign stallreq_for_load_i2 = ((ex_rf_waddr_i1  == rs_i2) | (ex_rf_waddr_i1  == rt_i2)) & ex_inst_is_load_i1
                                | ((ex_rf_waddr_i2  == rs_i2) | (ex_rf_waddr_i2  == rt_i2)) & ex_inst_is_load_i2
                                | ((dt_rf_waddr_i1  == rs_i2) | (dt_rf_waddr_i1  == rt_i2)) & dt_inst_is_load_i1
                                | ((dt_rf_waddr_i2  == rs_i2) | (dt_rf_waddr_i2  == rt_i2)) & dt_inst_is_load_i2;

    assign stallreq_for_excp0_i1  = ((ex_rf_we_i1 & (ex_rf_waddr_i1 == rs_i1)) | (ex_rf_we_i1 & (ex_rf_waddr_i1 == rt_i1))) & ex_inst_is_cp0_i1;
    assign stallreq_for_dtcp0_i1  = ((dt_rf_we_i1 & (dt_rf_waddr_i1 == rs_i1)) | (dt_rf_we_i1 & (dt_rf_waddr_i1 == rt_i1))) & dt_inst_is_cp0_i1;
    assign stallreq_for_excp0_i2  = ((ex_rf_we_i1 & (ex_rf_waddr_i1 == rs_i2)) | (ex_rf_we_i1 & (ex_rf_waddr_i1 == rt_i2))) & ex_inst_is_cp0_i1;
    assign stallreq_for_dtcp0_i2  = ((dt_rf_we_i1 & (dt_rf_waddr_i1 == rs_i2)) | (dt_rf_we_i1 & (dt_rf_waddr_i1 == rt_i2))) & dt_inst_is_cp0_i1;

    assign stallreq_for_load   = (stallreq_for_load_i1 & inst1_valid) |
                                 (stallreq_for_load_i2 & inst2_valid) ;
    assign stallreq_for_excp0  = (stallreq_for_excp0_i1  & inst1_valid) | 
                                 (stallreq_for_excp0_i2  & inst2_valid) ;
    assign stallreq_for_dtcp0  = (stallreq_for_dtcp0_i1  & inst1_valid) | 
                                 (stallreq_for_dtcp0_i2  & inst2_valid) ;

    assign sel_i1_src1 = inst1_info[15:13];
    assign sel_i2_src1 = inst2_info[15:13];
    assign sel_i1_src2 = inst1_info[12:9];
    assign sel_i2_src2 = inst2_info[12:9];
    assign rf_we_i1    = inst1_info[6];
    assign rf_we_i2    = inst2_info[6];
    assign rf_waddr_i1 = inst1_info[5:1];
    assign rf_waddr_i2 = inst2_info[5:1];
    assign hilo_op_i1  = inst1_info[36:28];
    assign hilo_op_i2  = inst2_info[36:28];

    assign data_corelate = (sel_i2_src1[0] & rf_we_i1 & (rf_waddr_i1==rs_i2)) | // i2 read reg[rs] & i1 write reg[rs]
                           (sel_i2_src2[0] & rf_we_i1 & (rf_waddr_i1==rt_i2)) | // i2 read reg[rt] & i1 write reg[rt]
                           (inst_flag1[0]  & hilo_op_i2[7:6]!=2'b0) | // i2 read hilo & i1 is complex cauculation
                           (hilo_op_i1[4]  & hilo_op_i2[6]) | // i2 read lo & i1 write lo
                           (hilo_op_i1[5]  & hilo_op_i2[7]) ; // i2 read hi & i1 write hi

    assign inst_conflict = (inst_flag1[1:0]!=2'b0 & inst_flag2[2:0]!=3'b0) |
                           (inst_flag1[2:0]!=3'b0 & inst_flag2[1:0]!=2'b0) |
                           (inst_flag1[2] | inst_flag2[2]) | inst_flag2[0];

    assign launch_mode   = inst1_is_br   ? `DualIssue   :
                           data_corelate ? `SingleIssue : 
                           inst_conflict ? `SingleIssue : 
                           inst2_is_br   ? `SingleIssue :
                           ~inst2_valid  ? `SingleIssue : `DualIssue;   

    assign launched      = stall[2]                     ? 1'b0 : 
                           (~inst2_valid & inst1_is_br) ? 1'b0 :
                           (~inst1_valid & ~inst2_valid)? 1'b0 : 1'b1 ;

    assign inst1_launch  = launched;
    assign inst2_launch  = launched & (launch_mode == `DualIssue);

    always@(*)begin
        if(rst | flush) begin
            launch_r <= 1'b0;
        end
        else begin
            launch_r <= launched;
        end
    end


// output part

    wire [`ID_INST_INFO-1:0] inst1_bus, inst2_bus;
    wire switch;

    assign br_bus = inst1_launch ? {br_e, br_addr} : 33'b0 ;
    assign switch = inst1_is_br;

    assign inst1_bus = inst1_launch ?
    {
        inst1_info[98:28],// 290:220
        hi_rdata,         // 219:188
        lo_rdata,         // 187:156
        inst1_pc,         // 155:124
        inst1,            // 123:92
        inst1_info[27:0], // 91:64
        rdata2_i1,        // 63:32
        rdata1_i1         // 31:0
    } : `ID_INST_INFO'b0;

    assign inst2_bus = inst2_launch ?
    {
        inst2_info[98:28],// 290:220
        hi_rdata,         // 219:188
        lo_rdata,         // 187:156
        inst2_pc,         // 155:124
        inst2,            // 123:92
        inst2_info[27:0], // 91:64
        rdata2_i2,        // 63:32
        rdata1_i2         // 31:0
    } : `ID_INST_INFO'b0;

    /*wire notes
    is_delayslot,   // 290
    inst_cache,     // 289
    inst_tlbp,      // 288
    inst_tlbr,      // 287
    inst_tlbwi,     // 286
    inst_tlbwr,     // 285
    inst_mfc0,      // 284
    inst_mtc0,      // 283
    waddr,          // 282:279
    raddr,          // 278:273
    excepttype      // 272:241
    mem_op,         // 240:229
    hilo_op,        // 228:220
    hi_rdata,       // 219:188
    lo_rdata,       // 187:156
    id_pc,          // 155:124
    inst,           // 123:92
    alu_op,         // 91:80
    sel_alu_src1,   // 79:77
    sel_alu_src2,   // 76:73
    data_ram_en,    // 72
    data_ram_wen,   // 71
    rf_we,          // 70
    rf_waddr,       // 69:65
    sel_rf_res,     // 64
    rdata1,         // 63:32
    rdata2          // 31:0
    */

    assign id_to_ex_bus = switch ? {switch, inst1_bus, inst2_bus, inst1_launch, inst2_launch} :
                                   {switch, inst2_bus, inst1_bus, inst2_launch, inst1_launch} ;

endmodule