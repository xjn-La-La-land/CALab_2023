module pipe_MEM(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入
    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc, 
    input  wire [ 4:0] load_op_EX,    // 用与MEM阶段处理内存读数据
    input  wire [31:0] alu_result_EX, // 用于MEM阶段计算结果

    input  wire        rf_we_EX,
    input  wire [ 4:0] rf_waddr_EX,
    input  wire        res_from_mem_EX,   // 之后要写进寄存器的结果是否来自内存

    input  wire [31:0] data_sram_rdata,   // 内存读数据

    input  wire [13:0] csr_num_EX,
    input  wire        csr_en_EX,
    input  wire        csr_we_EX,
    input  wire [31:0] csr_wmask_EX,
    input  wire [31:0] csr_wdata_EX,

    input  wire        ertn_flush_EX,    // ertn指令向后推�??

    input  wire        ex_WB,            // 异常指令到达WB级，清空流水线
    input  wire        flush_WB,         // ertn指令到达WB级，清空流水线

    input  wire [ 2:0] rd_cnt_op_EX,     // {inst_rdcntvh_w, inst_rdcntvl_w, inst_rdcntid}
    input  wire [31:0] rd_timer_EX,

    input  wire [5:0]  exception_source_in, // {INE, BRK, SYS, ALE, ADEF, INT}
    input  wire [31:0] wb_vaddr_EX,      // 无效地址

    output wire        to_valid,         // IF数据可以发出
    output wire        to_allowin,       // 允许preIF阶段的数据进入

    output wire        rf_we,
    output reg  [ 4:0] rf_waddr,
    output wire [31:0] rf_wdata,

    output reg [13:0]  csr_num,
    output wire        csr_en_out,
    output wire        csr_we_out,
    output reg [31:0]  csr_wmask,
    output reg [31:0]  csr_wdata,

    output wire        ex_MEM,
    output wire        ertn_flush_out,

    output wire        rd_cnt,           // 用于前递
    output reg [ 2:0]  rd_cnt_op,        // {inst_rdcntvh_w, inst_rdcntvl_w, inst_rdcntid}
    output reg [31:0]  rd_timer,         // 计时器读信号和读数据

    output reg [31:0]  wb_vaddr,  // 无效地址

    output reg  [5:0]  exception_source, // {INE, BRK, SYS, ALE, ADEF, INT}

    output reg [31:0]  PC
);

wire ready_go;              // 数据处理完成信号
reg valid;
assign ready_go = valid;
assign to_allowin = !valid || ready_go && from_allowin || ex_WB || flush_WB; 
assign to_valid = valid & ready_go & ~flush_WB & ~ex_WB;
    
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b0;
    end
    else if(to_allowin) begin // 如果当前阶段允许数据进入，则数据是否有效就取决于上一阶段数据是否可以发出
        valid <= from_valid;
    end
end

wire data_allowin; // 拉手成功，数据可以进�???
assign data_allowin = from_valid && to_allowin;
always @(posedge clk) begin
    if (reset) begin
        PC <= 32'b0;
    end
    else if(data_allowin) begin
        PC <= from_pc;
    end
end

wire [ 7:0] mem_byte;
wire [15:0] mem_halfword;
wire [31:0] mem_result;         // 从内存中读出的数据

reg  [ 4:0] load_op;
reg  [31:0] alu_result;
always @(posedge clk) begin
    if (reset) begin
        load_op    <= 5'b0;
        alu_result <= 32'b0;
    end
    else if(data_allowin) begin
        load_op    <= load_op_EX;
        alu_result <= alu_result_EX;
    end
end

reg res_from_mem;
reg gr_we;
always @(posedge clk) begin
    if (reset) begin
        rf_waddr <= 5'b0;
        gr_we <= 1'b0;
        res_from_mem <= 1'b0;
    end
    else if(data_allowin) begin
        rf_waddr <= rf_waddr_EX;
        gr_we <= rf_we_EX;
        res_from_mem <= res_from_mem_EX;
    end
end

assign rf_we = gr_we && valid;


assign mem_byte     = {8{alu_result[1:0]==2'b00}} & data_sram_rdata[ 7: 0] |
                        {8{alu_result[1:0]==2'b01}} & data_sram_rdata[15: 8] |
                        {8{alu_result[1:0]==2'b10}} & data_sram_rdata[23:16] |
                        {8{alu_result[1:0]==2'b11}} & data_sram_rdata[31:24];
assign mem_halfword = {16{alu_result[1:0]==2'b00}} & data_sram_rdata[15:0] |
                        {16{alu_result[1:0]==2'b10}} & data_sram_rdata[31:16];

assign mem_result   = {32{load_op[4]}} & {{24{mem_byte[7]}}, mem_byte} |  // ld.b
                        {32{load_op[3]}} & {{24'b0}, mem_byte} |            // ld.bu
                        {32{load_op[2]}} & {{16{mem_halfword[15]}}, mem_halfword} | // ld.h
                        {32{load_op[1]}} & {{16'b0}, mem_halfword} |        // ld.hu
                        {32{load_op[0]}} & data_sram_rdata;                 // ld.w

assign rf_wdata = res_from_mem ? mem_result : alu_result;


/* ------------------------------------------------例外处理-------------------------------------------------------*/
reg     csr_en;
reg     csr_we;
reg     ertn_flush;

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
        csr_en <= csr_en_EX;
        csr_we <= csr_we_EX;
        ertn_flush <= ertn_flush_EX;

        csr_num <= csr_num_EX;
        csr_wmask <= csr_wmask_EX;
        csr_wdata <= csr_wdata_EX;
    end
end

assign csr_en_out = csr_en && valid;
assign csr_we_out = csr_we && valid;
assign ertn_flush_out = ertn_flush && valid;

always @(posedge clk) begin
    if (reset) begin
        rd_cnt_op <= 3'b0;
        rd_timer <= 32'b0;
    end
    else begin
        rd_cnt_op <= rd_cnt_op_EX;
        rd_timer <= rd_timer_EX;
    end
end

assign rd_cnt = (rd_cnt_op != 3'b0);

always @(posedge clk) begin
    if (reset) begin
        exception_source <= 6'b0;
        wb_vaddr <= 32'b0;
    end
    else if(data_allowin) begin
        exception_source <= exception_source_in;
        wb_vaddr <= wb_vaddr_EX;
    end
end

assign ex_MEM = (exception_source != 6'b0);

endmodule