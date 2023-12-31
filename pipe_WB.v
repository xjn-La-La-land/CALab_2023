`include "define.v"

module pipe_WB(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc, 

    output wire        to_allowin,     // 允许preIF阶段的数据进入
    output wire        to_valid, 

    input  wire        rf_we_MEM,
    input  wire [ 4:0] rf_waddr_MEM,
    input  wire [31:0] rf_wdata_MEM,   // 之后要写进寄存器的结果是否来自内存

    input  wire [13:0] csr_num_MEM,
    input  wire        csr_en_MEM,
    input  wire        csr_we_MEM,
    input  wire [31:0] csr_wmask_MEM,
    input  wire [31:0] csr_wdata_MEM,

    input  wire        ertn_flush_MEM,  
       
    input  wire [31:0] csr_rvalue,      // 当拍从csr寄存器返回的读数据

    input  wire [ 2:0] rd_cnt_op_MEM,
    input  wire [31:0] rd_timer_MEM,

    input  wire [13:0] exception_source_in,  // {TLBR(IF), TLBR(EX), INE, BRK, SYS, ALE, ADEF, PPI(IF), PPI(EX), PME, PIF, PIS, PIL, INT}
    input  wire [31:0] wb_vaddr_MEM,         // 无效地址

    input  wire [ 2:0] tlbcommand_MEM,
    input  wire        tlb_flush_MEM,
    
    output wire        rf_we,          // 用于读写对比
    output reg  [ 4:0] rf_waddr,
    output wire [31:0] rf_wdata,

    output reg [13:0]  csr_num,
    output wire        csr_we_out,
    output reg [31:0]  csr_wmask,
    output reg [31:0]  csr_wdata,

    output wire        ertn_flush_out,

    output reg [ 2:0] rd_cnt_op,
    output reg [31:0] rd_timer,       // 计时器读信号和读数据

    output wire       wb_ex,        // 异常信号
    output wire [5:0] wb_ecode,     // 异常类型一级代码
    output wire [8:0] wb_esubcode,  // 异常类型二级代码
    output reg [31:0] wb_vaddr,     // 无效数据地址
    output reg [13:0] exception_source,

    output wire       tlbrd_out,
    output wire       tlbwr_out,
    output wire       tlbfill_out,

    output wire       tlb_flush_out,

    output reg [31:0]  PC
);


reg valid;
assign to_allowin = 1'b1; 
assign to_valid = valid;
    
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b0;
    end
    else if(to_allowin) begin // 如果当前阶段允许数据进入，则数据是否有效就取决于上一阶段数据是否可以发出
        valid <= from_valid;
    end
end

wire data_allowin; // 拉手成功，数据可以进入
assign data_allowin = from_valid && to_allowin;

always @(posedge clk) begin
    if (reset) begin
        PC <= 32'b0;
    end
    else if(data_allowin) begin
        PC <= from_pc;
    end
end

reg [31:0] rf_wdata1; // 未考虑csr读数的情况
reg        gr_we;
always @(posedge clk) begin
    if (reset) begin
        rf_waddr <= 5'b0;
        gr_we <= 1'b0;
        rf_wdata1 <= 31'b0;
    end
    else if(data_allowin) begin
        rf_waddr <= rf_waddr_MEM;
        gr_we <= rf_we_MEM;
        rf_wdata1 <= rf_wdata_MEM;
    end
end

assign rf_we = gr_we && to_valid && ~wb_ex && ~tlb_flush_out;  // !!异常指令不写回


/* ------------------------------------------------例外处理-------------------------------------------------------*/
reg        csr_en;
reg        csr_we;
reg        ertn_flush;

always @(posedge clk) begin
    if (reset) begin
        csr_en <= 1'b0;
        csr_we <= 1'b0;
        ertn_flush <= 1'b0;

        csr_num <= 14'b0;
        csr_wmask <= 32'b0;
        csr_wdata <= 32'b0;
    end
    else if(data_allowin) begin
        csr_en <= csr_en_MEM;
        csr_we <= csr_we_MEM;
        ertn_flush <= ertn_flush_MEM;

        csr_num <= csr_num_MEM;
        csr_wmask <= csr_wmask_MEM;
        csr_wdata <= csr_wdata_MEM;
    end
end

assign csr_we_out = csr_we && ~tlb_flush_out && valid ;
assign ertn_flush_out = ertn_flush && ~tlb_flush_out && valid && ~wb_ex;

assign rf_wdata = (csr_en || rd_cnt_op[0])       ? csr_rvalue : 
                  (rd_cnt_op[1] || rd_cnt_op[2]) ? rd_timer   : rf_wdata1;

always @(posedge clk) begin
    if (reset) begin
        rd_cnt_op <= 3'b0;
        rd_timer <= 32'b0;
    end
    else begin
        rd_cnt_op <= rd_cnt_op_MEM;
        rd_timer <= rd_timer_MEM;
    end
end

always @(posedge clk) begin
    if (reset) begin
        exception_source <= 14'b0;
        wb_vaddr <= 32'b0;
    end
    else if(data_allowin) begin
        exception_source <= exception_source_in;
        wb_vaddr <= wb_vaddr_MEM;
    end
end

assign wb_ex       = (exception_source != 12'b0) && ~tlb_flush_out && valid;
// {TLBR(IF), TLBR(EX), INE, BRK, SYS, ALE, ADEF, PPI(IF), PPI(EX), PME, PIF, PIS, PIL, INT}
assign wb_ecode    = {6{exception_source[13] || exception_source[12]}} & (`ECODE_TLBR) |
                     {6{exception_source[11]}} & (`ECODE_INE)  |
                     {6{exception_source[10]}} & (`ECODE_BRK)  |
                     {6{exception_source[9]}} & (`ECODE_SYS)   |
                     {6{exception_source[8]}} & (`ECODE_ALE)   |
                     {6{exception_source[7]}} & (`ECODE_ADE)   |
                     {6{exception_source[6] || exception_source[5]}} & (`ECODE_PPI)   |
                     {6{exception_source[4]}} & (`ECODE_PME)   |
                     {6{exception_source[3]}} & (`ECODE_PIF)   |
                     {6{exception_source[2]}} & (`ECODE_PIS)   |
                     {6{exception_source[1]}} & (`ECODE_PIL)   |
                     {6{exception_source[0]}} & (`ECODE_INT);

assign wb_esubcode = `ESUBCODE_ADEF;  // 取指地址在adef检查是否对齐，load/store地址在ale检查是否对齐


/*-------------------------------------tlb command process------------------------------------*/
// tlbcommand_MEM = {inst_tlbrd, inst_tlbfill, inst_tlbwr}
reg tlbrd, tlbwr, tlbfill;
always @(posedge clk) begin
    if (reset) begin
        tlbrd <= 1'b0;
        tlbwr <= 1'b0;
        tlbfill <= 1'b0;
    end
    else if(data_allowin) begin
        tlbrd <= tlbcommand_MEM[2];
        tlbwr <= tlbcommand_MEM[0];
        tlbfill <= tlbcommand_MEM[1];
    end
end
assign tlbrd_out = tlbrd && ~tlb_flush_out && valid;
assign tlbwr_out = tlbwr && ~tlb_flush_out && valid;
assign tlbfill_out = tlbfill && ~tlb_flush_out && valid;

reg tlb_flush;
always @(posedge clk) begin
    if (reset) begin
        tlb_flush <= 1'b0;
    end
    else if(data_allowin) begin
        tlb_flush <= tlb_flush_MEM;
    end
end
assign tlb_flush_out = tlb_flush && valid;


endmodule