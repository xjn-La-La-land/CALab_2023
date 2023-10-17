module pipe_MEM(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入
    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc, 

    input wire [31:0] alu_result_EX, // 用于MEM阶段计算结果

    input  wire        rf_we_EX,
    input  wire [ 4:0] rf_waddr_EX,
    input  wire        res_from_mem_EX,   // �?后要写进寄存器的结果是否来自内存

    input  wire [31:0] data_sram_rdata,   // 读数�?

    output wire        to_valid,       // IF数据可以发出
    output wire        to_allowin,     // 允许preIF阶段的数据进�? 

    output reg         rf_we,          // 用于读写对比
    output reg  [ 4:0] rf_waddr,
    output wire [31:0] rf_wdata, // 用于MEM阶段计算�?

    output reg [31:0]  PC
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

    wire [31:0] mem_result;         // 从内存中读出的数�?
    wire [31:0] final_result;

    reg [31:0] alu_result;
    always @(posedge clk) begin
        if (reset) begin
            alu_result <= 32'b0;
        end
        else if(data_allowin) begin
            alu_result <= alu_result_EX;
        end
    end

    reg res_from_mem;
    always @(posedge clk) begin
        if (reset) begin
            rf_waddr <= 5'b0;
            rf_we <= 1'b0;
            res_from_mem <= 1'b0;
        end
        else if(data_allowin) begin
            rf_waddr <= rf_waddr_EX;
            rf_we <= rf_we_EX;
            res_from_mem <= res_from_mem_EX;
        end
    end

    assign mem_result = data_sram_rdata;
    assign rf_wdata = res_from_mem ? mem_result : alu_result;
endmodule