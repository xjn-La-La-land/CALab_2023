module MEM_stream(
    input wire         clk,
    input wire         reset,
    input wire         valid,

    // control in
    input wire         EXE_to_MEM_valid,
    input wire         WB_allowin,

    // data in
    input wire  [31:0] MEM_pc_in,
    input wire  [31:0] MEM_alu_res_in,
    input wire  [31:0] MEM_mem_res_in,
    input wire         MEM_res_from_mem_in,
    input wire         MEM_rf_we_in,
    input wire  [ 4:0] MEM_rf_waddr_in,

    // data out
    output wire [31:0] MEM_pc_out,
    output wire [31:0] MEM_rf_wdata_out,
    output wire        MEM_rf_we_out,
    output wire [ 4:0] MEM_rf_waddr_out,

    // control out
    output wire        MEM_to_WB_valid,
    output wire        MEM_allowin
    );

wire        MEM_ready_go;
// MEM一级的缓存寄存器
reg         MEM_valid;
reg  [31:0] MEM_pc;
reg  [31:0] MEM_alu_res;
reg         MEM_res_from_mem;
reg         MEM_rf_we;
reg  [ 4:0] MEM_rf_waddr;

// 访存相关的数据信号
wire [31:0] final_result;

assign final_result = MEM_res_from_mem ? MEM_mem_res_in : MEM_alu_res; // MEM级流水中mem_res不能用缓存寄存器缓冲！

// MEM输出数据的赋值
assign MEM_pc_out       = MEM_pc;
assign MEM_rf_wdata_out = final_result;
assign MEM_rf_we_out    = MEM_rf_we & MEM_valid;
assign MEM_rf_waddr_out = MEM_rf_waddr;

// MEM输出控制信号的赋值
assign MEM_allowin     = (!MEM_valid) || (MEM_ready_go && WB_allowin);
assign MEM_ready_go    = 1'b1;  // 除了IF阶段出现写后读的阻塞，其他各级流水的ready_go信号都是1
assign MEM_to_WB_valid = MEM_valid && MEM_ready_go;

// MEM缓存数据域的赋值
always @(posedge clk)begin
    if(reset)begin
        MEM_pc <= 32'b0;
    end
    else if(EXE_to_MEM_valid && MEM_allowin)begin
        MEM_pc <= MEM_pc_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        MEM_alu_res <= 32'b0;
    end
    else if(EXE_to_MEM_valid && MEM_allowin)begin
        MEM_alu_res <= MEM_alu_res_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        MEM_res_from_mem <= 1'b0;
    end
    else if(EXE_to_MEM_valid && MEM_allowin)begin
        MEM_res_from_mem <= MEM_res_from_mem_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        MEM_rf_we <= 1'b0;
        MEM_rf_waddr <= 5'b0;
    end
    else if(EXE_to_MEM_valid && MEM_allowin)begin
        MEM_rf_we <= MEM_rf_we_in;
        MEM_rf_waddr <= MEM_rf_waddr_in;
    end
end

// MEM缓存控制信号valid域的更新
always @(posedge clk)begin
    if(reset)begin
        MEM_valid <= 1'b0;
    end
    else if(MEM_allowin)begin
        MEM_valid <= EXE_to_MEM_valid;
    end
end

endmodule