module pipe_EX(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入
    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc, 

    input  wire [18:0] alu_op_ID,         // ALU的操作码 
    input  wire [31:0] alu_src1_ID,       // ALU的输入         
    input  wire [31:0] alu_src2_ID,

    input  wire        rf_we_ID,
    input  wire [ 4:0] rf_waddr_ID,
    input  wire        res_from_mem_ID,   // 之后要写进寄存器的结果是否来自内存

    input  wire [ 4:0] load_op_ID,
    input  wire [ 2:0] store_op_ID,
    input  wire        data_sram_en_ID,
    input  wire [31:0] data_sram_wdata_ID,

    input  wire [13:0] csr_num_ID,
    input  wire        csr_en_ID,
    input  wire        csr_we_ID,
    input  wire [31:0] csr_wmask_ID,
    input  wire [31:0] csr_wdata_ID,

    input  wire        ertn_flush_ID,

    input  wire        ex_MEM,
    input  wire        flush_MEM,
    input  wire        ex_WB,           // 异常指令到达WB级，清空流水线
    input  wire        flush_WB,        // ertn指令到达WB级，清空流水线

    input  wire [2:0]  rd_cnt_op_ID,    // {inst_rdcntvh_w, inst_rdcntvl_w, inst_rdcntid}

    input  wire [5:0]  exception_source_in, // 6种异常源 {INE, BRK, SYS, ALE, ADEF, INT}

    output wire        to_valid,       // IF数据可以发出
    output wire        to_allowin,     // 允许preIF阶段的数据进入

    output wire [31:0] alu_result, // 用于MEM阶段计算结果

    output wire        rf_we,
    output reg  [ 4:0] rf_waddr,
    output reg         res_from_mem,   // 之后要写进寄存器的结果是否来自内存

    output reg  [ 4:0] load_op,
    output reg         data_sram_en,
    output wire [ 3:0] data_sram_we_out,
    output wire [31:0] data_sram_addr,
    output reg  [31:0] data_sram_wdata,

    output reg [13:0]  csr_num,
    output wire        csr_en_out,
    output wire        csr_we_out,
    output reg [31:0]  csr_wmask,
    output reg [31:0]  csr_wdata,

    output wire        ertn_flush_out,    // ertn指令，清空流水线

    output wire        rd_cnt,            // 用于前递
    output reg  [ 2:0] rd_cnt_op,         // {inst_rdcntvh_w, inst_rdcntvl_w, inst_rdcntid}
    output wire [31:0] rd_timer,          // 计时器读信号和读数据

    output wire [31:0] wb_vaddr,          // 无效地址

    output wire [5:0]  exception_source,  // {INE, BRK, SYS, ALE, ADEF, INT}

    output reg  [31:0] PC
);


wire ready_go;              // 数据处理完成信号
reg valid;

// 33-bit multiplier
wire op_mul_w;      //32-bit signed multiplication
wire op_mulh_w;     //32-bit signed multiplication
wire op_mulh_wu;    //32-bit unsigned multiplication
wire mul_en;

wire [32:0] multiplier_a;
wire [32:0] multiplier_b;
wire [65:0] multiplier_result;

reg  [31:0] mul_result;
reg         mul_ready;


// 32-bit divider
wire        div_en;
wire        signed_en;
wire        unsigned_en;
wire        divisor_tvalid;
wire        divisor_tready_signed;
wire        divisor_tready_unsigned;
wire        dividend_tvalid;
wire        dividend_tready_signed;
wire        dividend_tready_unsigned;
wire        div_out_valid_signed;
wire        div_out_valid_unsigned;

reg         clear_valid;
wire [63:0] div_result_signed;
wire [63:0] div_result_unsigned;

assign ready_go = valid & ~wait_div & ~(mul_en & ~mul_ready);    // 当前数据是valid并且读后写冲突完�??
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

reg    gr_we;
always @(posedge clk) begin
    if (reset) begin
        rf_waddr <= 5'b0;
        gr_we <= 1'b0;
        res_from_mem <= 1'b0;
    end
    else if(data_allowin) begin
        rf_waddr <= rf_waddr_ID;
        gr_we <= rf_we_ID;
        res_from_mem <= res_from_mem_ID;
    end
end
assign rf_we = gr_we && valid;

reg [18:0] alu_op;         // ALU的操作码
reg [31:0] alu_src1;       // ALU的输入
reg [31:0] alu_src2;
always @(posedge clk) begin
    if (reset) begin
        alu_op <= 19'b0;
        alu_src1 <= 32'b0;
        alu_src2 <= 32'b0;
    end
    else if(data_allowin) begin
        alu_op <= alu_op_ID;
        alu_src1 <= alu_src1_ID;
        alu_src2 <= alu_src2_ID;
    end
end

wire [31:0] alu_result1; // 非除法、乘法运算结果
reg  [2:0] store_op;      // 存储输入的store_op_ID
wire [3:0] st_b_strb;    // 内存写数据字节掩码
wire [3:0] st_h_strb;
wire [3:0] st_w_strb;

wire [3:0]  data_sram_we;

always @(posedge clk) begin
    if (reset) begin
        load_op         <= 5'b0;
        store_op        <= 3'b0;
        data_sram_en    <= 1'b0;
        data_sram_wdata <= 32'b0;
    end
    else if(data_allowin) begin
        load_op         <= load_op_ID;
        store_op        <= store_op_ID;
        data_sram_en    <= data_sram_en_ID;
        data_sram_wdata <= data_sram_wdata_ID;
    end
end

// data_sram_we的赋值
assign st_b_strb = {4{alu_result1[1:0]==2'b00}} & {4'b0001} |
                    {4{alu_result1[1:0]==2'b01}} & {4'b0010} |
                    {4{alu_result1[1:0]==2'b10}} & {4'b0100} |
                    {4{alu_result1[1:0]==2'b11}} & {4'b1000};
assign st_h_strb = {4{alu_result1[1:0]==2'b00}} & {4'b0011} |
                    {4{alu_result1[1:0]==2'b10}} & {4'b1100};
assign st_w_strb = 4'b1111;
assign data_sram_we = {4{store_op[2]}} & st_b_strb |
                      {4{store_op[1]}} & st_h_strb |
                      {4{store_op[0]}} & st_w_strb;

assign data_sram_addr  = {alu_result[31:2], 2'b00};

alu u_alu(
    .alu_op     (alu_op[11:0]),
    .alu_src1   (alu_src1  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result1)
); 


// 乘法运算赋值
assign op_mul_w  = alu_op[12];
assign op_mulh_w = alu_op[13];
assign op_mulh_wu = alu_op[14];
assign mul_en = op_mul_w | op_mulh_w | op_mulh_wu;


assign multiplier_a = {{op_mulh_w & alu_src1[31]}, alu_src1};
assign multiplier_b = {{op_mulh_w & alu_src2[31]}, alu_src2};

assign multiplier_result = $signed(multiplier_a) * $signed(multiplier_b);

always@(posedge clk) begin // 将乘法结果写入寄存器，阻塞一拍防止时序问题
    if (reset) begin
        mul_result <= 66'b0;
        mul_ready <= 1'b0;
    end
    else if(mul_en) begin
        mul_result <= (op_mul_w) ? multiplier_result[31:0] : multiplier_result[63:32];
        mul_ready <= 1'b1;
    end
    else
        mul_ready <= 1'b0;
end


// 除法运算赋值
always @(posedge clk) begin // 用于拉手成功后时钟上升沿清除valid信号
    if (reset) begin
        clear_valid <= 1'b0;
    end
    else if(data_allowin) begin
        clear_valid <= 1'b1;
    end
    else if(divisor_tvalid && ((dividend_tready_signed & signed_en) || (dividend_tready_unsigned & unsigned_en))) begin
        clear_valid <= 1'b0;
    end
end

assign signed_en = alu_op[16] | alu_op[15];
assign unsigned_en = alu_op[18] | alu_op[17];
assign div_en = signed_en | unsigned_en;
assign divisor_tvalid = div_en & clear_valid;
assign dividend_tvalid = div_en & clear_valid;
signed_div my_signed_div(
    .aclk(clk),
    .s_axis_divisor_tdata(alu_src2),
    .s_axis_divisor_tready(divisor_tready_signed),
    .s_axis_divisor_tvalid(divisor_tvalid & (signed_en)),
    .s_axis_dividend_tdata(alu_src1),
    .s_axis_dividend_tready(dividend_tready_signed),
    .s_axis_dividend_tvalid(dividend_tvalid & (signed_en)),
    .m_axis_dout_tdata(div_result_signed),
    .m_axis_dout_tvalid(div_out_valid_signed)
);

unsigned_div my_unsigned_div(
    .aclk(clk),
    .s_axis_divisor_tdata(alu_src2),
    .s_axis_divisor_tready(divisor_tready_unsigned),
    .s_axis_divisor_tvalid(divisor_tvalid & (unsigned_en)),
    .s_axis_dividend_tdata(alu_src1),
    .s_axis_dividend_tready(dividend_tready_unsigned),
    .s_axis_dividend_tvalid(dividend_tvalid & (unsigned_en)),
    .m_axis_dout_tdata(div_result_unsigned),
    .m_axis_dout_tvalid(div_out_valid_unsigned)
);

assign alu_result = 
    {32{mul_en}} & mul_result |
    {32{alu_op[15]}} & div_result_signed[63:32] |
    {32{alu_op[16]}} & div_result_signed[31:0] |
    {32{alu_op[17]}} & div_result_unsigned[63:32] |
    {32{alu_op[18]}} & div_result_unsigned[31:0] |
    {32{~mul_en && ~div_en}} & alu_result1;

assign wait_div = div_en & ~div_out_valid_signed & ~div_out_valid_unsigned & ~flush_WB;


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
        csr_en <= csr_en_ID;
        csr_we <= csr_we_ID;
        ertn_flush <= ertn_flush_ID;

        csr_num <= csr_num_ID;
        csr_wmask <= csr_wmask_ID;
        csr_wdata <= csr_wdata_ID;
    end
end

assign csr_en_out = csr_en && valid;
assign csr_we_out = csr_we && valid;
assign ertn_flush_out = ertn_flush && valid;

// load/store访存地址非对齐例外检测
wire   ex_ale = (((load_op[2:1] != 2'b00 || store_op[1] == 1'b1) && (alu_result[0] != 1'b0))
                | ((load_op[0] == 1'b1 || store_op[0] == 1'b1) && (alu_result[1:0] != 2'b00))) && valid;
assign wb_vaddr = alu_result;


// 64位计时器
reg  [63:0] timer;

always @(posedge clk) begin
    if (reset) begin
        timer <= 64'b0;
        rd_cnt_op <= 3'b0;
    end
    else begin
        timer <= timer + 1;
        rd_cnt_op <= rd_cnt_op_ID;
    end
end

assign rd_cnt = (rd_cnt_op != 3'b0);

assign rd_timer = (rd_cnt_op[1]) ? timer[31:0]  :
                  (rd_cnt_op[2]) ? timer[63:32] : 32'b0;

reg [5:0] exception_source_old;
always @(posedge clk)begin
    if(reset)begin
        exception_source_old <= 6'b0;
    end
    else if(data_allowin)begin
        exception_source_old <= exception_source_in;
    end
end

assign exception_source = {exception_source_old[5:3], ex_ale, exception_source_old[1:0]};

// store指令若要发出访存请求，需要检查EX、MEM、WB级是否有异常或ertn
wire data_sram_we_valid = data_sram_en && valid &&
                          (exception_source == 6'b0) &&
                          (~ex_MEM && ~flush_MEM) &&
                          (~ex_WB && ~flush_WB);

assign data_sram_we_out = {4{data_sram_we_valid}} & data_sram_we;

endmodule