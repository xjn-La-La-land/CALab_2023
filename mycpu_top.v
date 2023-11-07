module mycpu_top(

    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire [3:0]  inst_sram_we,    // RAM字节写使�???
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    output wire        inst_sram_en,    // RAM的片选信号，高电平有�???
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire        data_sram_en,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    reg         reset;
    always @(posedge clk) reset <= ~resetn;
    
    wire [31:0] pc_preIF_to_IF;
    wire [31:0] pc_IF_to_ID;
    wire [31:0] pc_ID_to_EX;
    wire [31:0] pc_EX_to_MEM;
    wire [31:0] pc_MEM_to_WB;
    wire [31:0] pc_WB;

    wire        IF_allowin;
    wire        ID_allowin;
    wire        EX_allowin;
    wire        MEM_allowin;
    wire        WB_allowin;

    wire        preIF_valid;
    wire        IF_valid;
    wire        ID_valid;
    wire        EX_valid;
    wire        MEM_valid;
    wire        WB_valid;

    wire        br_taken;      // 跳转信号
    wire [31:0] br_target;

    wire [31:0] rf_rdata1;         // 读数据
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

    wire [ 4:0] rf_raddr1;        // 读地址
    wire [ 4:0] rf_raddr2;
    wire        rf_we;
    wire [ 4:0] rf_waddr;
    wire        res_from_mem;

    wire [18:0] alu_op;         // ALU的操作码 
    wire [31:0] alu_src1;       // ALU的输入         
    wire [31:0] alu_src2;

    wire [ 4:0] load_op_ID;
    wire [ 2:0] store_op;
    wire [31:0] data_sram_wdata_ID;
    wire        data_sram_en_ID;

    wire [ 4:0] load_op_EX;
    wire [31:0] alu_result;

    // 控制寄存�??
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
    wire   [31:0] csr_rvalue;

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
    wire  [5:0]  exception_source_ID;
    wire  [5:0]  exception_source_EX;
    wire  [5:0]  exception_source_MEM;

    wire         ex_MEM;     

    wire         ex_WB;     
    wire  [5:0]  wb_ecode_WB; 
    wire  [8:0]  wb_esubcode_WB;
    

    // 异常相关pc
    wire  [31:0] wb_vaddr_EX;

    wire  [31:0] wb_vaddr_MEM;

    wire  [31:0] wb_pc_WB;
    wire  [31:0] wb_vaddr_WB;

    // 异常处理地址
    wire  [31:0] ex_entry;

    // 异常信号
    wire         ex_adef_IF;

    // 中断信号
    wire         has_int;


    pre_IF u_pre_IF(
        .clk          (clk),
        .reset        (reset),

        .br_taken     (br_taken),
        .br_target    (br_target),

        .from_allowin (IF_allowin),

        .ex_en        (ertn_flush_WB | ex_WB),   // 出现异常处理信号，或者ertn指令
        .ex_entry     (ex_entry),

        .to_valid     (preIF_valid),
        .nextpc       (pc_preIF_to_IF)
    );

    assign inst_sram_en    = IF_allowin; 
    assign inst_sram_we    = 4'b0;
    assign inst_sram_addr  = pc_preIF_to_IF;
    assign inst_sram_wdata = 32'b0; 

    pipe_IF u_pipe_IF(
        .clk          (clk),
        .reset        (reset),

        .from_allowin (ID_allowin),
        .from_valid   (preIF_valid),

        .from_pc      (pc_preIF_to_IF),

        .br_taken     (br_taken),

        .ex_WB        (ex_WB),
        .flush_WB     (ertn_flush_WB),

        .to_valid     (IF_valid),
        .to_allowin   (IF_allowin),

        .ex_adef      (ex_adef_IF),
        .PC           (pc_IF_to_ID)
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
        .alu_result_EX(alu_result), // 用于数据前递

        .rf_we_MEM(rf_we_MEM),
        .rf_waddr_MEM(rf_waddr_MEM),
        .rf_wdata_MEM(rf_wdata),    // 用于数据前递
        
        .rf_we_WB(rf_we_WB),
        .rf_waddr_WB(rf_waddr_WB),
        .rf_wdata_WB(rf_wdata_WB),  // 用于数据前递

        .csr_en_EX(csr_en_EX),      // 防止csr冲突
        .csr_en_MEM(csr_en_MEM),
        .csr_we_EX(csr_we_EX),      // 防止csr冲突
        .csr_we_MEM(csr_we_MEM),
        .csr_we_WB(csr_we_WB),
        .rd_cnt_EX(rd_cnt_EX),
        .rd_cnt_MEM(rd_cnt_MEM),
        
        .ex_WB(ex_WB),
        .flush_WB(ertn_flush_WB),

        .has_int(has_int),         // 中断信号

        .ex_adef_IF(ex_adef_IF),      // adef异常信号，IF级传过来

        .to_valid(ID_valid),       // IF数据可以发出
        .to_allowin(ID_allowin),     // 允许preIF阶段的数据进入

        .br_taken(br_taken),       // 跳转信号
        .br_target(br_target),    

        .rf_raddr1(rf_raddr1),         // 读地址
        .rf_raddr2(rf_raddr2),

        .rf_we(rf_we),
        .rf_waddr(rf_waddr),
        .res_from_mem(res_from_mem),

        .alu_op(alu_op),         // ALU的操作码 
        .alu_src1(alu_src1),       // ALU的输入          
        .alu_src2(alu_src2),
        
        .data_sram_en(data_sram_en_ID),
        .load_op(load_op_ID),
        .store_op(store_op),
        .data_sram_wdata(data_sram_wdata_ID),

        .csr_num(csr_num_ID),
        .csr_en(csr_en_ID),
        .csr_we(csr_we_ID),
        .csr_wmask(csr_wmask_ID),
        .csr_wdata(csr_wdata_ID),

        .ertn_flush(ertn_flush_ID),

        .rd_cnt_op(rd_cnt_op_ID),

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
        .alu_src1_ID(alu_src1),       // ALU的输入         
        .alu_src2_ID(alu_src2),

        .rf_we_ID(rf_we),
        .rf_waddr_ID(rf_waddr),
        .res_from_mem_ID(res_from_mem),

        .load_op_ID(load_op_ID),
        .store_op_ID(store_op),
        .data_sram_en_ID(data_sram_en_ID),
        .data_sram_wdata_ID(data_sram_wdata_ID),

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
        
        .rd_cnt_op_ID(rd_cnt_op_ID),

        .exception_source_in(exception_source_ID),


        .to_valid(EX_valid),       // IF数据可以发出
        .to_allowin(EX_allowin),     // 允许preIF阶段的数据进入 

        .alu_result(alu_result), // 用于MEM阶段计算结果

        .rf_we(rf_we_EX),          // 用于读写对比
        .rf_waddr(rf_waddr_EX),
        .res_from_mem(res_from_mem_EX),

        .load_op(load_op_EX),
        .data_sram_en(data_sram_en),
        .data_sram_we_out(data_sram_we),
        .data_sram_addr(data_sram_addr),
        .data_sram_wdata(data_sram_wdata),

        .csr_num(csr_num_EX),
        .csr_en_out(csr_en_EX),
        .csr_we_out(csr_we_EX),
        .csr_wmask(csr_wmask_EX),
        .csr_wdata(csr_wdata_EX),

        .ertn_flush_out(ertn_flush_EX),

        .rd_cnt(rd_cnt_EX),
        .rd_cnt_op(rd_cnt_op_EX),
        .rd_timer(rd_timer_EX),

        .wb_vaddr(wb_vaddr_EX),   // 无效地址

        .exception_source(exception_source_EX),

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
        .res_from_mem_EX(res_from_mem_EX),   // �????后要写进寄存器的结果是否来自内存

        .data_sram_rdata(data_sram_rdata),   // 读数�????

        .csr_num_EX(csr_num_EX),
        .csr_en_EX(csr_en_EX),
        .csr_we_EX(csr_we_EX),
        .csr_wmask_EX(csr_wmask_EX),
        .csr_wdata_EX(csr_wdata_EX),

        .ertn_flush_EX(ertn_flush_EX),

        .ex_WB(ex_WB),
        .flush_WB(ertn_flush_WB),

        .rd_cnt_op_EX(rd_cnt_op_EX),
        .rd_timer_EX(rd_timer_EX),


        .exception_source_in(exception_source_EX),
        .wb_vaddr_EX(wb_vaddr_EX),  // 无效地址

        .to_valid(MEM_valid),       // IF数据可以发出
        .to_allowin(MEM_allowin),     // 允许preIF阶段的数据进�???? 

        .rf_we(rf_we_MEM),          // 用于读写对比
        .rf_waddr(rf_waddr_MEM),
        .rf_wdata(rf_wdata), // 用于MEM阶段计算�????

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
        .rf_wdata_MEM(rf_wdata),   // �????后要写进寄存器的结果是否来自�????

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

        .rf_we(rf_we_WB),          
        .rf_waddr(rf_waddr_WB),
        .rf_wdata(rf_wdata_WB),

        .csr_num(csr_num_WB),
        .csr_we_out(csr_we_WB),
        .csr_wmask(csr_wmask_WB),
        .csr_wdata(csr_wdata_WB),

        .ertn_flush_out(ertn_flush_WB),     // 之后要写进寄存器的结果是否来自内�??

        .rd_cnt_op(rd_cnt_op_WB),
        .rd_timer(rd_timer_WB),

        .wb_ex(ex_WB),     // 异常信号
        .wb_ecode(wb_ecode_WB),  // 异常类型一级代码
        .wb_esubcode(wb_esubcode_WB), // 异常类型二级代码
        .wb_vaddr(wb_vaddr_WB), // 无效指令地址

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

        .hw_int_in(8'b0),  // 硬件外部中断    !!!!!!!!! 这里要实�??
        .ipi_int_in(1'b0), // 核间中断  

        .wb_ex(ex_WB),     // 异常信号
        .wb_ecode(wb_ecode_WB),  // 异常类型一级代码
        .wb_esubcode(wb_esubcode_WB), // 异常类型二级代码
        .wb_pc(pc_WB),    // 异常指令地址
        .wb_vaddr(wb_vaddr_WB), // 无效数据地址          !!!!!!!!! 这里要实�??

        .ertn_flush(ertn_flush_WB), // 异常返回信号
        .coreid_in(1'b0), // 核ID                 !!!!!!!!! 这里要实现吗�??

        .csr_rvalue(csr_rvalue),
        .ex_entry(ex_entry),   // 异常入口地址，�?�往pre_IF阶段
        .has_int(has_int)      // 中断信号
    );

    // debug info generate
    assign debug_wb_pc       = pc_WB;
    assign debug_wb_rf_we   = {4{rf_we_WB}}; 
    assign debug_wb_rf_wnum  = rf_waddr_WB;
    assign debug_wb_rf_wdata = rf_wdata_WB;

endmodule
