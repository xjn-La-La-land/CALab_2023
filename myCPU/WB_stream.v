module WB_stream(
    input wire         clk,
    input wire         reset,
    input wire         valid,

    // control in
    input wire         MEM_to_WB_valid,
    input wire         out_allow,

    // data in
    input wire  [31:0] WB_pc_in,
    input wire  [31:0] WB_rf_wdata_in,
    input wire         WB_rf_we_in,
    input wire  [ 4:0] WB_rf_waddr_in,

    // data out
    output wire [31:0] WB_pc_out,
    output wire        WB_rf_we_out,
    output wire [ 4:0] WB_rf_waddr_out,
    output wire [31:0] WB_rf_wdata_out, // 将这些信号输出给到ID模块中的寄存器堆

    // control out
    output wire        WB_to_out_valid,
    output wire        WB_allowin
    );

wire        WB_ready_go;
// WB一级的缓存寄存器
reg         WB_valid;
reg  [31:0] WB_pc;
reg  [31:0] WB_rf_wdata;
reg         WB_rf_we;
reg  [ 4:0] WB_rf_waddr;

// 写回相关的数据信号
assign WB_pc_out       = WB_pc;
assign WB_rf_we_out    = WB_rf_we & valid & WB_valid;
assign WB_rf_waddr_out = WB_rf_waddr;
assign WB_rf_wdata_out = WB_rf_wdata;


// WB输出控制信号的赋值
assign WB_allowin     = (!WB_valid) || (WB_ready_go && out_allow);
assign WB_ready_go    = 1'b1;  // 除了IF阶段出现写后读的阻塞，其他各级流水的ready_go信号都是1
assign WB_to_out_valid= WB_valid && WB_ready_go;

// WB缓存数据域的赋值
always @(posedge clk)begin
    if(reset)begin
        WB_pc <= 32'b0;
    end
    else if(MEM_to_WB_valid && WB_allowin)begin
        WB_pc <= WB_pc_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        WB_rf_wdata <= 32'b0;
        WB_rf_we <= 1'b0;
        WB_rf_waddr <= 5'b0;
    end
    else if(MEM_to_WB_valid && WB_allowin)begin
        WB_rf_wdata <= WB_rf_wdata_in;
        WB_rf_we <= WB_rf_we_in;
        WB_rf_waddr <= WB_rf_waddr_in;
    end
end

// WB缓存控制信号valid域的更新
always @(posedge clk)begin
    if(reset)begin
        WB_valid <= 1'b0;
    end
    else if(WB_allowin)begin
        WB_valid <= MEM_to_WB_valid;
    end
end

endmodule