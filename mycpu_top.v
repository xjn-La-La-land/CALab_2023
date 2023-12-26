`include "define.v"
module mycpu_top(

    input  wire         aclk,
    input  wire         aresetn,

    //read request interface
    output wire [ 3:0]  arid,
    output wire [31:0]  araddr,
    output wire [ 7:0]  arlen,
    output wire [ 2:0]  arsize,
    output wire [ 1:0]  arburst,
    output wire [ 1:0]  arlock,
    output wire [ 3:0]  arcache,
    output wire [ 2:0]  arprot,
    output wire         arvalid,
    input  wire         arready,

    //read data interface
    input  wire [ 3:0]  rid,
    input  wire [31:0]  rdata,
    input  wire [ 1:0]  rresp,
    input  wire         rlast,
    input  wire         rvalid,
    output wire         rready,

    //write request interface
    output wire [ 3:0]  awid,
    output wire [31:0]  awaddr,
    output wire [ 7:0]  awlen,
    output wire [ 2:0]  awsize,
    output wire [ 1:0]  awburst,
    output wire [ 1:0]  awlock,
    output wire [ 3:0]  awcache,
    output wire [ 2:0]  awprot,
    output wire         awvalid,
    input  wire         awready,

    //write data interface
    output wire [ 3:0]  wid,
    output wire [31:0]  wdata,
    output wire [ 3:0]  wstrb,
    output wire         wlast,
    output wire         wvalid,
    input  wire         wready,

    //write response interface
    input  wire [ 3:0]  bid,
    input  wire [ 1:0]  bresp,
    input  wire         bvalid,
    output wire         bready,

    // trace debug interface
    output wire [31:0]  debug_wb_pc,
    output wire [ 3:0]  debug_wb_rf_we,
    output wire [ 4:0]  debug_wb_rf_wnum,
    output wire [31:0]  debug_wb_rf_wdata

);
    wire   clk;
    reg    reset;
    assign clk = aclk;
    always @(posedge clk) reset <= ~aresetn;

    // inst sram interface
    wire        inst_sram_req;    // 指令RAM读写请求信号
    wire        inst_sram_wr;     // 1表示是写请求，为0表示是读请求(指令RAM恒为0)
    wire [ 2:0] inst_sram_size;   // 请求传输的字节数0: 1 byte, 1: 2 bytes, 2: 4 bytes
    wire [ 3:0] inst_sram_wstrb;  // 写请求的字节写使�?
    wire [31:0] inst_sram_addr;   // 读写请求的地�?
    wire [31:0] inst_sram_wdata;  // 写请求的写数�?(指令RAM恒为0)
    wire        inst_sram_addr_ok;// 该次请求的地�?传输OK，读：地�?被接收；写：地址和数据被接收
    wire        inst_sram_data_ok;// 该次请求的数据传输OK，读：数据返回；写：数据写入完成
    wire [31:0] inst_sram_rdata;  // 读请求返回的读数�?
    // data sram interface
    wire        data_sram_req;
    wire        data_sram_wr;
    wire [ 1:0] data_sram_size;
    wire [ 3:0] data_sram_wstrb;
    wire [31:0] data_sram_addr;
    wire [31:0] data_sram_wdata;
    wire        data_sram_addr_ok;
    wire        data_sram_data_ok;
    wire [31:0] data_sram_rdata;

    assign inst_sram_wr     = 1'b0;
    assign inst_sram_size   = 3'h2;
    assign inst_sram_wstrb  = 4'h0;
    assign inst_sram_wdata  = 32'h0;
    assign data_sram_size[2] = 1'b0;
    
    wire [31:0] pc_IF_to_ID;
    wire [31:0] pc_ID_to_EX;
    wire [31:0] pc_EX_to_MEM;
    wire [31:0] pc_MEM_to_WB;
    wire [31:0] pc_WB;

    wire        ID_allowin;
    wire        EX_allowin;
    wire        MEM_allowin;
    wire        WB_allowin;

    wire        IF_valid;
    wire        ID_valid;
    wire        EX_valid;
    wire        MEM_valid;
    wire        WB_valid;

    wire [31:0] mem_wdata;

    wire        br_taken;      // 跳转信号
    wire [31:0] br_target;

    wire [31:0] rf_rdata1;         // 读数�?
    wire [31:0] rf_rdata2;  
    
    wire        rf_we_EX;       // 用于读写对比
    wire [ 4:0] rf_waddr_EX;
    wire        res_from_mem_EX;

    wire        rf_we_MEM;
    wire [ 4:0] rf_waddr_MEM;
    wire [31:0] rf_wdata;

    wire        rf_we_WB;
    wire [ 4:0] rf_waddr_WB;
    wire [31:0] rf_wdata_WB;

    wire [ 4:0] rf_raddr1;        // 读地�?
    wire [ 4:0] rf_raddr2;
    wire        rf_we;
    wire [ 4:0] rf_waddr;
    wire        res_from_mem;

    wire [18:0] alu_op;         // ALU的操作码 
    wire [31:0] alu_src1;       // ALU的输�?         
    wire [31:0] alu_src2;

    wire [ 4:0] load_op_ID;
    wire [ 2:0] store_op;

    wire [ 4:0] load_op_EX;
    wire [31:0] alu_result;

    // 控制寄存�???
    wire  [13:0] csr_num_ID;
    wire         csr_en_ID;
    wire         csr_we_ID;
    wire  [31:0] csr_wmask_ID;
    wire  [31:0] csr_wdata_ID;
    
    wire  [13:0] csr_num_EX;
    wire         csr_en_EX;
    wire         csr_we_EX;
    wire  [31:0] csr_wmask_EX;
    wire  [31:0] csr_wdata_EX;

    wire  [13:0] csr_num_MEM;
    wire         csr_en_MEM;
    wire         csr_we_MEM;
    wire  [31:0] csr_wmask_MEM;
    wire  [31:0] csr_wdata_MEM;

    wire  [13:0] csr_num_WB;
    wire         csr_we_WB;
    wire  [31:0] csr_wmask_WB;
    wire  [31:0] csr_wdata_WB;

    // 控制寄存器读数据
    wire  [31:0] csr_rvalue;

    // 控制寄存器特殊接口
    wire  [ 9:0] csr_asid_asid;  
    wire  [18:0] csr_tlbehi_vppn; 
    wire  [31:0] csr_tlbidx;
    wire  [31:0] csr_tlbelo0;
    wire  [31:0] csr_tlbelo1;
    wire  [31:0] csr_crmd_value;
    wire  [31:0] csr_dwm0_value;
    wire  [31:0] csr_dwm1_value;


    // ertn 信号
    wire         ertn_flush_ID;
    wire         ertn_flush_EX;
    wire         ertn_flush_MEM;
    wire         ertn_flush_WB;

    // 读计时器相关信号
    wire [ 2:0]  rd_cnt_op_ID;

    wire         rd_cnt_EX;
    wire [ 2:0]  rd_cnt_op_EX;
    wire [31:0]  rd_timer_EX;

    wire         rd_cnt_MEM;
    wire [ 2:0]  rd_cnt_op_MEM;
    wire [31:0]  rd_timer_MEM;

    wire [ 2:0]  rd_cnt_op_WB;
    wire [31:0]  rd_timer_WB;  


    // 异常信号
    wire [13:0]  exception_source_IF;
    wire [13:0]  exception_source_ID;
    wire [13:0]  exception_source_EX;
    wire [13:0]  exception_source_MEM;
    wire [13:0]  exception_source_WB;

    wire         ex_MEM;     

    wire         ex_WB;     
    wire  [5:0]  wb_ecode_WB; 
    wire  [8:0]  wb_esubcode_WB;


    wire  [31:0] wb_vaddr_EX;
    wire  [31:0] wb_vaddr_MEM;
    wire  [31:0] wb_vaddr_WB;

    // 异常处理地址
    wire  [31:0] ex_entry;

    // 中断信号
    wire         has_int;

    // tlb相关信号
    // 传递 tlbrd, tlbwr, tlbfill
    wire  [4:0]  tlbcommand_ID;
    wire  [4:0]  invtlb_op_ID; 
    wire  [2:0]  tlbcommand_EX;
    wire  [2:0]  tlbcommand_MEM; 
    wire         tlbrd;
    wire         tlbwr;
    wire         tlbfill; 

    wire         tlb_flush_ID;
    wire         tlb_flush_EX;
    wire         tlb_flush_MEM;
    wire         tlb_flush_WB;

    wire [18:0] tlb_s0_vppn;
    wire        tlb_s0_va_bit12;
    wire [ 9:0] tlb_s0_asid;
    wire        tlb_s0_found;
    wire [ 3:0] tlb_s0_index;
    wire [19:0] tlb_s0_ppn;
    wire [ 5:0] tlb_s0_ps;
    wire [ 1:0] tlb_s0_plv;
    wire [ 1:0] tlb_s0_mat;
    wire        tlb_s0_d;
    wire        tlb_s0_v;
    wire [18:0] tlb_s1_vppn;
    wire        tlb_s1_va_bit12;
    wire [ 9:0] tlb_s1_asid;
    wire        tlb_s1_found;
    wire [ 3:0] tlb_s1_index;
    wire [19:0] tlb_s1_ppn;
    wire [ 5:0] tlb_s1_ps;
    wire [ 1:0] tlb_s1_plv;
    wire [ 1:0] tlb_s1_mat;
    wire        tlb_s1_d;
    wire        tlb_s1_v;

    wire        tlb_invtlb_valid;
    wire [ 4:0] tlb_invtlb_op;

    wire        tlb_r_e;
    wire [18:0] tlb_r_vppn;
    wire [ 5:0] tlb_r_ps;
    wire [ 9:0] tlb_r_asid;
    wire        tlb_r_g;
    wire [19:0] tlb_r_ppn0;
    wire [ 1:0] tlb_r_plv0;
    wire [ 1:0] tlb_r_mat0;
    wire        tlb_r_d0;
    wire        tlb_r_v0;
    wire [19:0] tlb_r_ppn1;
    wire [ 1:0] tlb_r_plv1;
    wire [ 1:0] tlb_r_mat1;
    wire        tlb_r_d1;
    wire        tlb_r_v1;

    // cache相关信号
    wire [11:0]  inst_vaddr_offset;

    wire         icache_rd_req;
    wire [ 2:0]  icache_rd_type;
    wire [31:0]  icache_rd_addr;

    wire         icache_rd_rdy;
    wire         icache_ret_valid;
    wire         icache_ret_last;
    wire [31:0]  icache_ret_data;
       

    pipe_IF u_pipe_IF(
        .clk          (clk),
        .reset        (reset),

        .from_allowin (ID_allowin),

        .br_taken     (br_taken),
        .br_target    (br_target),

        .ex_WB        (ex_WB),
        .flush_WB     (ertn_flush_WB),
        .tlb_flush_WB (tlb_flush_WB),

        .to_valid     (IF_valid),

        .PC           (pc_IF_to_ID),

        // tlb修改导致的取值错误，需要回到取值错误的第一个指令处
        .ex_entry     (tlb_flush_WB ? pc_WB : ex_entry), 

        .inst_sram_req(inst_sram_req),
        .inst_sram_wr (inst_sram_wr),
        .inst_sram_size(inst_sram_size),
        .inst_sram_wstrb(inst_sram_wstrb),
        .inst_sram_addr(inst_sram_addr),
        .inst_sram_wdata(inst_sram_wdata),
        .inst_sram_addr_ok(inst_sram_addr_ok),
        .inst_sram_data_ok(inst_sram_data_ok),

        .csr_crmd_value(csr_crmd_value),
        .csr_asid_asid(csr_asid_asid),
        .csr_dwm0_value(csr_dwm0_value),
        .csr_dwm1_value(csr_dwm1_value),


        .tlb_found(tlb_s0_found),
        .tlb_index(tlb_s0_index),
        .tlb_ppn(tlb_s0_ppn),
        .tlb_ps(tlb_s0_ps),
        .tlb_plv(tlb_s0_plv),
        .tlb_mat(tlb_s0_mat),
        .tlb_d(tlb_s0_d),
        .tlb_v(tlb_s0_v),

        .tlb_vppn(tlb_s0_vppn),
        .tlb_va_bit12(tlb_s0_va_bit12),
        .tlb_asid(tlb_s0_asid),

        .vaddr_offset(inst_vaddr_offset),

        .exception_source(exception_source_IF)
    );

    pipe_ID u_pipe_ID(
        .clk(clk),
        .reset(reset),

        .from_allowin(EX_allowin),
        .from_valid(IF_valid),

        .from_pc(pc_IF_to_ID),

        .inst_sram_rdata(inst_sram_rdata),

        .rf_rdata1(rf_rdata1),         
        .rf_rdata2(rf_rdata2),        

        .rf_we_EX(rf_we_EX),
        .rf_waddr_EX(rf_waddr_EX),
        .res_from_mem_EX(res_from_mem_EX),
        .alu_result_EX(alu_result), // 用于数据前�??

        .rf_we_MEM(rf_we_MEM),
        .rf_waddr_MEM(rf_waddr_MEM),
        .mem_waiting(mem_waiting),
        .rf_wdata_MEM(rf_wdata),    // 用于数据前�??
        
        .rf_we_WB(rf_we_WB),
        .rf_waddr_WB(rf_waddr_WB),
        .rf_wdata_WB(rf_wdata_WB),  // 用于数据前�??

        .csr_en_EX(csr_en_EX),      // 防止csr冲突
        .csr_en_MEM(csr_en_MEM),
        .csr_we_EX(csr_we_EX),      // 防止csr冲突
        .csr_we_MEM(csr_we_MEM),
        .csr_we_WB(csr_we_WB),
        .rd_cnt_EX(rd_cnt_EX),
        .rd_cnt_MEM(rd_cnt_MEM),
        
        .ex_WB(ex_WB),
        .flush_WB(ertn_flush_WB),
        .tlb_flush_WB(tlb_flush_WB),

        .has_int(has_int),         // 中断信号

        .exception_source_in(exception_source_IF),

        .to_valid(ID_valid),       // IF数据可以发出
        .to_allowin(ID_allowin),     // 允许preIF阶段的数据进�?

        .br_taken(br_taken),       // 跳转信号
        .br_target(br_target),    

        .rf_raddr1(rf_raddr1),         // 读地�?
        .rf_raddr2(rf_raddr2),

        .rf_we(rf_we),
        .rf_waddr(rf_waddr),
        .res_from_mem(res_from_mem),

        .alu_op(alu_op),         // ALU的操作码 
        .alu_src1(alu_src1),       // ALU的输�?          
        .alu_src2(alu_src2),
        
        .load_op(load_op_ID),
        .store_op(store_op),
        .mem_wdata(mem_wdata),

        .csr_num(csr_num_ID),
        .csr_en(csr_en_ID),
        .csr_we(csr_we_ID),
        .csr_wmask(csr_wmask_ID),
        .csr_wdata(csr_wdata_ID),

        .ertn_flush(ertn_flush_ID),

        .rd_cnt_op(rd_cnt_op_ID),

        .tlb_command(tlbcommand_ID),
        .invtlb_op(invtlb_op_ID),

        .tlb_flush(tlb_flush_ID),

        .exception_source(exception_source_ID),

        .PC(pc_ID_to_EX)
    );

    pipe_EX u_pipe_EX(
        .clk(clk),  
        .reset(reset),  

        .from_allowin(MEM_allowin),   // ID周期允许数据进入
        .from_valid(ID_valid),     // preIF数据可以发出

        .from_pc(pc_ID_to_EX), 

        .alu_op_ID(alu_op),         // ALU的操作码 
        .alu_src1_ID(alu_src1),       // ALU的输�?         
        .alu_src2_ID(alu_src2),

        .rf_we_ID(rf_we),
        .rf_waddr_ID(rf_waddr),
        .res_from_mem_ID(res_from_mem),

        .load_op_ID(load_op_ID),
        .store_op_ID(store_op),
        .mem_wdata_ID(mem_wdata),

        .csr_num_ID(csr_num_ID),
        .csr_en_ID(csr_en_ID),
        .csr_we_ID(csr_we_ID),
        .csr_wmask_ID(csr_wmask_ID),
        .csr_wdata_ID(csr_wdata_ID),
        
        .ertn_flush_ID(ertn_flush_ID),

        .ex_MEM(ex_MEM),
        .flush_MEM(ertn_flush_MEM),
        .ex_WB(ex_WB),
        .flush_WB(ertn_flush_WB),
        .tlb_flush_WB(tlb_flush_WB),
        
        .rd_cnt_op_ID(rd_cnt_op_ID),

        .csr_crmd_value(csr_crmd_value),
        .csr_dwm0_value(csr_dwm0_value),
        .csr_dwm1_value(csr_dwm1_value),

        .tlbcommand_ID(tlbcommand_ID),
        .invtlb_op_ID(invtlb_op_ID),     
        .csr_asid_asid(csr_asid_asid),   
        .csr_tlbehi_vppn(csr_tlbehi_vppn),  

        .tlb_flush_ID(tlb_flush_ID),

        // tlb 查询结果
        .tlb_found(tlb_s1_found),
        .tlb_index(tlb_s1_index),
        .tlb_ppn(tlb_s1_ppn),
        .tlb_ps(tlb_s1_ps),
        .tlb_plv(tlb_s1_plv),
        .tlb_mat(tlb_s1_mat),
        .tlb_d(tlb_s1_d),
        .tlb_v(tlb_s1_v),    
    
        .exception_source_in(exception_source_ID),

        .to_valid(EX_valid),       // IF数据可以发出
        .to_allowin(EX_allowin),     // 允许preIF阶段的数据进�? 

        .alu_result(alu_result), // 用于MEM阶段计算结果

        .rf_we(rf_we_EX),          // 用于读写对比
        .rf_waddr(rf_waddr_EX),
        .res_from_mem(res_from_mem_EX),

        .load_op(load_op_EX),

        .data_sram_req(data_sram_req),
        .data_sram_wr(data_sram_wr),
        .data_sram_size(data_sram_size),
        .data_sram_wstrb(data_sram_wstrb),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_addr_ok(data_sram_addr_ok),

        .csr_num(csr_num_EX),
        .csr_en_out(csr_en_EX),
        .csr_we_out(csr_we_EX),
        .csr_wmask_out(csr_wmask_EX),
        .csr_wdata_out(csr_wdata_EX),

        .ertn_flush_out(ertn_flush_EX),

        .rd_cnt(rd_cnt_EX),
        .rd_cnt_op(rd_cnt_op_EX),
        .rd_timer(rd_timer_EX),

        .wb_vaddr(wb_vaddr_EX),   // 无效地址

        .exception_source(exception_source_EX),

        .tlb_command(tlbcommand_EX),

        // tlb 查询输入
        .tlb_vppn(tlb_s1_vppn),
        .tlb_va_bit12(tlb_s1_va_bit12),
        .tlb_asid(tlb_s1_asid),

        .invtlb_valid(tlb_invtlb_valid),
        .invtlb_op(tlb_invtlb_op),  

        .tlb_flush(tlb_flush_EX),

        .PC(pc_EX_to_MEM)
    );

    pipe_MEM u_pipe_MEM(
        .clk(clk),
        .reset(reset), 

        .from_allowin(WB_allowin),   // ID周期允许数据进入
        .from_valid(EX_valid),     // preIF数据可以发出

        .from_pc(pc_EX_to_MEM), 
        .load_op_EX(load_op_EX),
        .alu_result_EX(alu_result), // 用于MEM阶段计算结果

        .rf_we_EX(rf_we_EX),
        .rf_waddr_EX(rf_waddr_EX),
        .res_from_mem_EX(res_from_mem_EX),

        .data_sram_req(data_sram_req),
        .data_sram_rdata(data_sram_rdata),
        .data_sram_data_ok(data_sram_data_ok),

        .csr_num_EX(csr_num_EX),
        .csr_en_EX(csr_en_EX),
        .csr_we_EX(csr_we_EX),
        .csr_wmask_EX(csr_wmask_EX),
        .csr_wdata_EX(csr_wdata_EX),

        .ertn_flush_EX(ertn_flush_EX),

        .ex_WB(ex_WB),
        .flush_WB(ertn_flush_WB),
        .tlb_flush_WB(tlb_flush_WB),

        .rd_cnt_op_EX(rd_cnt_op_EX),
        .rd_timer_EX(rd_timer_EX),

        .exception_source_in(exception_source_EX),
        .wb_vaddr_EX(wb_vaddr_EX),  // 无效地址

        .tlbcommand_EX(tlbcommand_EX),
        .tlb_flush_EX(tlb_flush_EX),

        .to_valid(MEM_valid),       // IF数据可以发出
        .to_allowin(MEM_allowin),     // 允许preIF阶段的数据进�?

        .mem_waiting(mem_waiting),

        .rf_we(rf_we_MEM),          // 用于读写对比
        .rf_waddr(rf_waddr_MEM),
        .rf_wdata(rf_wdata), // 用于MEM阶段计算�?????

        .csr_num(csr_num_MEM),
        .csr_en_out(csr_en_MEM),
        .csr_we_out(csr_we_MEM),
        .csr_wmask(csr_wmask_MEM),
        .csr_wdata(csr_wdata_MEM),

        .ex_MEM(ex_MEM),
        .ertn_flush_out(ertn_flush_MEM),

        .rd_cnt(rd_cnt_MEM),
        .rd_cnt_op(rd_cnt_op_MEM),
        .rd_timer(rd_timer_MEM),
        
        .wb_vaddr(wb_vaddr_MEM),
        .exception_source(exception_source_MEM),

        .tlb_command(tlbcommand_MEM),
        .tlb_flush(tlb_flush_MEM),

        .PC(pc_MEM_to_WB)
    );

    pipe_WB u_pipe_WB(
        .clk(clk),
        .reset(reset), 

        .from_valid(MEM_valid),     
        .from_pc(pc_MEM_to_WB), 
        
        .to_allowin(WB_allowin),    
        .to_valid(WB_valid), 

        .rf_we_MEM(rf_we_MEM),
        .rf_waddr_MEM(rf_waddr_MEM),
        .rf_wdata_MEM(rf_wdata),   // �?????后要写进寄存器的结果是否来自�?????

        .csr_num_MEM(csr_num_MEM),
        .csr_en_MEM(csr_en_MEM),
        .csr_we_MEM(csr_we_MEM),
        .csr_wmask_MEM(csr_wmask_MEM),
        .csr_wdata_MEM(csr_wdata_MEM),

        .ertn_flush_MEM(ertn_flush_MEM),     
        .csr_rvalue(csr_rvalue),

        .rd_cnt_op_MEM(rd_cnt_op_MEM),
        .rd_timer_MEM(rd_timer_MEM),

        .exception_source_in(exception_source_MEM),
        .wb_vaddr_MEM(wb_vaddr_MEM), // 无效地址

        .tlbcommand_MEM(tlbcommand_MEM),
        .tlb_flush_MEM(tlb_flush_MEM),

        .rf_we(rf_we_WB),          
        .rf_waddr(rf_waddr_WB),
        .rf_wdata(rf_wdata_WB),

        .csr_num(csr_num_WB),
        .csr_we_out(csr_we_WB),
        .csr_wmask(csr_wmask_WB),
        .csr_wdata(csr_wdata_WB),

        .ertn_flush_out(ertn_flush_WB),     // 之后要写进寄存器的结果是否来自内�???

        .rd_cnt_op(rd_cnt_op_WB),
        .rd_timer(rd_timer_WB),

        .wb_ex(ex_WB),     // 异常信号
        .wb_ecode(wb_ecode_WB),  // 异常类型�?级代�?
        .wb_esubcode(wb_esubcode_WB), // 异常类型二级代码
        .wb_vaddr(wb_vaddr_WB), // 无效指令地址
        .exception_source(exception_source_WB),

        .tlbrd_out(tlbrd),
        .tlbwr_out(tlbwr),
        .tlbfill_out(tlbfill),

        .tlb_flush_out(tlb_flush_WB),

        .PC(pc_WB)
    );

    regfile u_regfile(
        .clk    (clk      ),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2),
        .we     (rf_we_WB & WB_valid),
        .waddr  (rf_waddr_WB),
        .wdata  (rf_wdata_WB)
    );

    csr u_csr( 
        .clk(clk),
        .reset(reset),

        .csr_num(csr_num_WB),
        .csr_we(csr_we_WB),
        .csr_wmask(csr_wmask_WB),
        .csr_wdata(csr_wdata_WB),

        .hw_int_in(8'b0),  // 硬件外部中断    !!!!!!!!! 这里要实�???
        .ipi_int_in(1'b0), // 核间中断  

        .wb_ex(ex_WB),     // 异常信号
        .wb_ecode(wb_ecode_WB),  // 异常类型�?级代�?
        .wb_esubcode(wb_esubcode_WB), // 异常类型二级代码
        .wb_pc(pc_WB),     // 异常指令地址
        .wb_vaddr(wb_vaddr_WB), // 无效数据地址          !!!!!!!!! 这里要实�???
        .exception_source(exception_source_WB),

        .ertn_flush(ertn_flush_WB), // 异常返回信号
        .coreid_in(1'b0), // 核ID                 !!!!!!!!! 这里要实现吗�???

        .csr_rvalue(csr_rvalue),
        .ex_entry(ex_entry),   // 异常入口地址，�?�往pre_IF阶段
        .has_int(has_int),     // 中断信号

        // for tlbrd
        .tlbrd(tlbrd),
        .csr_tlbehi_vppn_in({18{tlb_r_e}} & tlb_r_vppn), // vppn from tlb
        .csr_tlbelo0_in({31{tlb_r_e}} & {4'b0, tlb_r_ppn0, 1'b0, tlb_r_g, tlb_r_mat0, tlb_r_plv0, tlb_r_d0, tlb_r_v0}),
        .csr_tlbelo1_in({31{tlb_r_e}} & {4'b0, tlb_r_ppn1, 1'b0, tlb_r_g, tlb_r_mat1, tlb_r_plv1, tlb_r_d1, tlb_r_v1}),
        .csr_tlbidx_in({~tlb_r_e, 1'b0, {6{tlb_r_e}} & tlb_r_ps, 24'b0}),
        .csr_asid_asid_in({10{tlb_r_e}} & tlb_r_asid),

        .csr_asid_asid(csr_asid_asid),   
        .csr_tlbehi_vppn(csr_tlbehi_vppn), 
        .csr_tlbidx(csr_tlbidx),
        .csr_tlbelo0(csr_tlbelo0),
        .csr_tlbelo1(csr_tlbelo1),

        .csr_crmd_value(csr_crmd_value),
        .csr_dwm0_value(csr_dwm0_value),
        .csr_dwm1_value(csr_dwm1_value)
    );

    sram_to_axi_bridge bridge(
        
        .aclk               (clk),
        .areset             (reset),

        .inst_sram_req      (icache_rd_req), // 修改到cache
        .inst_sram_wr       (1'b0),      
        .inst_sram_size     (icache_rd_type),   
        .inst_sram_wstrb    (4'b0),  
        .inst_sram_addr     (icache_rd_addr),    
        .inst_sram_wdata    (32'b0),    
        .inst_sram_addr_ok  (icache_rd_rdy),
        .inst_sram_data_ok  (icache_ret_valid),
        .inst_sram_rdata    (icache_ret_data),
        .inst_sram_rlast    (icache_ret_last),

        .data_sram_req      (data_sram_req),    
        .data_sram_wr       (data_sram_wr),     
        .data_sram_size     (data_sram_size),   
        .data_sram_wstrb    (data_sram_wstrb),  
        .data_sram_addr     (data_sram_addr),
        .data_sram_wdata    (data_sram_wdata),
        .data_sram_addr_ok  (data_sram_addr_ok),
        .data_sram_data_ok  (data_sram_data_ok),
        .data_sram_rdata    (data_sram_rdata),

        .arid               (arid),
        .araddr             (araddr),
        .arlen              (arlen),
        .arsize             (arsize),
        .arburst            (arburst),
        .arlock             (arlock),
        .arcache            (arcache),
        .arprot             (arprot),
        .arvalid            (arvalid),
        .arready            (arready),

        .rid                (rid),
        .rdata              (rdata),
        .rresp              (rresp),
        .rlast              (rlast),
        .rvalid             (rvalid),
        .rready             (rready),

        .awid               (awid),
        .awaddr             (awaddr),
        .awlen              (awlen),
        .awsize             (awsize),
        .awburst            (awburst),
        .awlock             (awlock),
        .awcache            (awcache),
        .awprot             (awprot),
        .awvalid            (awvalid),
        .awready            (awready),

        .wid                (wid),
        .wdata              (wdata),
        .wstrb              (wstrb),
        .wlast              (wlast),
        .wvalid             (wvalid),
        .wready             (wready),

        .bid                (bid),
        .bresp              (bresp),
        .bvalid             (bvalid),
        .bready             (bready)
    );

    // 实例化 cache 模块
    cache u_icache(
        .clk(clk),
        .reset(reset),

        .valid(inst_sram_req),
        .op(inst_sram_wr),
        .index(inst_vaddr_offset[11:4]),
        .tag(inst_sram_addr[31:12]),
        .offset(inst_vaddr_offset[3:0]),
        .wstrb(inst_sram_wstrb),
        .wdata(inst_sram_wdata),

        .addr_ok(inst_sram_addr_ok),
        .data_ok(inst_sram_data_ok),
        .rdata(inst_sram_rdata),

        .rd_req(icache_rd_req),
        .rd_type(icache_rd_type),
        .rd_addr(icache_rd_addr),

        .rd_rdy(icache_rd_rdy),
        .ret_valid(icache_ret_valid),
        .ret_last(icache_ret_last),
        .ret_data(icache_ret_data),

        .wr_req(),
        .wr_type(),
        .wr_addr(),
        .wr_wstrb(),
        .wr_data(),

        .wr_rdy()
    );

    // 实例化 tlb 模块
    // tlbfill 指令随机生成index
    reg [3:0] tlbfill_index;
    wire [3:0] tlb_w_index;
    always @(posedge clk) begin
        if(reset)
            tlbfill_index <= 4'b0;
        else if (tlbfill) 
            tlbfill_index <= tlbfill_index + 1'b1;
    end
    assign tlb_w_index = (tlbfill)? tlbfill_index : csr_tlbidx[3:0];
    tlb u_tlb (
        .clk(clk),

        .s0_vppn(tlb_s0_vppn),
        .s0_va_bit12(tlb_s0_va_bit12),
        .s0_asid(tlb_s0_asid),
        .s0_found(tlb_s0_found),
        .s0_index(tlb_s0_index),
        .s0_ppn(tlb_s0_ppn),
        .s0_ps(tlb_s0_ps),
        .s0_plv(tlb_s0_plv),
        .s0_mat(tlb_s0_mat),
        .s0_d(tlb_s0_d),
        .s0_v(tlb_s0_v),

        .s1_vppn(tlb_s1_vppn),
        .s1_va_bit12(tlb_s1_va_bit12),
        .s1_asid(tlb_s1_asid),
        .s1_found(tlb_s1_found),
        .s1_index(tlb_s1_index),
        .s1_ppn(tlb_s1_ppn),
        .s1_ps(tlb_s1_ps),
        .s1_plv(tlb_s1_plv),
        .s1_mat(tlb_s1_mat),
        .s1_d(tlb_s1_d),
        .s1_v(tlb_s1_v),

        .invtlb_valid(tlb_invtlb_valid),
        .invtlb_op(tlb_invtlb_op),

        .we(tlbwr | tlbfill),
        .w_index(tlb_w_index),
        .w_e(~csr_tlbidx[`CSR_TLBIDX_NE]),
        .w_vppn(csr_tlbehi_vppn),
        .w_ps(csr_tlbidx[`CSR_TLBIDX_PS]),
        .w_asid(csr_asid_asid),
        .w_g(csr_tlbelo0[`CSR_TLBELO_G] & csr_tlbelo1[`CSR_TLBELO_G]),
        .w_ppn0(csr_tlbelo0[`CSR_TLBELO_PPN]),
        .w_plv0(csr_tlbelo0[`CSR_TLBELO_PLV]),
        .w_mat0(csr_tlbelo0[`CSR_TLBELO_MAT]),
        .w_d0(csr_tlbelo0[`CSR_TLBELO_D]),
        .w_v0(csr_tlbelo0[`CSR_TLBELO_V]),
        .w_ppn1(csr_tlbelo1[`CSR_TLBELO_PPN]),
        .w_plv1(csr_tlbelo1[`CSR_TLBELO_PLV]),
        .w_mat1(csr_tlbelo1[`CSR_TLBELO_MAT]),
        .w_d1(csr_tlbelo1[`CSR_TLBELO_D]),
        .w_v1(csr_tlbelo1[`CSR_TLBELO_V]),

        .r_index(csr_tlbidx[3:0]),
        .r_e(tlb_r_e),
        .r_vppn(tlb_r_vppn),
        .r_ps(tlb_r_ps),
        .r_asid(tlb_r_asid),
        .r_g(tlb_r_g),
        .r_ppn0(tlb_r_ppn0),
        .r_plv0(tlb_r_plv0),
        .r_mat0(tlb_r_mat0),
        .r_d0(tlb_r_d0),
        .r_v0(tlb_r_v0),
        .r_ppn1(tlb_r_ppn1),
        .r_plv1(tlb_r_plv1),
        .r_mat1(tlb_r_mat1),
        .r_d1(tlb_r_d1),
        .r_v1(tlb_r_v1)
    );

        

    // debug info generate
    assign debug_wb_pc       = pc_WB;
    assign debug_wb_rf_we   = {4{rf_we_WB}}; 
    assign debug_wb_rf_wnum  = rf_waddr_WB;
    assign debug_wb_rf_wdata = rf_wdata_WB;

endmodule
