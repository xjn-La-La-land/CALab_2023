module EXE_stream(
    input wire         clk,
    input wire         reset,
    input wire         valid,

    // control in
    input wire         ID_to_EXE_valid,
    input wire         MEM_allowin,

    // data in
    input wire  [31:0] EXE_pc_in,
    input wire  [31:0] EXE_rdata1_in,
    input wire  [31:0] EXE_rdata2_in,
    input wire  [31:0] EXE_imm_in,
    input wire  [ 1:0] EXE_alu_ctrl_in,
    input wire  [11:0] EXE_alu_op_in,
    input wire         alu_res_need_bypass_in,
    input wire         EXE_mem_rd_in,
    input wire         EXE_mem_we_in,
    input wire         EXE_res_from_mem_in,
    input wire         EXE_rf_we_in,
    input wire  [ 4:0] EXE_rf_waddr_in,

    // data out
    output wire [31:0] EXE_pc_out,
    output wire [31:0] EXE_alu_res_out,
    output wire        EXE_res_from_mem_out,
    output wire        EXE_rf_we_out,
    output wire [ 4:0] EXE_rf_waddr_out,
    output wire        EXE_need_bypass_out,
    output wire        EXE_to_ID_stuck_out, // EXE阶段load指令无法将写回数据前递给ID

    output wire        data_sram_en,
    output wire [ 3:0] data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,

    // control out
    output wire        EXE_to_MEM_valid,
    output wire        EXE_allowin
    );

wire        EXE_ready_go;
// EXE一级的缓存寄存器
reg         EXE_valid   ;
reg  [31:0] EXE_pc      ;
reg  [31:0] EXE_rdata1  ;
reg  [31:0] EXE_rdata2  ;
reg  [31:0] EXE_imm     ;
reg  [ 1:0] EXE_alu_ctrl;
reg  [11:0] EXE_alu_op  ;
reg         alu_res_need_bypass;
reg         EXE_mem_rd  ;
reg         EXE_mem_we  ;   // 译码生成的访存控制信号
reg         EXE_res_from_mem;
reg         EXE_rf_we   ;   // 译码生成的寄存器写回控制信号
reg  [ 4:0] EXE_rf_waddr;

// alu运算相关的数据信号
wire [31:0] alu_src1   ;
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

// alu运算信号的赋值
assign alu_src1 = EXE_alu_ctrl[0] ? EXE_pc[31:0] : EXE_rdata1[31:0]; // 计算PC+4要用EXE阶段的PC!
assign alu_src2 = EXE_alu_ctrl[1] ? EXE_imm[31:0] : EXE_rdata2[31:0];

alu u_alu(
    .alu_op     (EXE_alu_op ),
    .alu_src1   (alu_src1  ), // 3rd error: .alu_src1   (alu_src2  ),
    .alu_src2   (alu_src2  ),
    .alu_result (alu_result)
    );

// EXE输出数据的赋值
assign EXE_pc_out                  = EXE_pc;
assign EXE_alu_res_out             = alu_result;
assign EXE_res_from_mem_out        = EXE_res_from_mem;
assign EXE_rf_we_out               = EXE_rf_we;
assign EXE_rf_waddr_out            = EXE_rf_waddr;
assign EXE_need_bypass_out         = alu_res_need_bypass & EXE_valid;
assign EXE_to_ID_stuck_out         = EXE_mem_rd & EXE_valid;

assign data_sram_en    = 1'b1; // 数据RAM片选信号
assign data_sram_we    = {4{EXE_mem_we && valid}};
assign data_sram_addr  = alu_result;
assign data_sram_wdata = EXE_rdata2;

// EXE输出控制信号的赋值
assign EXE_allowin     = (!EXE_valid) || (EXE_ready_go && MEM_allowin);
assign EXE_ready_go    = 1'b1;  // 除了IF阶段出现写后读的阻塞，其他各级流水的ready_go信号都是1
assign EXE_to_MEM_valid= EXE_valid && EXE_ready_go;


// EXE缓存数据域的赋值
always @(posedge clk)begin
    if(reset)begin
        EXE_pc <= 32'b0;
    end
    else if(ID_to_EXE_valid && EXE_allowin)begin
        EXE_pc <= EXE_pc_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        EXE_rdata1 <= 32'b0;
        EXE_rdata2 <= 32'b0;
        EXE_imm    <= 32'b0;
    end
    else if(ID_to_EXE_valid && EXE_allowin)begin
        EXE_rdata1 <= EXE_rdata1_in;
        EXE_rdata2 <= EXE_rdata2_in;
        EXE_imm    <= EXE_imm_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        EXE_alu_ctrl <= 2'b0;
    end
    else if(ID_to_EXE_valid && EXE_allowin)begin
        EXE_alu_ctrl <= EXE_alu_ctrl_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        EXE_alu_op <= 12'b0;
    end
    else if(ID_to_EXE_valid && EXE_allowin)begin
        EXE_alu_op <= EXE_alu_op_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        EXE_mem_rd <= 1'b0;
        EXE_mem_we <= 1'b0;
        EXE_res_from_mem <= 1'b0;
    end
    else if(ID_to_EXE_valid && EXE_allowin)begin
        EXE_mem_rd <= EXE_mem_rd_in;
        EXE_mem_we <= EXE_mem_we_in;
        EXE_res_from_mem <= EXE_res_from_mem_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        EXE_rf_we <= 1'b0;
        EXE_rf_waddr <= 5'b0;
    end
    else if(ID_to_EXE_valid && EXE_allowin)begin
        EXE_rf_we <= EXE_rf_we_in;
        EXE_rf_waddr <= EXE_rf_waddr_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        alu_res_need_bypass <= 1'b0;
    end
    else if(ID_to_EXE_valid && EXE_allowin)begin
        alu_res_need_bypass <= alu_res_need_bypass_in;
    end
end

// EXE缓存控制信号valid域的更新
always @(posedge clk)begin
    if(reset)begin
        EXE_valid <= 1'b0;
    end
    else if(EXE_allowin)begin
        EXE_valid <= ID_to_EXE_valid;
    end
end

endmodule