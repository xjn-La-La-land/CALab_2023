`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 

module pipe_ID(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入
    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc,
    input  wire [31:0] inst_sram_rdata,

    input  wire [31:0] rf_rdata1,         // 读数据
    input  wire [31:0] rf_rdata2,        

    input  wire        rf_we_EX,       // 用于读写对比
    input  wire [ 4:0] rf_waddr_EX,
    input  wire        res_from_mem_EX,
    input  wire [31:0] alu_result_EX, // EX阶段数据前递

    input  wire        rf_we_MEM,
    input  wire [ 4:0] rf_waddr_MEM,
    input  wire [31:0] rf_wdata_MEM, // MEM阶段用于数据前递
    
    input  wire        rf_we_WB,
    input  wire [ 4:0] rf_waddr_WB,
    input  wire [31:0] rf_wdata_WB, // WB阶段用于数据前递

    output wire        to_valid,       // IF数据可以发出
    output wire        to_allowin,     // 允许preIF阶段的数据进�?

    output wire        br_taken,       // 跳转信号
    output wire [31:0] br_target,      

    output wire [ 4:0] rf_raddr1,         // 读地址
    output wire [ 4:0] rf_raddr2,

    output wire        rf_we,
    output wire [ 4:0] rf_waddr,
    output wire        res_from_mem,   // 判断要写进寄存器的结果是否来自内存

    output wire [11:0] alu_op,         // ALU的操作码 
    output wire [31:0] alu_src1,       // ALU的操作数          
    output wire [31:0] alu_src2,

    output wire [3:0]  data_sram_we,   
    output wire [31:0] data_sram_wdata,
    output wire        data_sram_en,

    output reg  [31:0] PC
);

    wire ready_go;              // 数据处理完成信号
    reg valid;
    wire rw_conflict;        // 读写冲突
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

// 各条指令的译码识别信号
/*-------------------------------------------------------------------------------------------------------------*/
// 算数运算类指令(在EXE阶段计算)            指令格式                            操作
wire        inst_add_w;   /*           add.w rd, rj, rk               GR[rd] = GR[rj] + GR[rk]        */
wire        inst_sub_w;   /*           sub.w rd, rj, rk               GR[rd] = GR[rj] - GR[rk]        */
wire        inst_addi_w;  /*           addi.w rd, rj, si12            GR[rd] = GR[rj] + sext32(si12)  */
wire        inst_slt;     /*           slt rd, rj, rk                 GR[rd] = GR[rj] <signed GR[rk]  */
wire        inst_sltu;    /*           sltu rd, rj, rk                GR[rd] = GR[rj] <unsigned GR[rk] */
wire        inst_slti;    /*           slti rd, rj, si12              GR[rd] = GR[rj] <signed sext32(si12) */
wire        inst_sltui;   /*           sltui rd, rj, si12             GR[rd] = GR[rj] <unsigned sext32(si12) */
wire        inst_pcaddu12i;/*          pcaddu12i rd, si20             GR[rd] = PC + {si20, 12’b0}     */
/*-------------------------------------------------------------------------------------------------------------*/
// 逻辑运算类指令(在EXE阶段计算)
wire        inst_and;     /*           and rd, rj, rk                 GR[rd] = GR[rj] & GR[rk]        */
wire        inst_or;      /*           or rd, rj, rk                  GR[rd] = GR[rj] | GR[rk]        */
wire        inst_nor;     /*           nor rd, rj, rk                 GR[rd] = ~(GR[rj] | GR[rk])     */
wire        inst_xor;     /*           xor rd, rj, rk                 GR[rd] = GR[rj] ^ GR[rk]        */
wire        inst_andi;    /*           andi rd, rj, ui12              GR[rd] = GR[rj] & zext32(ui12)  */
wire        inst_ori;     /*           ori rd, rj, ui12               GR[rd] = GR[rj] | zext32(ui12)  */
wire        inst_xori;    /*           xori rd, rj, ui12              GR[rd] = GR[rj] ^ zext32(ui12)  */
/*-------------------------------------------------------------------------------------------------------------*/
// 移位指令
wire        inst_sll_w;   /*           sll.w rd, rj, rk               GR[rd] = GR[rj] << GR[rk][4:0]  */
wire        inst_srl_w;   /*           srl.w rd, rj, rk               GR[rd] = GR[rj] >>logic GR[rk][4:0] */
wire        inst_sra_w;   /*           sra.w rd, rj, rk               GR[rd] = GR[rj] >>arith GR[rk][4:0] */
wire        inst_slli_w;  /*           slli.w rd, rj, ui5             GR[rd] = GR[rj] << ui5          */
wire        inst_srli_w;  /*           srli.w rd, rj, ui5             GR[rd] = GR[rj] >>logic ui5     */
wire        inst_srai_w;  /*           srai.w rd, rj, ui5             GR[rd] = GR[rj] >>arith ui5     */
/*-------------------------------------------------------------------------------------------------------------*/
// load类指令
wire        inst_ld_w;    /*           ld.w rd, rj, si12              GR[rd] = MEM[GR[rj]+sext32(si12)][31:0] */
/*-------------------------------------------------------------------------------------------------------------*/
// store类指令
wire        inst_st_w;    /*           st.w rd, rj, si12              MEM[GR[rj]+sext32(si12)][31:0] = GR[rd] */
/*-------------------------------------------------------------------------------------------------------------*/
// 无条件间接跳转
wire        inst_jirl;    /*           jirl rd, rj, offs16            GR[rd] = PC+4; PC = GR[rj]+sext32({offs16, 2’b0}) */
/*-------------------------------------------------------------------------------------------------------------*/
// 无条件相对PC跳转; BrTarget = PC + sext32({off26, 2’b0}
wire        inst_b;       /*           b offs26                       PC = BrTarget                   */
wire        inst_bl;      /*           bl offs26                      GR[1] = PC+4; PC = BrTarget     */
/*-------------------------------------------------------------------------------------------------------------*/
// 条件分支; TakenTgt = PC + sext32({off16, 2’b0})
wire        inst_beq;     /*           beq rj, rd, off16              if (GR[rj]==GR[rd]); PC = TakenTgt */
wire        inst_bne;     /*           bne rj, rd, offs16             if (GR[rj]!=GR[rd]); PC = TakenTgt */
/*-------------------------------------------------------------------------------------------------------------*/
// 立即数装载
wire        inst_lu12i_w; /*           lu12i rd, si20                 GR[rd] = {si20, 12’b0}           */



    wire        need_ui5;           // 各类指令是否�?要立即数，据此对立即数进行赋�?
    wire        need_si12;
    wire        need_ui12;
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
    assign inst_slti   = op_31_26_d[6'h00] & op_25_22_d[4'h8];
    assign inst_sltui  = op_31_26_d[6'h00] & op_25_22_d[4'h9];
    assign inst_nor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h08];
    assign inst_and    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h09];
    assign inst_or     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0a];
    assign inst_xor    = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0b];
    assign inst_andi   = op_31_26_d[6'h00] & op_25_22_d[4'hd];
    assign inst_ori    = op_31_26_d[6'h00] & op_25_22_d[4'he];
    assign inst_xori   = op_31_26_d[6'h00] & op_25_22_d[4'hf];
    assign inst_sll_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0e];
    assign inst_srl_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h0f];
    assign inst_sra_w  = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h10];
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
    assign inst_pcaddu12i= op_31_26_d[6'h07] & ~inst[25];
    
    assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_pcaddu12i |inst_ld_w | inst_st_w
                        | inst_jirl | inst_bl;
    assign alu_op[ 1] = inst_sub_w;
    assign alu_op[ 2] = inst_slt | inst_slti;
    assign alu_op[ 3] = inst_sltu | inst_sltui;
    assign alu_op[ 4] = inst_and | inst_andi;
    assign alu_op[ 5] = inst_nor;
    assign alu_op[ 6] = inst_or | inst_ori;
    assign alu_op[ 7] = inst_xor | inst_xori;
    assign alu_op[ 8] = inst_sll_w | inst_slli_w;
    assign alu_op[ 9] = inst_srl_w | inst_srli_w;
    assign alu_op[10] = inst_sra_w | inst_srai_w;
    assign alu_op[11] = inst_lu12i_w;
    
    assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
    assign need_si12  =  inst_addi_w | inst_ld_w | inst_st_w | inst_slti | inst_sltui;
    assign need_ui12  =  inst_andi | inst_ori | inst_xori;
    assign need_si16  =  inst_jirl | inst_beq | inst_bne;
    assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
    assign need_si26  =  inst_b | inst_bl;
    assign src2_is_4  =  inst_jirl | inst_bl;
    
    assign imm = src2_is_4 ? 32'h4                      :
                 need_si20 ? {i20[19:0], 12'b0}         :
                 need_ui12 ? {{20'b0}, i12[11:0]}       :
    /*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;
    
    assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                                 {{14{i16[15]}}, i16[15:0], 2'b0} ; // 选择PC的偏移量�?16位还�?26�?
    
    assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};    // 设置jirl指令的偏移量
    
    assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w; // 判断寄存器堆第二个读地址在哪个数据段中，rd还是rk
    
    assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;         // 源操作数1是否为PC�?
    
    assign src2_is_imm   = inst_slli_w |                // 源操作数2是否为立即数
                           inst_srli_w |
                           inst_srai_w |
                           inst_addi_w |
                           inst_ld_w   |
                           inst_st_w   |
                           inst_lu12i_w|
                           inst_pcaddu12i|
                           inst_jirl   |
                           inst_bl     |
                           inst_slti   |
                           inst_sltui  |
                           inst_andi   |
                           inst_ori    |
                           inst_xori;
     
    assign dst_is_r1     = inst_bl;                     // link操作会将返回地址写入1号寄存器，且这个是隐含的，并不在指令中体现，因此�?要特殊处�?
    assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
    assign mem_we        = inst_st_w;                   // 判断是否�?要写内存
    assign dest          = dst_is_r1 ? 5'd1 : rd;

    assign raddr1_valid = ~(inst_b | inst_bl | inst_lu12i_w | inst_pcaddu12i);
    assign raddr2_valid = ~(inst_slli_w
                            | inst_srli_w
                            | inst_srai_w
                            | inst_addi_w
                            | inst_ld_w
                            | inst_lu12i_w
                            | inst_pcaddu12i
                            | inst_jirl
                            | inst_b 
                            | inst_bl
                            | inst_slti
                            | inst_sltui
                            | inst_andi
                            | inst_ori
                            | inst_xori  
                        );

    assign rf_raddr1 = {5{raddr1_valid}} & rj;
    assign rf_raddr2 = {5{raddr2_valid}} & (src_reg_is_rd ? rd :rk);

    assign rw_conflict = ((rf_raddr1 != 5'b0) | (rf_raddr2 != 5'b0)) 
                        & ((rf_raddr1 == rf_waddr_EX) & rf_we_EX |
                           (rf_raddr2 == rf_waddr_EX) & rf_we_EX) 
                        & res_from_mem_EX; // 当当前指令的读数据需要等待从内存中读取时，阻塞一拍

    assign rj_value  = {32{(rf_raddr1 != 5'b0)}} &
                    (
                        ((rf_raddr1 == rf_waddr_EX) & rf_we_EX) ? alu_result_EX 
                        : ((rf_raddr1 == rf_waddr_MEM) & rf_we_MEM) ? rf_wdata_MEM
                        : ((rf_raddr1 == rf_waddr_WB) & rf_we_WB) ? rf_wdata_WB
                        : rf_rdata1
                    );

    assign rkd_value = {32{(rf_raddr2 != 5'b0)}} &
                    (
                        ((rf_raddr2 == rf_waddr_EX) & rf_we_EX) ? alu_result_EX 
                        : ((rf_raddr2 == rf_waddr_MEM) & rf_we_MEM) ? rf_wdata_MEM
                        : ((rf_raddr2 == rf_waddr_WB) & rf_we_WB) ? rf_wdata_WB
                        : rf_rdata2
                    );

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