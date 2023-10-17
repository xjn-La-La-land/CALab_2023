module mycpu_top(

    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire [3:0]  inst_sram_we,    // RAM字节写使�?
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    output wire        inst_sram_en,    // RAM的片选信号，高电平有�?
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    output wire        data_sram_en,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
    reg         reset;
    always @(posedge clk) reset <= ~resetn;
    
    wire [31:0] pc_preIF_to_IF;
    wire [31:0] pc_IF_to_ID;
    wire [31:0] pc_ID_to_EX;
    wire [31:0] pc_EX_to_MEM;
    wire [31:0] pc_MEM_to_WB;
    wire [31:0] pc_WB;

    wire        IF_allowin;
    wire        ID_allowin;
    wire        EX_allowin;
    wire        MEM_allowin;
    wire        WB_allowin;

    wire        preIF_valid;
    wire        IF_valid;
    wire        ID_valid;
    wire        EX_valid;
    wire        MEM_valid;
    wire        WB_valid;

    wire        br_taken;      // 跳转信号
    wire [31:0] br_target;

    wire [31:0] rf_rdata1;         // 读数�??
    wire [31:0] rf_rdata2;  
    
    wire        rf_we_EX;       // 用于读写对比
    wire [ 4:0] rf_waddr_EX;
    wire        res_from_mem_EX;

    wire        rf_we_MEM;
    wire [ 4:0] rf_waddr_MEM;
    wire [31:0] rf_wdata;

    wire        rf_we_WB;
    wire [ 4:0] rf_waddr_WB;
    wire [31:0] rf_wdata_WB;

    wire [ 4:0] rf_raddr1;        // 读地�??
    wire [ 4:0] rf_raddr2;
    wire        rf_we;
    wire [ 4:0] rf_waddr;
    wire        res_from_mem;   // �??后要写进寄存器的结果是否

    wire [18:0] alu_op;         // ALU的操作码 
    wire [31:0] alu_src1;       // ALU的输�??          
    wire [31:0] alu_src2;

    wire [3:0]  data_sram_we_ID;
    wire [31:0] data_sram_wdata_ID;
    wire        data_sram_en_ID;

    wire [31:0] alu_result;


    pre_IF u_pre_IF(
        .clk          (clk),
        .reset        (reset),

        .br_taken     (br_taken),
        .br_target    (br_target),

        .from_allowin (IF_allowin),

        .to_valid     (preIF_valid),
        .nextpc       (pc_preIF_to_IF)
    );

    assign inst_sram_en    = IF_allowin; 
    assign inst_sram_we    = 4'b0;
    assign inst_sram_addr  = pc_preIF_to_IF;
    assign inst_sram_wdata = 32'b0; 

    pipe_IF u_pipe_IF(
        .clk          (clk),
        .reset        (reset),

        .from_allowin (ID_allowin),
        .from_valid   (preIF_valid),

        .from_pc      (pc_preIF_to_IF),

        .br_taken     (br_taken),

        .to_valid     (IF_valid),
        .to_allowin   (IF_allowin),

        .PC           (pc_IF_to_ID)
    );

    pipe_ID u_pipe_ID(
        .clk(clk),
        .reset(reset),

        .from_allowin(EX_allowin),
        .from_valid(IF_valid),

        .from_pc(pc_IF_to_ID),
        .inst_sram_rdata(inst_sram_rdata),

        .rf_rdata1(rf_rdata1),         
        .rf_rdata2(rf_rdata2),        

        .rf_we_EX(rf_we_EX & EX_valid),       // 用于读写对比
        .rf_waddr_EX(rf_waddr_EX),
        .res_from_mem_EX(res_from_mem_EX),
        .alu_result_EX(alu_result), // 用于数据前�??

        .rf_we_MEM(rf_we_MEM & MEM_valid),
        .rf_waddr_MEM(rf_waddr_MEM),
        .rf_wdata_MEM(rf_wdata),    // 用于数据前�??
        
        .rf_we_WB(rf_we_WB & WB_valid),
        .rf_waddr_WB(rf_waddr_WB),
        .rf_wdata_WB(rf_wdata_WB),  // 用于数据前�??

        .to_valid(ID_valid),       // IF数据可以发出
        .to_allowin(ID_allowin),     // 允许preIF阶段的数据进�??

        .br_taken(br_taken),       // 跳转信号
        .br_target(br_target),    

        .rf_raddr1(rf_raddr1),         // 读地�??
        .rf_raddr2(rf_raddr2),

        .rf_we(rf_we),
        .rf_waddr(rf_waddr),
        .res_from_mem(res_from_mem),   // �??后要写进寄存器的结果是否来自wire

        .alu_op(alu_op),         // ALU的操作码 
        .alu_src1(alu_src1),       // ALU的输�??          
        .alu_src2(alu_src2),
        
        .data_sram_we(data_sram_we_ID),
        .data_sram_wdata(data_sram_wdata_ID),
        .data_sram_en(data_sram_en_ID),

        .PC(pc_ID_to_EX)
    );

    pipe_EX u_pipe_EX(
        .clk(clk),
        .reset(reset), 

        .from_allowin(MEM_allowin),   // ID周期允许数据进入
        .from_valid(ID_valid),     // preIF数据可以发出

        .from_pc(pc_ID_to_EX), 

        .alu_op_ID(alu_op),         // ALU的操作码 
        .alu_src1_ID(alu_src1),       // ALU的输�??          
        .alu_src2_ID(alu_src2),

        .rf_we_ID(rf_we),
        .rf_waddr_ID(rf_waddr),
        .res_from_mem_ID(res_from_mem),   // �??后要写进寄存器的结果是否来自内存

        .data_sram_we_ID(data_sram_we_ID),
        .data_sram_wdata_ID(data_sram_wdata_ID),
        .data_sram_en_ID(data_sram_en_ID),

        .to_valid(EX_valid),       // IF数据可以发出
        .to_allowin(EX_allowin),     // 允许preIF阶段的数据进�?? 

        .alu_result(alu_result), // 用于MEM阶段计算结果

        .rf_we(rf_we_EX),          // 用于读写对比
        .rf_waddr(rf_waddr_EX),
        .res_from_mem(res_from_mem_EX),   // �??后要写进寄存器的结果是否来自内存 

        .data_sram_we(data_sram_we),
        .data_sram_wdata(data_sram_wdata),
        .data_sram_en(data_sram_en),

        .PC(pc_EX_to_MEM)
    );

    // EX
    // assign data_sram_we   = data_sram_we_EX;
    // assign data_sram_wdata = data_sram_wdata_EX;
    // assign data_sram_en   = data_sram_en_EX;
    assign data_sram_addr  = alu_result;

    pipe_MEM u_pipe_MEM(
        .clk(clk),
        .reset(reset), 

        .from_allowin(WB_allowin),   // ID周期允许数据进入
        .from_valid(EX_valid),     // preIF数据可以发出

        .from_pc(pc_EX_to_MEM), 

        .alu_result_EX(alu_result), // 用于MEM阶段计算结果

        .rf_we_EX(rf_we_EX),
        .rf_waddr_EX(rf_waddr_EX),
        .res_from_mem_EX(res_from_mem_EX),   // �??后要写进寄存器的结果是否来自内存

        .data_sram_rdata(data_sram_rdata),   // 读数�??

        .to_valid(MEM_valid),       // IF数据可以发出
        .to_allowin(MEM_allowin),     // 允许preIF阶段的数据进�?? 

        .rf_we(rf_we_MEM),          // 用于读写对比
        .rf_waddr(rf_waddr_MEM),
        .rf_wdata(rf_wdata), // 用于MEM阶段计算�??

        .PC(pc_MEM_to_WB)
    );

    pipe_WB u_pipe_WB(
        .clk(clk),
        .reset(reset), 

        .from_valid(MEM_valid),     
        .from_pc(pc_MEM_to_WB), 
        
        .to_allowin(WB_allowin),    
        .to_valid(WB_valid), 

        .rf_we_MEM(rf_we_MEM),
        .rf_waddr_MEM(rf_waddr_MEM),
        .rf_wdata_MEM(rf_wdata),   // �??后要写进寄存器的结果是否来自�??

        .rf_we(rf_we_WB),          
        .rf_waddr(rf_waddr_WB),
        .rf_wdata(rf_wdata_WB),

        .PC(pc_WB)
    );

    regfile u_regfile(
        .clk    (clk      ),
        .raddr1 (rf_raddr1),
        .rdata1 (rf_rdata1),
        .raddr2 (rf_raddr2),
        .rdata2 (rf_rdata2),
        .we     (rf_we_WB & WB_valid),
        .waddr  (rf_waddr_WB),
        .wdata  (rf_wdata_WB)
    );


    // debug info generate
    assign debug_wb_pc       = pc_WB;
    assign debug_wb_rf_we   = {4{rf_we_WB & WB_valid}}; 
    assign debug_wb_rf_wnum  = rf_waddr_WB;
    assign debug_wb_rf_wdata = rf_wdata_WB;

endmodule
