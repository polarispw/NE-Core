module tlb
#(
    parameter TLBNUM =16
)
(
input wire clk,
input wire rst,
input wire [2:0] k0,

//search port 0 inst
input  wire inst_en, 
input  wire [31:0] inst_vaddr,
output wire inst_uncached,
output wire [19:0] inst_tag,

//search port 1 data
input  wire data_ren,
input  wire data_wen,
input  wire [31:0] data_vaddr,
output wire data_uncached,
output wire [19:0] data_tag,
output wire [31:0] p_index,

//write port
input                       we,
input [$clog2(TLBNUM)-1:0]  w_index,
input wire [31:0]           w_hi,
input wire [31:0]           w_lo0,
input wire [31:0]           w_lo1,

//read port
input [$clog2(TLBNUM)-1:0] r_index,
output wire [31:0] r_hi,
output wire [31:0] r_lo0,
output wire [31:0] r_lo1,

//例外 
output wire i_refill,
output wire i_invalid,
output wire d_refill,
output wire d_invalid,
output wire d_modify,

//tlb op 
input wire op_tlbp,
input wire op_tlbr,
input wire op_tlbwi,
input wire op_tlbwr


);

reg [           18:0] tlb_vpn2  [TLBNUM-1:0];
reg [            7:0] tlb_asid  [TLBNUM-1:0];
reg                   tlb_g     [TLBNUM-1:0];
reg [           19:0] tlb_pfn0  [TLBNUM-1:0];
reg [            2:0] tlb_c0    [TLBNUM-1:0];
reg                   tlb_d0    [TLBNUM-1:0];
reg                   tlb_v0    [TLBNUM-1:0];
reg [           19:0] tlb_pfn1  [TLBNUM-1:0];
reg [            2:0] tlb_c1    [TLBNUM-1:0];
reg                   tlb_d1    [TLBNUM-1:0];
reg                   tlb_v1    [TLBNUM-1:0];

wire [TLBNUM-1:0] match0;
wire [TLBNUM-1:0] match1;

//write 
wire [18:0] w_vpn2;
wire [7:0]  w_asid;
wire        w_g;
wire [19:0] w_pfn0;
wire [2:0]  w_c0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_pfn1;
wire [2:0]  w_c1;
wire        w_d1;
wire        w_v1;
//read 
wire [18:0] r_vpn2;
wire [7:0]  r_asid;
wire        r_g;
wire [19:0] r_pfn0;
wire [2:0]  r_c0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_pfn1;
wire [2:0]  r_c1;
wire        r_d1;
wire        r_v1;
//search inst
wire [18:0] i_vpn2;
wire        i_odd_page;
wire [7:0]  i_asid;
wire        i_found;
wire [3:0]  i_index;
wire [19:0] i_pfn;
wire [2:0]  i_c;
wire        i_d;
wire        i_v;
//search data
wire [18:0] d_vpn2;
wire        d_odd_page;
wire [7:0]  d_asid;
wire        d_found;
wire [3:0]  d_index;
wire [19:0] d_pfn;
wire [2:0]  d_c;
wire        d_d;
wire        d_v;

wire [19:0] i_pfn0;
wire [2:0]  i_c0;
wire        i_d0;
wire        i_v0;
wire [19:0] i_pfn1;
wire [2:0]  i_c1;
wire        i_d1;

wire [19:0] d_pfn0;
wire [2:0]  d_c0;
wire        d_d0;
wire        d_v0;
wire [19:0] d_pfn1;
wire [2:0]  d_c1;
wire        d_d1;

assign w_vpn2 = w_hi[31:13];
assign w_asid = w_hi[7:0];
assign w_g    = w_lo0[0] & w_lo1[0];
assign w_pfn0 = w_lo0[25:6];
assign w_c0   = w_lo0[5:3];
assign w_d0   = w_lo0[2];
assign w_v0   = w_lo0[1];
assign w_pfn1 = w_lo1[25:6];
assign w_c1   = w_lo1[5:3];
assign w_d1   = w_lo1[2];
assign w_v1   = w_lo1[1];

//read
assign r_vpn2 = (r_index == w_index && we == 1'b1) ? w_vpn2 : tlb_vpn2[r_index];
assign r_asid = (r_index == w_index && we == 1'b1) ? w_asid : tlb_asid[r_index];
assign r_g    = (r_index == w_index && we == 1'b1) ? w_g    : tlb_g[r_index];
assign r_pfn0 = (r_index == w_index && we == 1'b1) ? w_pfn0 : tlb_pfn0[r_index];
assign r_c0   = (r_index == w_index && we == 1'b1) ? w_c0   : tlb_c0[r_index];
assign r_d0   = (r_index == w_index && we == 1'b1) ? w_d0   : tlb_d0[r_index];
assign r_v0   = (r_index == w_index && we == 1'b1) ? w_v0   : tlb_v0[r_index];
assign r_pfn1 = (r_index == w_index && we == 1'b1) ? w_pfn1 : tlb_pfn1[r_index];
assign r_c1   = (r_index == w_index && we == 1'b1) ? w_c1   : tlb_c1[r_index];
assign r_d1   = (r_index == w_index && we == 1'b1) ? w_d1   : tlb_d1[r_index];
assign r_v1   = (r_index == w_index && we == 1'b1) ? w_v1   : tlb_v1[r_index];

assign r_hi   = {r_vpn2,5'b0,r_asid};
assign r_lo0  = {6'b0,r_pfn0,r_c0,r_d0,r_v0,r_g};
assign r_lo1  = {6'b0,r_pfn1,r_c1,r_d1,r_v1,r_g};

assign i_vpn2     = inst_vaddr[31:13];
assign i_odd_page = inst_vaddr[12];
assign i_asid     = w_hi[7:0];

assign d_vpn2     = op_tlbp ? w_vpn2 : data_vaddr[31:13];
assign d_odd_page = op_tlbp ? w_hi[12] : data_vaddr[12];
assign d_asid     = op_tlbp ? w_asid : w_hi[7:0];


//search
assign match0[ 0] = (i_vpn2==tlb_vpn2[ 0]) && ((i_asid==tlb_asid[ 0]) || tlb_g[ 0]);
assign match0[ 1] = (i_vpn2==tlb_vpn2[ 1]) && ((i_asid==tlb_asid[ 1]) || tlb_g[ 1]);
assign match0[ 2] = (i_vpn2==tlb_vpn2[ 2]) && ((i_asid==tlb_asid[ 2]) || tlb_g[ 2]);
assign match0[ 3] = (i_vpn2==tlb_vpn2[ 3]) && ((i_asid==tlb_asid[ 3]) || tlb_g[ 3]);
assign match0[ 4] = (i_vpn2==tlb_vpn2[ 4]) && ((i_asid==tlb_asid[ 4]) || tlb_g[ 4]);
assign match0[ 5] = (i_vpn2==tlb_vpn2[ 5]) && ((i_asid==tlb_asid[ 5]) || tlb_g[ 5]);
assign match0[ 6] = (i_vpn2==tlb_vpn2[ 6]) && ((i_asid==tlb_asid[ 6]) || tlb_g[ 6]);
assign match0[ 7] = (i_vpn2==tlb_vpn2[ 7]) && ((i_asid==tlb_asid[ 7]) || tlb_g[ 7]);
assign match0[ 8] = (i_vpn2==tlb_vpn2[ 8]) && ((i_asid==tlb_asid[ 8]) || tlb_g[ 8]);
assign match0[ 9] = (i_vpn2==tlb_vpn2[ 9]) && ((i_asid==tlb_asid[ 9]) || tlb_g[ 9]);
assign match0[10] = (i_vpn2==tlb_vpn2[10]) && ((i_asid==tlb_asid[10]) || tlb_g[10]);
assign match0[11] = (i_vpn2==tlb_vpn2[11]) && ((i_asid==tlb_asid[11]) || tlb_g[11]);
assign match0[12] = (i_vpn2==tlb_vpn2[12]) && ((i_asid==tlb_asid[12]) || tlb_g[12]);
assign match0[13] = (i_vpn2==tlb_vpn2[13]) && ((i_asid==tlb_asid[13]) || tlb_g[13]);
assign match0[14] = (i_vpn2==tlb_vpn2[14]) && ((i_asid==tlb_asid[14]) || tlb_g[14]);
assign match0[15] = (i_vpn2==tlb_vpn2[15]) && ((i_asid==tlb_asid[15]) || tlb_g[15]);//TODO respond TLBNUM

assign match1[ 0] = (d_vpn2==tlb_vpn2[ 0]) && ((d_asid==tlb_asid[ 0]) || tlb_g[ 0]);
assign match1[ 1] = (d_vpn2==tlb_vpn2[ 1]) && ((d_asid==tlb_asid[ 1]) || tlb_g[ 1]);
assign match1[ 2] = (d_vpn2==tlb_vpn2[ 2]) && ((d_asid==tlb_asid[ 2]) || tlb_g[ 2]);
assign match1[ 3] = (d_vpn2==tlb_vpn2[ 3]) && ((d_asid==tlb_asid[ 3]) || tlb_g[ 3]);
assign match1[ 4] = (d_vpn2==tlb_vpn2[ 4]) && ((d_asid==tlb_asid[ 4]) || tlb_g[ 4]);
assign match1[ 5] = (d_vpn2==tlb_vpn2[ 5]) && ((d_asid==tlb_asid[ 5]) || tlb_g[ 5]);
assign match1[ 6] = (d_vpn2==tlb_vpn2[ 6]) && ((d_asid==tlb_asid[ 6]) || tlb_g[ 6]);
assign match1[ 7] = (d_vpn2==tlb_vpn2[ 7]) && ((d_asid==tlb_asid[ 7]) || tlb_g[ 7]);
assign match1[ 8] = (d_vpn2==tlb_vpn2[ 8]) && ((d_asid==tlb_asid[ 8]) || tlb_g[ 8]);
assign match1[ 9] = (d_vpn2==tlb_vpn2[ 9]) && ((d_asid==tlb_asid[ 9]) || tlb_g[ 9]);
assign match1[10] = (d_vpn2==tlb_vpn2[10]) && ((d_asid==tlb_asid[10]) || tlb_g[10]);
assign match1[11] = (d_vpn2==tlb_vpn2[11]) && ((d_asid==tlb_asid[11]) || tlb_g[11]);
assign match1[12] = (d_vpn2==tlb_vpn2[12]) && ((d_asid==tlb_asid[12]) || tlb_g[12]);
assign match1[13] = (d_vpn2==tlb_vpn2[13]) && ((d_asid==tlb_asid[13]) || tlb_g[13]);
assign match1[14] = (d_vpn2==tlb_vpn2[14]) && ((d_asid==tlb_asid[14]) || tlb_g[14]);
assign match1[15] = (d_vpn2==tlb_vpn2[15]) && ((d_asid==tlb_asid[15]) || tlb_g[15]);//TODO respond TLBNUM

assign i_found = !(match0 == 16'b0);//TODO respond TLBNUM
assign d_found = !(match1 == 16'b0);//TODO respond TLBNUM

assign i_index =  ({4{match0[ 0]}} & 4'd0 )
                | ({4{match0[ 1]}} & 4'd1 )
                | ({4{match0[ 2]}} & 4'd2 )
                | ({4{match0[ 3]}} & 4'd3 )
                | ({4{match0[ 4]}} & 4'd4 )
                | ({4{match0[ 5]}} & 4'd5 )
                | ({4{match0[ 6]}} & 4'd6 )
                | ({4{match0[ 7]}} & 4'd7 )
                | ({4{match0[ 8]}} & 4'd8 )
                | ({4{match0[ 9]}} & 4'd9 )
                | ({4{match0[10]}} & 4'd10)
                | ({4{match0[11]}} & 4'd11)
                | ({4{match0[12]}} & 4'd12)
                | ({4{match0[13]}} & 4'd13)
                | ({4{match0[14]}} & 4'd14)
                | ({4{match0[15]}} & 4'd15);//TODO respond TLBNUM
assign d_index = ({4{match1[ 0]}} & 4'd0 )
                | ({4{match1[ 1]}} & 4'd1 )
                | ({4{match1[ 2]}} & 4'd2 )
                | ({4{match1[ 3]}} & 4'd3 )
                | ({4{match1[ 4]}} & 4'd4 )
                | ({4{match1[ 5]}} & 4'd5 )
                | ({4{match1[ 6]}} & 4'd6 )
                | ({4{match1[ 7]}} & 4'd7 )
                | ({4{match1[ 8]}} & 4'd8 )
                | ({4{match1[ 9]}} & 4'd9 )
                | ({4{match1[10]}} & 4'd10)
                | ({4{match1[11]}} & 4'd11)
                | ({4{match1[12]}} & 4'd12)
                | ({4{match1[13]}} & 4'd13)
                | ({4{match1[14]}} & 4'd14)
                | ({4{match1[15]}} & 4'd15);//TODO respond TLBNUM

assign i_pfn0= ({20{match0[ 0]}} & tlb_pfn0[ 0])
              | ({20{match0[ 1]}} & tlb_pfn0[ 1])
              | ({20{match0[ 2]}} & tlb_pfn0[ 2])
              | ({20{match0[ 3]}} & tlb_pfn0[ 3])
              | ({20{match0[ 4]}} & tlb_pfn0[ 4])
              | ({20{match0[ 5]}} & tlb_pfn0[ 5])
              | ({20{match0[ 6]}} & tlb_pfn0[ 6])
              | ({20{match0[ 7]}} & tlb_pfn0[ 7])
              | ({20{match0[ 8]}} & tlb_pfn0[ 8])
              | ({20{match0[ 9]}} & tlb_pfn0[ 9])
              | ({20{match0[10]}} & tlb_pfn0[10])
              | ({20{match0[11]}} & tlb_pfn0[11])
              | ({20{match0[12]}} & tlb_pfn0[12])
              | ({20{match0[13]}} & tlb_pfn0[13])
              | ({20{match0[14]}} & tlb_pfn0[14])
              | ({20{match0[15]}} & tlb_pfn0[15]);//TODO respond TLBNUM
assign i_c0  = ({20{match0[ 0]}} &   tlb_c0[ 0])
              | ({20{match0[ 1]}} &   tlb_c0[ 1])
              | ({20{match0[ 2]}} &   tlb_c0[ 2])
              | ({20{match0[ 3]}} &   tlb_c0[ 3])
              | ({20{match0[ 4]}} &   tlb_c0[ 4])
              | ({20{match0[ 5]}} &   tlb_c0[ 5])
              | ({20{match0[ 6]}} &   tlb_c0[ 6])
              | ({20{match0[ 7]}} &   tlb_c0[ 7])
              | ({20{match0[ 8]}} &   tlb_c0[ 8])
              | ({20{match0[ 9]}} &   tlb_c0[ 9])
              | ({20{match0[10]}} &   tlb_c0[10])
              | ({20{match0[11]}} &   tlb_c0[11])
              | ({20{match0[12]}} &   tlb_c0[12])
              | ({20{match0[13]}} &   tlb_c0[13])
              | ({20{match0[14]}} &   tlb_c0[14])
              | ({20{match0[15]}} &   tlb_c0[15]);//TODO respond TLBNUM
assign i_d0  = ({20{match0[ 0]}} &   tlb_d0[ 0])
              | ({20{match0[ 1]}} &   tlb_d0[ 1])
              | ({20{match0[ 2]}} &   tlb_d0[ 2])
              | ({20{match0[ 3]}} &   tlb_d0[ 3])
              | ({20{match0[ 4]}} &   tlb_d0[ 4])
              | ({20{match0[ 5]}} &   tlb_d0[ 5])
              | ({20{match0[ 6]}} &   tlb_d0[ 6])
              | ({20{match0[ 7]}} &   tlb_d0[ 7])
              | ({20{match0[ 8]}} &   tlb_d0[ 8])
              | ({20{match0[ 9]}} &   tlb_d0[ 9])
              | ({20{match0[10]}} &   tlb_d0[10])
              | ({20{match0[11]}} &   tlb_d0[11])
              | ({20{match0[12]}} &   tlb_d0[12])
              | ({20{match0[13]}} &   tlb_d0[13])
              | ({20{match0[14]}} &   tlb_d0[14])
              | ({20{match0[15]}} &   tlb_d0[15]);//TODO respond TLBNUM
assign i_v0  = ({20{match0[ 0]}} &   tlb_v0[ 0])
              | ({20{match0[ 1]}} &   tlb_v0[ 1])
              | ({20{match0[ 2]}} &   tlb_v0[ 2])
              | ({20{match0[ 3]}} &   tlb_v0[ 3])
              | ({20{match0[ 4]}} &   tlb_v0[ 4])
              | ({20{match0[ 5]}} &   tlb_v0[ 5])
              | ({20{match0[ 6]}} &   tlb_v0[ 6])
              | ({20{match0[ 7]}} &   tlb_v0[ 7])
              | ({20{match0[ 8]}} &   tlb_v0[ 8])
              | ({20{match0[ 9]}} &   tlb_v0[ 9])
              | ({20{match0[10]}} &   tlb_v0[10])
              | ({20{match0[11]}} &   tlb_v0[11])
              | ({20{match0[12]}} &   tlb_v0[12])
              | ({20{match0[13]}} &   tlb_v0[13])
              | ({20{match0[14]}} &   tlb_v0[14])
              | ({20{match0[15]}} &   tlb_v0[15]);//TODO respond TLBNUM

assign i_pfn1= ({20{match0[ 0]}} & tlb_pfn1[ 0])
              | ({20{match0[ 1]}} & tlb_pfn1[ 1])
              | ({20{match0[ 2]}} & tlb_pfn1[ 2])
              | ({20{match0[ 3]}} & tlb_pfn1[ 3])
              | ({20{match0[ 4]}} & tlb_pfn1[ 4])
              | ({20{match0[ 5]}} & tlb_pfn1[ 5])
              | ({20{match0[ 6]}} & tlb_pfn1[ 6])
              | ({20{match0[ 7]}} & tlb_pfn1[ 7])
              | ({20{match0[ 8]}} & tlb_pfn1[ 8])
              | ({20{match0[ 9]}} & tlb_pfn1[ 9])
              | ({20{match0[10]}} & tlb_pfn1[10])
              | ({20{match0[11]}} & tlb_pfn1[11])
              | ({20{match0[12]}} & tlb_pfn1[12])
              | ({20{match0[13]}} & tlb_pfn1[13])
              | ({20{match0[14]}} & tlb_pfn1[14])
              | ({20{match0[15]}} & tlb_pfn1[15]);//TODO respond TLBNUM
assign i_c1  = ({20{match0[ 0]}} &   tlb_c1[ 0])
              | ({20{match0[ 1]}} &   tlb_c1[ 1])
              | ({20{match0[ 2]}} &   tlb_c1[ 2])
              | ({20{match0[ 3]}} &   tlb_c1[ 3])
              | ({20{match0[ 4]}} &   tlb_c1[ 4])
              | ({20{match0[ 5]}} &   tlb_c1[ 5])
              | ({20{match0[ 6]}} &   tlb_c1[ 6])
              | ({20{match0[ 7]}} &   tlb_c1[ 7])
              | ({20{match0[ 8]}} &   tlb_c1[ 8])
              | ({20{match0[ 9]}} &   tlb_c1[ 9])
              | ({20{match0[10]}} &   tlb_c1[10])
              | ({20{match0[11]}} &   tlb_c1[11])
              | ({20{match0[12]}} &   tlb_c1[12])
              | ({20{match0[13]}} &   tlb_c1[13])
              | ({20{match0[14]}} &   tlb_c1[14])
              | ({20{match0[15]}} &   tlb_c1[15]);//TODO respond TLBNUM
assign i_d1  = ({20{match0[ 0]}} &   tlb_d1[ 0])
              | ({20{match0[ 1]}} &   tlb_d1[ 1])
              | ({20{match0[ 2]}} &   tlb_d1[ 2])
              | ({20{match0[ 3]}} &   tlb_d1[ 3])
              | ({20{match0[ 4]}} &   tlb_d1[ 4])
              | ({20{match0[ 5]}} &   tlb_d1[ 5])
              | ({20{match0[ 6]}} &   tlb_d1[ 6])
              | ({20{match0[ 7]}} &   tlb_d1[ 7])
              | ({20{match0[ 8]}} &   tlb_d1[ 8])
              | ({20{match0[ 9]}} &   tlb_d1[ 9])
              | ({20{match0[10]}} &   tlb_d1[10])
              | ({20{match0[11]}} &   tlb_d1[11])
              | ({20{match0[12]}} &   tlb_d1[12])
              | ({20{match0[13]}} &   tlb_d1[13])
              | ({20{match0[14]}} &   tlb_d1[14])
              | ({20{match0[15]}} &   tlb_d1[15]);//TODO respond TLBNUM
assign i_v1  = ({20{match0[ 0]}} &   tlb_v1[ 0])
              | ({20{match0[ 1]}} &   tlb_v1[ 1])
              | ({20{match0[ 2]}} &   tlb_v1[ 2])
              | ({20{match0[ 3]}} &   tlb_v1[ 3])
              | ({20{match0[ 4]}} &   tlb_v1[ 4])
              | ({20{match0[ 5]}} &   tlb_v1[ 5])
              | ({20{match0[ 6]}} &   tlb_v1[ 6])
              | ({20{match0[ 7]}} &   tlb_v1[ 7])
              | ({20{match0[ 8]}} &   tlb_v1[ 8])
              | ({20{match0[ 9]}} &   tlb_v1[ 9])
              | ({20{match0[10]}} &   tlb_v1[10])
              | ({20{match0[11]}} &   tlb_v1[11])
              | ({20{match0[12]}} &   tlb_v1[12])
              | ({20{match0[13]}} &   tlb_v1[13])
              | ({20{match0[14]}} &   tlb_v1[14])
              | ({20{match0[15]}} &   tlb_v1[15]);//TODO respond TLBNUM

assign d_pfn0= ({20{match1[ 0]}} & tlb_pfn0[ 0])
              | ({20{match1[ 1]}} & tlb_pfn0[ 1])
              | ({20{match1[ 2]}} & tlb_pfn0[ 2])
              | ({20{match1[ 3]}} & tlb_pfn0[ 3])
              | ({20{match1[ 4]}} & tlb_pfn0[ 4])
              | ({20{match1[ 5]}} & tlb_pfn0[ 5])
              | ({20{match1[ 6]}} & tlb_pfn0[ 6])
              | ({20{match1[ 7]}} & tlb_pfn0[ 7])
              | ({20{match1[ 8]}} & tlb_pfn0[ 8])
              | ({20{match1[ 9]}} & tlb_pfn0[ 9])
              | ({20{match1[10]}} & tlb_pfn0[10])
              | ({20{match1[11]}} & tlb_pfn0[11])
              | ({20{match1[12]}} & tlb_pfn0[12])
              | ({20{match1[13]}} & tlb_pfn0[13])
              | ({20{match1[14]}} & tlb_pfn0[14])
              | ({20{match1[15]}} & tlb_pfn0[15]);//TODO respond TLBNUM
assign d_c0  = ({20{match1[ 0]}} &   tlb_c0[ 0])
              | ({20{match1[ 1]}} &   tlb_c0[ 1])
              | ({20{match1[ 2]}} &   tlb_c0[ 2])
              | ({20{match1[ 3]}} &   tlb_c0[ 3])
              | ({20{match1[ 4]}} &   tlb_c0[ 4])
              | ({20{match1[ 5]}} &   tlb_c0[ 5])
              | ({20{match1[ 6]}} &   tlb_c0[ 6])
              | ({20{match1[ 7]}} &   tlb_c0[ 7])
              | ({20{match1[ 8]}} &   tlb_c0[ 8])
              | ({20{match1[ 9]}} &   tlb_c0[ 9])
              | ({20{match1[10]}} &   tlb_c0[10])
              | ({20{match1[11]}} &   tlb_c0[11])
              | ({20{match1[12]}} &   tlb_c0[12])
              | ({20{match1[13]}} &   tlb_c0[13])
              | ({20{match1[14]}} &   tlb_c0[14])
              | ({20{match1[15]}} &   tlb_c0[15]);//TODO respond TLBNUM
assign d_d0  = ({20{match1[ 0]}} &   tlb_d0[ 0])
              | ({20{match1[ 1]}} &   tlb_d0[ 1])
              | ({20{match1[ 2]}} &   tlb_d0[ 2])
              | ({20{match1[ 3]}} &   tlb_d0[ 3])
              | ({20{match1[ 4]}} &   tlb_d0[ 4])
              | ({20{match1[ 5]}} &   tlb_d0[ 5])
              | ({20{match1[ 6]}} &   tlb_d0[ 6])
              | ({20{match1[ 7]}} &   tlb_d0[ 7])
              | ({20{match1[ 8]}} &   tlb_d0[ 8])
              | ({20{match1[ 9]}} &   tlb_d0[ 9])
              | ({20{match1[10]}} &   tlb_d0[10])
              | ({20{match1[11]}} &   tlb_d0[11])
              | ({20{match1[12]}} &   tlb_d0[12])
              | ({20{match1[13]}} &   tlb_d0[13])
              | ({20{match1[14]}} &   tlb_d0[14])
              | ({20{match1[15]}} &   tlb_d0[15]);//TODO respond TLBNUM
assign d_v0  = ({20{match1[ 0]}} &   tlb_v0[ 0])
              | ({20{match1[ 1]}} &   tlb_v0[ 1])
              | ({20{match1[ 2]}} &   tlb_v0[ 2])
              | ({20{match1[ 3]}} &   tlb_v0[ 3])
              | ({20{match1[ 4]}} &   tlb_v0[ 4])
              | ({20{match1[ 5]}} &   tlb_v0[ 5])
              | ({20{match1[ 6]}} &   tlb_v0[ 6])
              | ({20{match1[ 7]}} &   tlb_v0[ 7])
              | ({20{match1[ 8]}} &   tlb_v0[ 8])
              | ({20{match1[ 9]}} &   tlb_v0[ 9])
              | ({20{match1[10]}} &   tlb_v0[10])
              | ({20{match1[11]}} &   tlb_v0[11])
              | ({20{match1[12]}} &   tlb_v0[12])
              | ({20{match1[13]}} &   tlb_v0[13])
              | ({20{match1[14]}} &   tlb_v0[14])
              | ({20{match1[15]}} &   tlb_v0[15]);//TODO respond TLBNUM

assign d_pfn1= ({20{match1[ 0]}} & tlb_pfn1[ 0])
              | ({20{match1[ 1]}} & tlb_pfn1[ 1])
              | ({20{match1[ 2]}} & tlb_pfn1[ 2])
              | ({20{match1[ 3]}} & tlb_pfn1[ 3])
              | ({20{match1[ 4]}} & tlb_pfn1[ 4])
              | ({20{match1[ 5]}} & tlb_pfn1[ 5])
              | ({20{match1[ 6]}} & tlb_pfn1[ 6])
              | ({20{match1[ 7]}} & tlb_pfn1[ 7])
              | ({20{match1[ 8]}} & tlb_pfn1[ 8])
              | ({20{match1[ 9]}} & tlb_pfn1[ 9])
              | ({20{match1[10]}} & tlb_pfn1[10])
              | ({20{match1[11]}} & tlb_pfn1[11])
              | ({20{match1[12]}} & tlb_pfn1[12])
              | ({20{match1[13]}} & tlb_pfn1[13])
              | ({20{match1[14]}} & tlb_pfn1[14])
              | ({20{match1[15]}} & tlb_pfn1[15]);//TODO respond TLBNUM
assign d_c1  = ({20{match1[ 0]}} &   tlb_c1[ 0])
              | ({20{match1[ 1]}} &   tlb_c1[ 1])
              | ({20{match1[ 2]}} &   tlb_c1[ 2])
              | ({20{match1[ 3]}} &   tlb_c1[ 3])
              | ({20{match1[ 4]}} &   tlb_c1[ 4])
              | ({20{match1[ 5]}} &   tlb_c1[ 5])
              | ({20{match1[ 6]}} &   tlb_c1[ 6])
              | ({20{match1[ 7]}} &   tlb_c1[ 7])
              | ({20{match1[ 8]}} &   tlb_c1[ 8])
              | ({20{match1[ 9]}} &   tlb_c1[ 9])
              | ({20{match1[10]}} &   tlb_c1[10])
              | ({20{match1[11]}} &   tlb_c1[11])
              | ({20{match1[12]}} &   tlb_c1[12])
              | ({20{match1[13]}} &   tlb_c1[13])
              | ({20{match1[14]}} &   tlb_c1[14])
              | ({20{match1[15]}} &   tlb_c1[15]);//TODO respond TLBNUM
assign d_d1  = ({20{match1[ 0]}} &   tlb_d1[ 0])
              | ({20{match1[ 1]}} &   tlb_d1[ 1])
              | ({20{match1[ 2]}} &   tlb_d1[ 2])
              | ({20{match1[ 3]}} &   tlb_d1[ 3])
              | ({20{match1[ 4]}} &   tlb_d1[ 4])
              | ({20{match1[ 5]}} &   tlb_d1[ 5])
              | ({20{match1[ 6]}} &   tlb_d1[ 6])
              | ({20{match1[ 7]}} &   tlb_d1[ 7])
              | ({20{match1[ 8]}} &   tlb_d1[ 8])
              | ({20{match1[ 9]}} &   tlb_d1[ 9])
              | ({20{match1[10]}} &   tlb_d1[10])
              | ({20{match1[11]}} &   tlb_d1[11])
              | ({20{match1[12]}} &   tlb_d1[12])
              | ({20{match1[13]}} &   tlb_d1[13])
              | ({20{match1[14]}} &   tlb_d1[14])
              | ({20{match1[15]}} &   tlb_d1[15]);//TODO respond TLBNUM
assign d_v1  = ({20{match1[ 0]}} &   tlb_v1[ 0])
              | ({20{match1[ 1]}} &   tlb_v1[ 1])
              | ({20{match1[ 2]}} &   tlb_v1[ 2])
              | ({20{match1[ 3]}} &   tlb_v1[ 3])
              | ({20{match1[ 4]}} &   tlb_v1[ 4])
              | ({20{match1[ 5]}} &   tlb_v1[ 5])
              | ({20{match1[ 6]}} &   tlb_v1[ 6])
              | ({20{match1[ 7]}} &   tlb_v1[ 7])
              | ({20{match1[ 8]}} &   tlb_v1[ 8])
              | ({20{match1[ 9]}} &   tlb_v1[ 9])
              | ({20{match1[10]}} &   tlb_v1[10])
              | ({20{match1[11]}} &   tlb_v1[11])
              | ({20{match1[12]}} &   tlb_v1[12])
              | ({20{match1[13]}} &   tlb_v1[13])
              | ({20{match1[14]}} &   tlb_v1[14])
              | ({20{match1[15]}} &   tlb_v1[15]);//TODO respond TLBNUM

assign i_pfn   = i_odd_page ?   i_pfn1 : i_pfn0;
assign i_c     = i_odd_page ?   i_c1 :   i_c0;
assign i_d     = i_odd_page ?   i_d1 :   i_d0;
assign i_v     = i_odd_page ?   i_v1 :   i_v0;

assign d_pfn   = d_odd_page ?   d_pfn1  :   d_pfn0;
assign d_c     = d_odd_page ?   d_c1    :   d_c0;
assign d_d     = d_odd_page ?   d_d1    :   d_d0;
assign d_v     = d_odd_page ?   d_v1    :   d_v0;

//write
integer kk;
always @(posedge clk) begin
  if(rst) begin
    for (kk=0; kk<TLBNUM; kk=kk+1) begin
        tlb_vpn2[kk] <= 0;
        tlb_asid[kk] <= 0;
        tlb_g[kk]    <= 0;
        tlb_pfn0[kk] <= 0;
        tlb_c0[kk]   <= 0;
        tlb_d0[kk]   <= 0;
        tlb_v0[kk]   <= 0;
        tlb_pfn1[kk] <= 0;
        tlb_c1[kk]   <= 0;
        tlb_d1[kk]   <= 0;
        tlb_v1[kk]   <= 0;
    end
  end
  else if (we) begin
      tlb_vpn2[w_index] <= w_vpn2;
      tlb_asid[w_index] <= w_asid;
      tlb_g[w_index]    <= w_g;
      tlb_pfn0[w_index] <= w_pfn0;
      tlb_c0[w_index]   <= w_c0;
      tlb_d0[w_index]   <= w_d0;
      tlb_v0[w_index]   <= w_v0;
      tlb_pfn1[w_index] <= w_pfn1;
      tlb_c1[w_index]   <= w_c1;
      tlb_d1[w_index]   <= w_d1;
      tlb_v1[w_index]   <= w_v1;
  end
end



//MMU 
wire i_kseg0;
wire i_kseg1;
wire i_kseg2;
wire i_kseg3;
wire i_kuseg;
assign i_kseg0 = (inst_vaddr[31:29] == 3'b100)  ? 1'b1 : 1'b0;
assign i_kseg1 = (inst_vaddr[31:29] == 3'b101)  ? 1'b1 : 1'b0;
assign i_kseg2 = (inst_vaddr[31:29] == 3'b110)  ? 1'b1 : 1'b0;
assign i_kseg3 = (inst_vaddr[31:29] == 3'b111)  ? 1'b1 : 1'b0;
assign i_kuseg = (inst_vaddr[31] == 1'b0)       ? 1'b1 : 1'b0;
assign inst_tag = (i_kseg1 || i_kseg0) ? {3'b0, inst_vaddr[28:12]} : i_pfn;

assign inst_uncached =  i_kseg1 ? 1'b1              :
                        i_kseg0 ? !(k0 == 3'b011)   :
                        i_kseg2 ? !(i_c == 3'b011)  :
                        i_kseg3 ? !(i_c == 3'b011)  :
                        i_kuseg ? !(i_c == 3'b011)  :
                        1'b1;

wire d_kseg0;
wire d_kseg1;
wire d_kseg2;
wire d_kseg3;
wire d_kuseg;
assign d_kseg0 = (data_vaddr[31:29] == 3'b100)  ? 1'b1 : 1'b0;
assign d_kseg1 = (data_vaddr[31:29] == 3'b101)  ? 1'b1 : 1'b0;
assign d_kseg2 = (data_vaddr[31:29] == 3'b110)  ? 1'b1 : 1'b0;
assign d_kseg3 = (data_vaddr[31:29] == 3'b111)  ? 1'b1 : 1'b0;
assign d_kuseg = (data_vaddr[31] == 1'b0)       ? 1'b1 : 1'b0;
assign data_tag = (d_kseg0 || d_kseg1) ? {3'b0, data_vaddr[28:12]} : d_pfn;

assign data_uncached =  d_kseg1 ? 1'b1 :
                        d_kseg0 ? !(k0 == 3'b011)  :
                        d_kseg2 ? !(d_c == 3'b011) :
                        d_kseg3 ? !(d_c == 3'b011) :
                        d_kuseg ? !(d_c == 3'b011) :
                        1'b1;

assign p_index = d_found ? d_index : {1'b1, 31'b0};

//异常 
assign i_refill  = (i_kseg0 || i_kseg1) ? 1'b0 : inst_en && !i_found;
assign i_invalid = (i_kseg0 || i_kseg1) ? 1'b0 : inst_en && i_found && !i_v;

assign d_refill  = (d_kseg0 || d_kseg1) ? 1'b0 : (data_wen | data_ren) & ~d_found;
assign d_invalid = (d_kseg0 || d_kseg1) ? 1'b0 : (data_wen | data_ren) & d_found & ~d_v;
assign d_modify  = (d_kseg0 || d_kseg1) ? 1'b0 : data_wen & d_found & d_v && ~d_d;

endmodule
