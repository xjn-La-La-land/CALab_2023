module pipe_EX(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入
    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc, 

    input  wire [18:0] alu_op_ID,         // ALU的操作码 
    input  wire [31:0] alu_src1_ID,       // ALU的输�??          
    input  wire [31:0] alu_src2_ID,

    input  wire        rf_we_ID,
    input  wire [ 4:0] rf_waddr_ID,
    input  wire        res_from_mem_ID,   // �??后要写进寄存器的结果是否来自内存

    input wire [3:0]  data_sram_we_ID,
    input wire [31:0] data_sram_wdata_ID,
    input wire        data_sram_en_ID,

    output wire        to_valid,       // IF数据可以发出
    output wire        to_allowin,     // 允许preIF阶段的数据进�?? 

    output wire [31:0] alu_result, // 用于MEM阶段计算结果

    output reg         rf_we,          // 用于读写对比
    output reg  [ 4:0] rf_waddr,
    output reg         res_from_mem,   // �??后要写进寄存器的结果是否来自内存 

    output reg  [ 3:0] data_sram_we,
    output reg  [31:0] data_sram_wdata,
    output reg         data_sram_en,

    output reg  [31:0] PC
);
    wire ready_go;              // 数据处理完成信号
    reg valid; 
    assign ready_go = valid & ~wait_div;    // 当前数据是valid并且读后写冲突完�??
    assign to_allowin = !valid || ready_go && from_allowin; 
    assign to_valid = valid & ready_go;
     
    always @(posedge clk) begin
        if (reset) begin
            valid <= 1'b0;
        end
        else if(to_allowin) begin // 如果当前阶段允许数据进入，则数据是否有效就取决于上一阶段数据是否可以发出
            valid <= from_valid;
        end
    end

    wire data_allowin; // 拉手成功，数据可以进�??
    assign data_allowin = from_valid && to_allowin;

    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'b0;
        end
        else if(data_allowin) begin
            PC <= from_pc;
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            rf_waddr <= 5'b0;
            rf_we <= 1'b0;
            res_from_mem <= 1'b0;
        end
        else if(data_allowin) begin
            rf_waddr <= rf_waddr_ID;
            rf_we <= rf_we_ID;
            res_from_mem <= res_from_mem_ID;
        end
    end

    reg [18:0] alu_op;         // ALU的操作码
    reg [31:0] alu_src1;       // ALU的输�??
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

    always @(posedge clk) begin
        if (reset) begin
            data_sram_en <= 1'b0;
            data_sram_we <= 4'b0;
            data_sram_wdata <= 32'b0;
        end
        else if(data_allowin) begin
            data_sram_en <= data_sram_en_ID;
            data_sram_we <= data_sram_we_ID;
            data_sram_wdata <= data_sram_wdata_ID;
        end
    end

    wire [31:0] alu_result1; // 非除法运算结�?
    alu u_alu(
        .alu_op     (alu_op[14:0]),
        .alu_src1   (alu_src1  ),
        .alu_src2   (alu_src2  ),
        .alu_result (alu_result1)
    ); 

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
    
    assign alu_result = (
        {32{alu_op[15]}} & div_result_signed[63:32] |
        {32{alu_op[16]}} & div_result_signed[31:0] |
        {32{alu_op[17]}} & div_result_unsigned[63:32] |
        {32{alu_op[18]}} & div_result_unsigned[31:0] |
        {32{~div_en}} & alu_result1
    );
    
    assign wait_div = div_en & ~div_out_valid_signed & ~div_out_valid_unsigned;
endmodule