module pipe_EX(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入
    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc, 

    input  wire [11:0] alu_op_ID,         // ALU的操作码 
    input  wire [31:0] alu_src1_ID,       // ALU的输�?          
    input  wire [31:0] alu_src2_ID,

    input  wire        rf_we_ID,
    input  wire [ 4:0] rf_waddr_ID,
    input  wire        res_from_mem_ID,   // �?后要写进寄存器的结果是否来自内存

    input wire [3:0]  data_sram_we_ID,
    input wire [31:0] data_sram_wdata_ID,
    input wire        data_sram_en_ID,

    output wire        to_valid,       // IF数据可以发出
    output wire        to_allowin,     // 允许preIF阶段的数据进�? 

    output wire [31:0] alu_result, // 用于MEM阶段计算结果

    output reg         rf_we,          // 用于读写对比
    output reg  [ 4:0] rf_waddr,
    output reg         res_from_mem,   // �?后要写进寄存器的结果是否来自内存 

    output reg  [ 3:0] data_sram_we,
    output reg  [31:0] data_sram_wdata,
    output reg         data_sram_en,

    output reg  [31:0] PC
);
    wire ready_go;              // 数据处理完成信号
    reg valid; 
    assign ready_go = valid;    // 当前数据是valid并且读后写冲突完�?
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

    wire data_allowin; // 拉手成功，数据可以进�?
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

    reg [11:0] alu_op;         // ALU的操作码
    reg [31:0] alu_src1;       // ALU的输�?
    reg [31:0] alu_src2;
    always @(posedge clk) begin
        if (reset) begin
            alu_op <= 12'b0;
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

    alu u_alu(
        .alu_op     (alu_op    ),
        .alu_src1   (alu_src1  ),
        .alu_src2   (alu_src2  ),
        .alu_result (alu_result)
    ); 
endmodule