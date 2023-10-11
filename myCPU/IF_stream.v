module IF_stream(
    input wire         clk,
    input wire         reset,
    input wire         valid,
    // control in
    input wire         in_valid,
    input wire         ID_allowin,
    // data in
    input wire  [31:0] IF_inst_in,
    input wire         br_taken_in,
    input wire  [31:0] br_target_in,
    // data out
    output wire [31:0] IF_pc_out,
    output wire [31:0] IF_inst_out,

    output wire        inst_sram_en, // 片选信号
    output wire [ 3:0] inst_sram_we, // 4bit写使能信号
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    // control out
    output wire        IF_to_ID_valid,
    output wire        IF_allowin
    );

// IF阶段的缓冲寄存器
reg  [31:0] IF_pc;
reg         IF_valid;
wire        IF_ready_go;

wire [31:0] seq_pc;
wire [31:0] nextpc;

assign IF_allowin     = !(IF_valid) || (IF_ready_go && ID_allowin);
assign IF_ready_go    = 1'b1;  // 除了IF阶段出现写后读的阻塞，其他各级流水的ready_go信号都是1
assign IF_to_ID_valid = IF_valid && IF_ready_go;

assign IF_pc_out      = IF_pc;
assign seq_pc         = IF_pc + 3'h4;
assign nextpc         = br_taken_in ? br_target_in : seq_pc;

assign IF_inst_out    = IF_inst_in;

assign inst_sram_en    = 1'b1; // 指令RAM片选信号始终拉高
assign inst_sram_we    = 4'b0; // 指令RAM不需要写入
assign inst_sram_addr  = (in_valid && IF_allowin)? nextpc : IF_pc; // trick:当IF没有被阻塞时，取指地址为下一条指令的PC；当IF被阻塞时，取指地址为当前指令的pc
assign inst_sram_wdata = 32'b0;

// IF缓存控制信号IF_valid域的更新
always @(posedge clk)begin
    if(reset)begin
        IF_valid <= 1'b0;     // 各级流水的valid信号初始化时都置为0
    end
    else if(IF_allowin)begin
        IF_valid <= in_valid;
    end
    else if(br_taken_in)begin
        IF_valid <= 1'b0;     // !!!若指令RAM无法一个周期返回指令，而在等待时又恰好出现跳转，则将等待的这条指令valid置为0
    end
end

// IF缓存数据域的更新
always @(posedge clk)begin
    if(reset)begin
        IF_pc <= 32'h1bfffffc;     //trick: to make nextpc be 0x1c000000 during reset
    end
    else if(in_valid && IF_allowin)begin
        IF_pc <= nextpc;
    end
end

endmodule