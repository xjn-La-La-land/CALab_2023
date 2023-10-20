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

    input  wire [31:0] data_sram_rdata,   // 读数据

    output wire        to_valid,       // IF数据可以发出
    output wire        to_allowin,     // 允许preIF阶段的数据进入 

    output reg         rf_we,           // 用于读写对比
    output reg  [ 4:0] rf_waddr,
    output wire [31:0] rf_wdata,        // 用于MEM阶段计算�?

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

    wire [ 7:0] mem_byte;
    wire [15:0] mem_halfword;
    wire [31:0] mem_result;         // 从内存中读出的数据
    wire [31:0] final_result;
    
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
endmodule