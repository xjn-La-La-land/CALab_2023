module pipe_WB(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc, 

    output wire        to_allowin,     // 允许preIF阶段的数据进�?
    output wire        to_valid, 

    input  wire        rf_we_MEM,
    input  wire [ 4:0] rf_waddr_MEM,
    input  wire [31:0] rf_wdata_MEM,   // �?后要写进寄存器的结果是否来自�?

    output reg         rf_we,          // 用于读写对比
    output reg  [ 4:0] rf_waddr,
    output reg  [31:0] rf_wdata, // 用于MEM阶段计算�?

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

    reg res_from_mem;
    always @(posedge clk) begin
        if (reset) begin
            rf_waddr <= 5'b0;
            rf_we <= 1'b0;
            rf_wdata <= 31'b0;
        end
        else if(data_allowin) begin
            rf_waddr <= rf_waddr_MEM;
            rf_we <= rf_we_MEM;
            rf_wdata <= rf_wdata_MEM;
        end
    end
endmodule