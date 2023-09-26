module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire [3:0]  inst_sram_we,    // RAM字节写使能
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    output wire        inst_sram_en,    // RAM的片选信号，高电平有效
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

wire [11:0] alu_op;             // ALU的操作码 
wire        load_op;            // load操作码，没有用到？！！！！！！！！！
wire        src1_is_pc;         // 源操作数1是否为PC值
wire        src2_is_imm;        // 源操作数2是否为立即数
wire        res_from_mem;       // 最后要写进寄存器的结果是否来自内存
wire        dst_is_r1;          // 目的寄存器是否为r1，即link操作
wire        gr_we;              // 判断是否需要写寄存器
wire        mem_we;             // 判断是否需要写内存
wire        src_reg_is_rd;      // 判断寄存器堆第二个读地址在哪个数据段中，rd还是rk
wire [4: 0] dest;               // 写寄存器的目的寄存器地址
wire [31:0] rj_value;           // 寄存器堆第一个读到的数据
wire [31:0] rkd_value;          // 寄存器堆第二个读到的数据
wire [31:0] imm;                // 立即数
wire [31:0] br_offs;            // 分支偏移量
wire [31:0] jirl_offs;          // 跳转偏移量，即rj_value的值加上的偏移量，用于jirl指令

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

wire        inst_add_w;         // 要实现的20条指令
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

wire        need_ui5;           // 各类指令是否需要立即数，据此对立即数进行赋值
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;          // 纯粹用于保存jirl和bl指令，在寄存器中存储的PC+4所需要的立即数

wire [ 4:0] rf_raddr1;          // 寄存器堆的读写地址
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire [31:0] alu_src1   ;        // ALU的输入输出          
wire [31:0] alu_src2   ;
wire [31:0] alu_result ;

wire [31:0] mem_result;         // 从内存中读出的数据
wire [31:0] final_result;

wire        br_taken;           // 判断是否需要分支
wire [31:0] br_target;          // 分支目标地址

// 流水线设置
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

wire [31:0] nextpc;             // 计算出的下一个PC值，如果不跳转就是pc+4，如果是的就直接用ID中的结果，因为第一阶段一条指令后面通常是多个nop，所以不需要管错误发出的几个PC值
wire [31:0] seq_pc;             // 顺序化的PC值

assign seq_pc       = pc_IF + 3'h4;
assign nextpc = br_taken ? br_target : seq_pc;

reg  [31:0] pc_IF;              // IF级当前PC值
always @(posedge clk) begin
    if (reset) begin
        pc_IF <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if(valid) begin
        pc_IF <= nextpc; 
    end
end

assign inst_sram_en    = valid;
assign inst_sram_we    = 4'b0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

// IF
reg         valid_IF;      // 控制信号
always @(posedge clk) begin
    if (reset) begin
        valid_IF <= 1'b0;
    end
    else begin
        valid_IF <= valid;
    end
end
reg [31:0] inst;               // 当前读到的指令
reg [31:0] pc_ID;              // ID级当前PC值
always @(posedge clk) begin
    if (reset) begin
        inst <= 32'b0;
        pc_ID <= 32'b0;
    end
    else if(valid_IF) begin       // 当数据有效时再传递
        inst <= inst_sram_rdata;
        pc_ID <= pc_IF;
    end
end

// ID
reg         valid_ID;      // 控制信号
always @(posedge clk) begin
    if (reset) begin
        valid_ID <= 1'b0;
    end
    else begin
        valid_ID <= valid_IF;
    end
end

reg [31:0] pc_EX;              // EX级当前PC值
reg        rf_we_EX    ;
reg [ 4:0] rf_waddr_EX ;
reg        res_from_mem_EX;       // 最后要写进寄存器的结果是否来自内存

always @(posedge clk) begin
    if (reset) begin
        rf_waddr_EX <= 5'b0;
        rf_we_EX <= 1'b0;
        res_from_mem_EX <= 1'b0;
        pc_EX <= 32'b0;
    end
    else if(valid_ID) begin
        rf_waddr_EX <= dest;
        rf_we_Ex <= gr_we && valid;
        res_from_mem_EX <= res_from_mem;
        pc_EX <= pc_ID;
    end
end

reg [11:0] alu_op_EX  ;             // ALU的操作码 
reg [31:0] alu_src1_EX   ;        // ALU的输入输出          
reg [31:0] alu_src2_EX   ;
always @(posedge clk) begin
    if (reset) begin
        alu_op_EX <= 12'b0;
        alu_src1_EX <= 32'b0;
        alu_src2_EX <= 32'b0;
    end
    else if(valid_ID) begin
        alu_op_EX <= alu_op;
        alu_src1_EX <= alu_src1;
        alu_src2_EX <= alu_src2;
    end
end

reg [3:0]  data_sram_we_EX;
reg [31:0] data_sram_wdata_Ex;
reg        data_sram_en_EX;
always @(posedge clk) begin
    if (reset) begin
        data_sram_en_EX <= 1'b0;
        data_sram_we_EX <= 4'b0;
        data_sram_wdata_EX <= 32'b0;
    end
    else if(valid_ID) begin
        data_sram_en_EX <= valid_ID; // 片选信号在读或者写的时候都要拉高！！！
        data_sram_we_EX <= {4{mem_we && valid_ID}};
        data_sram_wdata_EX <= rkd_value;
    end
end

// EX
reg         valid_EX;      // 控制信号
always @(posedge clk) begin
    if (reset) begin
        valid_EX <= 1'b0;
    end
    else begin
        valid_EX <= valid_ID;
    end
end

reg [31:0] pc_MEM;              // MEM级当前PC值
reg [ 4:0] rf_waddr_MEM;        // 写寄存器的地址
reg        rf_we_MEM;           // 写寄存器使能
reg        res_from_mem_MEM;       // 最后要写进寄存器的结果是否来自内存
always @(posedge clk) begin
    if (reset) begin
        rf_waddr_MEM <= 5'b0;
        rf_we_MEM <= 1'b0;
        res_from_mem_MEM <= 1'b0;
        pc_MEM <= 32'b0;
    end
    else if(valid_EX) begin
        rf_waddr_MEM <= rf_waddr_EX;
        rf_we_MEM <= rf_we_EX;
        res_from_mem_MEM <= res_from_mem_EX;
        pc_MEM <= pc_EX;
    end
end

reg [31:0] alu_result_MEM;
always @(posedge clk) begin
    if (reset) begin
        alu_result_MEM <= 32'b0;
    end
    else if(valid_EX) begin
        alu_result_MEM <= alu_result;
    end
end

assign data_sram_we   = data_sram_we_EX;
assign data_sram_wdata = data_sram_wdata_EX;
assign data_sram_en   = data_sram_en_EX;
assign data_sram_addr  = alu_result;

// MEM
reg         valid_MEM;      // 控制信号
always @(posedge clk) begin
    if (reset) begin
        valid_MEM <= 1'b0;
    end
    else begin
        valid_MEM <= valid_EXE;
    end
end

reg [31:0] pc_WB;              // WB级当前PC值
reg [ 4:0] rf_waddr_WB;        // 写寄存器的地址
reg        rf_we_WB;           // 写寄存器使能
reg [31:0] rf_wdata_WB;        // 写寄存器的数据
always @(posedge clk) begin
    if (reset) begin
        rf_waddr_WB <= 5'b0;
        rf_we_WB <= 1'b0;
        rf_wdata_WB <= 32'b0;
        pc_WB <= 32'b0;
    end
    else if(valid_MEM) begin
        rf_waddr_WB <= rf_waddr_MEM;
        rf_we_WB <= rf_we_MEM;
        rf_wdata_WB <= final_result;
        pc_WB <= pc_MEM;
    end
end

assign mem_result   = data_sram_rdata;
assign final_result = res_from_mem_MEM ? mem_result : alu_result_MEM;

// WB

/*------------------*/

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

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d )); // 解码器
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
                             {{14{i16[15]}}, i16[15:0], 2'b0} ; // 选择PC的偏移量，16位还是26位

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};    // 设置jirl指令的偏移量

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w; // 判断寄存器堆第二个读地址在哪个数据段中，rd还是rk

assign src1_is_pc    = inst_jirl | inst_bl;         // 源操作数1是否为PC值

assign src2_is_imm   = inst_slli_w |                // 源操作数2是否为立即数
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign res_from_mem  = inst_ld_w;                   // 最后要写进寄存器的结果是否来自内存  
assign dst_is_r1     = inst_bl;                     // link操作会将返回地址写入一号寄存器，且这个是隐含的，并不在指令中体现，因此需要特殊处理
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign mem_we        = inst_st_w;                   // 判断是否需要写内存
assign dest          = dst_is_r1 ? 5'd1 : rd;

assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we_WB ),
    .waddr  (rf_waddr_WB),
    .wdata  (rf_wdata_WB)
    );

assign rj_value  = rf_rdata1;
assign rkd_value = rf_rdata2;

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid;
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (pc_ID + br_offs) :
                                                   /*inst_jirl*/ (rj_value + jirl_offs); // 获取下一个PC值

assign alu_src1 = src1_is_pc  ? pc_ID[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

alu u_alu(
    .alu_op     (alu_op_EX    ),
    .alu_src1   (alu_src1_EX  ),
    .alu_src2   (alu_src2_EX  ),
    .alu_result (alu_result)
    );

// debug info generate
assign debug_wb_pc       = pc_WB;
assign debug_wb_rf_we   = {4{rf_we_WB}};
assign debug_wb_rf_wnum  = rf_waddr_WB;
assign debug_wb_rf_wdata = rf_wdata_WB;

endmodule
