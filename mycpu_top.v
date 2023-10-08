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

    wire [31:0] rf_rdata1;         // 读数�?
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

    wire [ 4:0] rf_raddr1;        // 读地�?
    wire [ 4:0] rf_raddr2;
    wire        rf_we;
    wire [ 4:0] rf_waddr;
    wire        res_from_mem;   // �?后要写进寄存器的结果是否

    wire [11:0] alu_op;         // ALU的操作码 
    wire [31:0] alu_src1;       // ALU的输�?          
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

        .rf_we_MEM(rf_we_MEM & MEM_valid),
        .rf_waddr_MEM(rf_waddr_MEM),
        
        .rf_we_WB(rf_we_WB & WB_valid),
        .rf_waddr_WB(rf_waddr_WB),

        .to_valid(ID_valid),       // IF数据可以发出
        .to_allowin(ID_allowin),     // 允许preIF阶段的数据进�?

        .br_taken(br_taken),       // 跳转信号
        .br_target(br_target),    

        .rf_raddr1(rf_raddr1),         // 读地�?
        .rf_raddr2(rf_raddr2),

        .rf_we(rf_we),
        .rf_waddr(rf_waddr),
        .res_from_mem(res_from_mem),   // �?后要写进寄存器的结果是否来自wire

        .alu_op(alu_op),         // ALU的操作码 
        .alu_src1(alu_src1),       // ALU的输�?          
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
        .alu_src1_ID(alu_src1),       // ALU的输�?          
        .alu_src2_ID(alu_src2),

        .rf_we_ID(rf_we),
        .rf_waddr_ID(rf_waddr),
        .res_from_mem_ID(res_from_mem),   // �?后要写进寄存器的结果是否来自内存

        .data_sram_we_ID(data_sram_we_ID),
        .data_sram_wdata_ID(data_sram_wdata_ID),
        .data_sram_en_ID(data_sram_en_ID),

        .to_valid(EX_valid),       // IF数据可以发出
        .to_allowin(EX_allowin),     // 允许preIF阶段的数据进�? 

        .alu_result(alu_result), // 用于MEM阶段计算结果

        .rf_we(rf_we_EX),          // 用于读写对比
        .rf_waddr(rf_waddr_EX),
        .res_from_mem(res_from_mem_EX),   // �?后要写进寄存器的结果是否来自内存 

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
        .res_from_mem_EX(res_from_mem_EX),   // �?后要写进寄存器的结果是否来自内存

        .data_sram_rdata(data_sram_rdata),   // 读数�?

        .to_valid(MEM_valid),       // IF数据可以发出
        .to_allowin(MEM_allowin),     // 允许preIF阶段的数据进�? 

        .rf_we(rf_we_MEM),          // 用于读写对比
        .rf_waddr(rf_waddr_MEM),
        .rf_wdata(rf_wdata), // 用于MEM阶段计算�?

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
        .rf_wdata_MEM(rf_wdata),   // �?后要写进寄存器的结果是否来自�?

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

module pre_IF(
    input  wire        clk,
    input  wire        reset, 

    input  wire        br_taken,            // 跳转指令�?要更新nextpc
    input  wire [31:0] br_target,           // 跳转地址

    input  wire        from_allowin,       // IF周期允许数据进入
    
    output wire        to_valid,
    output wire [31:0] nextpc
);
// preIF 
    reg         valid;      // 控制信号
    always @(posedge clk) begin
        if (reset) begin
            valid <= 1'b0;
        end
        else begin
            valid <= 1'b1;
        end
    end
    assign to_valid = valid;

    reg  [31:0] PC;              // IF级当前PC�?
    wire [31:0] seq_pc;             // 顺序化的PC�?
    assign seq_pc       = PC + 3'h4;
    assign nextpc       = br_taken ? br_target : seq_pc;

    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
        end
        else if(valid && from_allowin) begin // 当数据有效且IF允许数据进入时再修改PC�?
            PC <= nextpc; 
        end
    end    
endmodule

module pipe_IF(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入
    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc,

    input wire         br_taken,       // 后面有跳转，当前指令和PC被取�?
    
    output wire        to_valid,       // IF数据可以发出
    output wire        to_allowin,     // 允许preIF阶段的数据进�?

    output reg [31:0] PC
); 

    wire ready_go;              // 数据处理完成信号
    reg valid;   
    assign ready_go = valid;    // 此时由于RAM�?定能够在�?周期内完成数据处�?
    assign to_allowin = !valid || ready_go && from_allowin; 
    assign to_valid = valid && ready_go;
   
    always @(posedge clk) begin
        if (reset) begin
            valid <= 1'b0;
        end
        else if(to_allowin) begin // 如果当前阶段允许数据进入，则数据是否有效就取决于上一阶段数据是否可以发出
            valid <= from_valid;
        end
        else if(br_taken) begin // 如果�?要跳转，当前阶段数据不能在下�?周期传到下一个流水线，则�?要将当前的数据给无效化，但当前没有什么用，这个判断一定要放在上一个的后面
            valid <= 1'b0;
        end
    end

    wire data_allowin; // 拉手成功，数据可以进�?
    assign data_valid = from_valid && to_allowin;

    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'b0;
        end
        else if(data_valid) begin       // 当数据有效时再传�?
            PC <= from_pc;
        end
    end

endmodule

module pipe_ID(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入
    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc,
    input  wire [31:0] inst_sram_rdata,

    input  wire [31:0] rf_rdata1,         // 读数�?
    input  wire [31:0] rf_rdata2,        

    input  wire        rf_we_EX,       // 用于读写对比
    input  wire [ 4:0] rf_waddr_EX,

    input  wire        rf_we_MEM,
    input  wire [ 4:0] rf_waddr_MEM,
    
    input  wire        rf_we_WB,
    input  wire [ 4:0] rf_waddr_WB,

    output wire        to_valid,       // IF数据可以发出
    output wire        to_allowin,     // 允许preIF阶段的数据进�?

    output wire        br_taken,       // 跳转信号
    output wire [31:0] br_target,      

    output wire [ 4:0] rf_raddr1,         // 读地�?
    output wire [ 4:0] rf_raddr2,

    output wire        rf_we,
    output wire [ 4:0] rf_waddr,
    output wire        res_from_mem,   // �?后要写进寄存器的结果是否来自wire

    output wire [11:0] alu_op,         // ALU的操作码 
    output wire [31:0] alu_src1,       // ALU的输�?          
    output wire [31:0] alu_src2,

    output wire [3:0]  data_sram_we,
    output wire [31:0] data_sram_wdata,
    output wire        data_sram_en,

    output reg  [31:0] PC
);

    wire ready_go;              // 数据处理完成信号
    reg valid;
    wire        rw_conflict;        // 读写冲突
    assign ready_go = valid && (~rw_conflict);    // 当前数据是valid并且读后写冲突完�?
    assign to_allowin = !valid || ready_go && from_allowin; 
    assign to_valid = valid & ready_go;
      
    always @(posedge clk) begin
        if (reset) begin
            valid <= 1'b0;
        end
        else if(br_taken) begin // 如果�?要跳转，则从下一个阶段开始valid就需要重置为零了
            valid <= 1'b0;
        end
        else if(to_allowin) begin // 如果当前阶段允许数据进入，则数据是否有效就取决于上一阶段数据是否可以发出
            valid <= from_valid;
        end
    end

    wire data_allowin; // 拉手成功，数据可以进�?
    assign data_allowin = from_valid && to_allowin;

    reg [31:0] inst;              // ID级当前PC�?
    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'b0;
            inst <= 32'b0;
        end
        else if(data_allowin) begin
            PC <= from_pc;
            inst <= inst_sram_rdata;
        end
    end

    wire        load_op;            // load操作码，没有用到？！！！！！！！！！
    wire        src1_is_pc;         // 源操作数1是否为PC�?
    wire        src2_is_imm;        // 源操作数2是否为立即数
    wire        dst_is_r1;          // 目的寄存器是否为r1，即link操作
    wire        gr_we;              // 判断是否�?要写寄存�?
    wire        mem_we;             // 判断是否�?要写内存
    wire        src_reg_is_rd;      // 判断寄存器堆第二个读地址在哪个数据段中，rd还是rk
    wire [4: 0] dest;               // 写寄存器的目的寄存器地址
    wire [31:0] rj_value;           // 寄存器堆第一个读到的数据
    wire [31:0] rkd_value;          // 寄存器堆第二个读到的数据
    wire [31:0] imm;                // 立即�?
    wire [31:0] br_offs;            // 分支偏移�?
    wire [31:0] jirl_offs;          // 跳转偏移量，即rj_value的�?�加上的偏移量，用于jirl指令

    wire [ 5:0] op_31_26;           // 指令的操作码分段
    wire [ 3:0] op_25_22;
    wire [ 1:0] op_21_20;
    wire [ 4:0] op_19_15;
    wire [ 4:0] rd;                 
    wire [ 4:0] rj;
    wire [ 4:0] rk;
    wire [11:0] i12;                // 21 - 10
    wire [19:0] i20;                // 24 - 5
    wire [15:0] i16;                // 25 - 10
    wire [25:0] i26;                //  9 -  0 + 25 - 10

    wire [63:0] op_31_26_d;
    wire [15:0] op_25_22_d;
    wire [ 3:0] op_21_20_d;
    wire [31:0] op_19_15_d;

    wire        inst_add_w;         // 要实现的20条指�?
    wire        inst_sub_w;
    wire        inst_slt;
    wire        inst_sltu;
    wire        inst_nor;
    wire        inst_and;
    wire        inst_or;
    wire        inst_xor;
    wire        inst_slli_w;
    wire        inst_srli_w;
    wire        inst_srai_w;
    wire        inst_addi_w;
    wire        inst_ld_w;
    wire        inst_st_w;
    wire        inst_jirl;
    wire        inst_b;
    wire        inst_bl;
    wire        inst_beq;
    wire        inst_bne;
    wire        inst_lu12i_w;

    wire        need_ui5;           // 各类指令是否�?要立即数，据此对立即数进行赋�?
    wire        need_si12;
    wire        need_si16;
    wire        need_si20;
    wire        need_si26;
    wire        src2_is_4;          // 纯粹用于保存jirl和bl指令，在寄存器中存储的PC+4�?�?要的立即�?

    wire        raddr1_valid;
    wire        raddr2_valid;

    assign op_31_26  = inst[31:26];
    assign op_25_22  = inst[25:22];
    assign op_21_20  = inst[21:20];
    assign op_19_15  = inst[19:15];
    
    assign rd   = inst[ 4: 0];
    assign rj   = inst[ 9: 5];
    assign rk   = inst[14:10];
    
    assign i12  = inst[21:10];
    assign i20  = inst[24: 5];
    assign i16  = inst[25:10];
    assign i26  = {inst[ 9: 0], inst[25:10]};
    
    decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d )); // 解码�?
    decoder_4_16 u_dec1(.in(op_25_22 ), .out(op_25_22_d ));
    decoder_2_4  u_dec2(.in(op_21_20 ), .out(op_21_20_d ));
    decoder_5_32 u_dec3(.in(op_19_15 ), .out(op_19_15_d ));
    
    assign inst_add_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h00];
    assign inst_sub_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h02];
    assign inst_slt    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h04];
    assign inst_sltu   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h05];
    assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_slli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h01];
    assign inst_srli_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h09];
    assign inst_srai_w = op_31_26_d[6'h00] & op_25_22_d[4'h1] & op_21_20_d[2'h0] & op_19_15_d[5'h11];
    assign inst_addi_w = op_31_26_d[6'h00] & op_25_22_d[4'ha];
    assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
    assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
    assign inst_jirl   = op_31_26_d[6'h13];
    assign inst_b      = op_31_26_d[6'h14];
    assign inst_bl     = op_31_26_d[6'h15];
    assign inst_beq    = op_31_26_d[6'h16];
    assign inst_bne    = op_31_26_d[6'h17];
    assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];
    
    assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_ld_w | inst_st_w
                        | inst_jirl | inst_bl;
    assign alu_op[ 1] = inst_sub_w;
    assign alu_op[ 2] = inst_slt;
    assign alu_op[ 3] = inst_sltu;
    assign alu_op[ 4] = inst_and;
    assign alu_op[ 5] = inst_nor;
    assign alu_op[ 6] = inst_or;
    assign alu_op[ 7] = inst_xor;
    assign alu_op[ 8] = inst_slli_w;
    assign alu_op[ 9] = inst_srli_w;
    assign alu_op[10] = inst_srai_w;
    assign alu_op[11] = inst_lu12i_w;
    
    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w;
    assign need_si16  =  inst_jirl | inst_beq | inst_bne;
    assign need_si20  =  inst_lu12i_w;
    assign need_si26  =  inst_b | inst_bl;
    assign src2_is_4  =  inst_jirl | inst_bl;
    
    assign imm = src2_is_4 ? 32'h4                      :
                 need_si20 ? {i20[19:0], 12'b0}         :
    /*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;
    
    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                                 {{14{i16[15]}}, i16[15:0], 2'b0} ; // 选择PC的偏移量�?16位还�?26�?
    
    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};    // 设置jirl指令的偏移量
    
    assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w; // 判断寄存器堆第二个读地址在哪个数据段中，rd还是rk
    
    assign src1_is_pc    = inst_jirl | inst_bl;         // 源操作数1是否为PC�?
    
    assign src2_is_imm   = inst_slli_w |                // 源操作数2是否为立即数
                           inst_srli_w |
                           inst_srai_w |
                           inst_addi_w |
                           inst_ld_w   |
                           inst_st_w   |
                           inst_lu12i_w|
                           inst_jirl   |
                           inst_bl     ;
     
    assign dst_is_r1     = inst_bl;                     // link操作会将返回地址写入�?号寄存器，且这个是隐含的，并不在指令中体现，因此�?要特殊处�?
    assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
    assign mem_we        = inst_st_w;                   // 判断是否�?要写内存
    assign dest          = dst_is_r1 ? 5'd1 : rd;

    assign raddr1_valid = ~(inst_b | inst_bl | inst_lu12i_w);
    assign raddr2_valid = ~(inst_slli_w
                            | inst_srli_w
                            | inst_srai_w
                            | inst_addi_w
                            | inst_ld_w
                            | inst_jirl
                            | inst_b 
                            | inst_bl 
                            | inst_lu12i_w
                        );

    assign rf_raddr1 = {5{raddr1_valid}} & rj;
    assign rf_raddr2 = {5{raddr2_valid}} & (src_reg_is_rd ? rd :rk);

    assign rw_conflict = ((rf_raddr1 != 5'b0) | (rf_raddr2 != 5'b0)) &
                        (
                            (rf_raddr1 == rf_waddr_EX) & rf_we_EX |
                            (rf_raddr1 == rf_waddr_MEM) & rf_we_MEM |
                            (rf_raddr1 == rf_waddr_WB) & rf_we_WB |
                            (rf_raddr2 == rf_waddr_EX) & rf_we_EX |
                            (rf_raddr2 == rf_waddr_MEM) & rf_we_MEM |
                            (rf_raddr2 == rf_waddr_WB) & rf_we_WB 
                        );

    assign rj_value  = rf_rdata1;
    assign rkd_value = rf_rdata2;

    assign rj_eq_rd = (rj_value == rkd_value);
    assign br_taken = (   inst_beq  &&  rj_eq_rd
                       || inst_bne  && !rj_eq_rd
                       || inst_jirl
                       || inst_bl
                       || inst_b
                      ) && valid && ~rw_conflict;
    assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (PC + br_offs) :
                                                       /*inst_jirl*/ (rj_value + jirl_offs); // 获取下一个PC�?
    assign rf_waddr = dest;
    assign rf_we = gr_we && valid;
    assign res_from_mem = inst_ld_w;

    assign alu_src1 = src1_is_pc  ? PC[31:0] : rj_value;
    assign alu_src2 = src2_is_imm ? imm : rkd_value;

    assign data_sram_en = valid; // 片�?�信号在读或者写的时候都要拉高！！！
    assign data_sram_we = {4{mem_we & valid}}; // 写使能信号在当前流水线数据有效时才被拉高
    assign data_sram_wdata = rkd_value;

endmodule

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

    output reg [31:0] PC
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

