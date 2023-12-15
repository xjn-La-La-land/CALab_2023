`include "define.v"

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
    input  wire        res_from_mem_EX,  // load阻塞
    input  wire [31:0] alu_result_EX, // EX阶段数据前递

    input  wire        rf_we_MEM,
    input  wire [ 4:0] rf_waddr_MEM,
    input  wire        mem_waiting,  // load阻塞
    input  wire [31:0] rf_wdata_MEM, // MEM阶段用于数据前递
    
    input  wire        rf_we_WB,
    input  wire [ 4:0] rf_waddr_WB,
    input  wire [31:0] rf_wdata_WB, // WB阶段用于数据前递

    input  wire        csr_en_EX,
    input  wire        csr_en_MEM,
    input  wire        csr_we_EX,
    input  wire        csr_we_MEM,
    input  wire        csr_we_WB,
    input  wire        rd_cnt_EX,
    input  wire        rd_cnt_MEM,
    
    input  wire        ex_WB,       // 异常指令到达WB级，清空流水线
    input  wire        flush_WB,    // ertn指令到达WB级，清空流水线
    input  wire        tlb_flush_WB,// tlb冲突指令到达WB级，清空流水线

    input  wire        has_int,        // 中断信号

    input  wire [13:0] exception_source_in, // IF级传入的exception_source



    output wire        to_valid,       // IF数据可以发出
    output wire        to_allowin,     // 允许preIF阶段的数据进入

    output wire        br_taken,       // 跳转信号
    output wire [31:0] br_target,      // 跳转目标地址

    output wire [ 4:0] rf_raddr1,      // 读寄存器编号
    output wire [ 4:0] rf_raddr2,

    output wire        rf_we,
    output wire [ 4:0] rf_waddr,
    output wire        res_from_mem,   // 判断要写进寄存器的结果是否来自内存

    output wire [18:0] alu_op,         // ALU的操作码 
    output wire [31:0] alu_src1,       // ALU的操作数          
    output wire [31:0] alu_src2,

    output wire [ 4:0] load_op,         // load操作码
    output wire [ 2:0] store_op,        // store操作码
    output wire [31:0] mem_wdata,       // store写数据

    // 控制寄存器
    output  [13:0]     csr_num,
    output             csr_en,
    output             csr_we,
    output  [31:0]     csr_wmask,
    output  [31:0]     csr_wdata,

    // ertn 信号
    output wire        ertn_flush,

    // 读计时器信号
    output wire [2:0]  rd_cnt_op,      // {inst_rdcntvh_w, inst_rdcntvl_w, inst_rdcntid}

    // tlb信号
    output wire [4:0]  tlb_command,    // 由于tlb指令在后面的流水级有特殊操作，因此将指令信号传递到EX阶段
    output wire [4:0]  invtlb_op,

    // tlb 修改引发的访存冲突
    output reg         tlb_flush,      // tlb指令修改引发的访存冲突

    // 异常信号
    output wire [13:0] exception_source, // {TLBR(IF), TLBR(EX), INE, BRK, SYS, ALE, ADEF, PPI(IF), PPI(EX), PME, PIF, PIS, PIL, INT}

    output reg  [31:0] PC
);

wire ready_go;              // 数据处理完成信号
reg  valid;

// 写后读数据先关
wire load_rw_conflict;      // EXE级的load型指令出现写后读
wire csrr_rw_conflict;      // csrrd, csrxchg指令出现写后读
wire gr_rw_conflict;        // 通用寄存器数据相关

wire csr_rw_conflict;       // csr寄存器数据相关

assign ready_go = valid && (~gr_rw_conflict) && (~csr_rw_conflict);
assign to_allowin = !valid || ready_go && from_allowin || ex_WB || flush_WB || tlb_flush_WB;
assign to_valid = valid & ready_go & ~flush_WB & ~ex_WB & ~tlb_flush_WB;
    
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b0;
    end
    else if(ready_go && (br_taken || ex_WB || flush_WB || tlb_flush_WB)) begin // 如果需要跳转并且跳转了，则从下一个阶段开始valid就需要重置为零了
        valid <= 1'b0;
    end
    else if(to_allowin) begin // 如果当前阶段允许数据进入，则数据是否有效就取决于上一阶段数据是否可以发出
        valid <= from_valid;
    end
end

wire data_allowin; // 拉手成功，数据可以进入
assign data_allowin = from_valid && to_allowin;

reg [31:0] inst;              // ID级当前PC的指令
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

wire        src1_is_pc;         // 源操作数1是否为PC
wire        src2_is_imm;        // 源操作数2是否为立即数
wire        dst_is_r1;          // 目的寄存器是否为r1，即link操作
wire        gr_we;              // 判断是否需要写回寄存器
wire        src_reg_is_rd;      // 判断寄存器堆第二个读地址在哪个数据段中，rd还是rk

wire [4: 0] dest;               // 写寄存器的目的寄存器地址
wire [31:0] rj_value;           // 寄存器堆第一个读到的数据
wire [31:0] rkd_value;          // 寄存器堆第二个读到的数据
wire [31:0] imm;                // 立即数
wire [31:0] br_offs;            // 分支便偏移量
wire [31:0] jirl_offs;          // 跳转偏移量，即rj_value的值加上的偏移量，用于jirl指令

wire        rj_eq_rd;           // rj_value == rkd_value
wire        rj_lt_ltu_rd;       // rj_value <signed rkd_value / rj_value <unsigned rkd_value

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

// 各条指令的译码识别信�???
/*-------------------------------------------------------------------------------------------------------------*/
// 算数运算类指�????(在EXE阶段计算)            指令格式                            操作
wire        inst_add_w;   /*           add.w rd, rj, rk               GR[rd] = GR[rj] + GR[rk]        */
wire        inst_sub_w;   /*           sub.w rd, rj, rk               GR[rd] = GR[rj] - GR[rk]        */
wire        inst_addi_w;  /*           addi.w rd, rj, si12            GR[rd] = GR[rj] + sext32(si12)  */
wire        inst_slt;     /*           slt rd, rj, rk                 GR[rd] = GR[rj] <signed GR[rk]  */
wire        inst_sltu;    /*           sltu rd, rj, rk                GR[rd] = GR[rj] <unsigned GR[rk] */
wire        inst_slti;    /*           slti rd, rj, si12              GR[rd] = GR[rj] <signed sext32(si12) */
wire        inst_sltui;   /*           sltui rd, rj, si12             GR[rd] = GR[rj] <unsigned sext32(si12) */
wire        inst_pcaddu12i;/*          pcaddu12i rd, si20             GR[rd] = PC + {si20, 12’b0}     */
wire        inst_mul_w;   /*           mul.w rd, rj, rk               GR[rd] = (GR[rj] * GR[rk])[31:0]       */
wire        inst_mulh_w;  /*           mulh.w rd, rj, rk              GR[rd] = (signed)(GR[rj] * GR[rk])[63:32]      */
wire        inst_mulh_wu; /*           mulh.wu rd, rj, rk             GR[rd] = (unsigned)(GR[rj] * GR[rk])[63:32]    */
wire        inst_div_w;   /*           div.w rd, rj, rk               GR[rd] = (signed)(GR[rj] / GR[rk])       */
wire        inst_div_wu;  /*           div.wu rd, rj, rk              GR[rd] = (unsigned)(GR[rj] / GR[rk])     */
wire        inst_mod_w;   /*           mod.w rd, rj, rk               GR[rd] = (signed)(GR[rj] % GR[rk])       */
wire        inst_mod_wu;  /*           mod.wu rd, rj, rk              GR[rd] = (unsigned)(GR[rj] % GR[rk])     */
/*-------------------------------------------------------------------------------------------------------------*/
// 逻辑运算类指�????(在EXE阶段计算)
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
// load类指�??? TgtAddr = GR[rj]+sext32(si12)
wire        inst_ld_b;    /*           ld.b rd, rj, si12              byte = MemoryLoad(TgtAddr, BYTE); GR[rd]=sext32(byte) */
wire        inst_ld_h;    /*           ld.h rd, rj, si12              halfword = MemoryLoad(TgtAddr, HALFWORD); GR[rd]=sext32(halfword) */
wire        inst_ld_w;    /*           ld.w rd, rj, si12              GR[rd] = MEM[TgtAddr][31:0]     */
wire        inst_ld_bu;   /*           ld.bu rd, rj, si12             byte = MemoryLoad(TgtAddr, BYTE); GR[rd]=zext32(byte) */
wire        inst_ld_hu;   /*           ld.hu rd, rj, si12             halfword = MemoryLoad(TgtAddr, HALFWORD); GR[rd]=zext32(halfword) */
/*-------------------------------------------------------------------------------------------------------------*/
// store类指�??? TgtAddr = GR[rj]+sext32(si12)
wire        inst_st_b;    /*           st.b rd, rj, si12              MemoryStore(GR[rd][7:0], TgtAddr, BYTE) */
wire        inst_st_h;    /*           st.h rd, rj, si12              MemoryStore(GR[rd][15:0]. TgtAddr, HALFBYTE) */
wire        inst_st_w;    /*           st.w rd, rj, si12              MEM[TgtAddr][31:0] = GR[rd] */
/*-------------------------------------------------------------------------------------------------------------*/
// 无条件间接跳�???
wire        inst_jirl;    /*           jirl rd, rj, offs16            GR[rd] = PC+4; PC = GR[rj]+sext32({offs16, 2’b0}) */
/*-------------------------------------------------------------------------------------------------------------*/
// 无条件相对PC跳转; BrTarget = PC + sext32({offs26, 2’b0})
wire        inst_b;       /*           b offs26                       PC = BrTarget                   */
wire        inst_bl;      /*           bl offs26                      GR[1] = PC+4; PC = BrTarget     */
/*-------------------------------------------------------------------------------------------------------------*/
// 条件分支; TakenTgt = PC + sext32({offs16, 2’b0})
wire        inst_beq;     /*           beq rj, rd, offs16             if (GR[rj]==GR[rd]): PC = TakenTgt */
wire        inst_bne;     /*           bne rj, rd, offs16             if (GR[rj]!=GR[rd]): PC = TakenTgt */
wire        inst_blt;     /*           blt rj, rd, offs16             if (GR[rj] <signed GR[rd]): PC = TakenTgt */
wire        inst_bge;     /*           bge rj, rd, offs16             if (GR[rj] >=signed GR[rd]): PC = TakenTgt */
wire        inst_bltu;    /*           bltu rj, rd, offs16            if (GR[rj] <unsigned GR[rd]): PC = TakenTgt */
wire        inst_bgeu;    /*           bgeu rj, rd, offs16            if (GR[rj] >=unsigned GR[rd]): PC = TakenTgt */
/*-------------------------------------------------------------------------------------------------------------*/
// 立即数装载
wire        inst_lu12i_w; /*           lu12i rd, si20                 GR[rd] = {si20, 12’b0}           */
/*-------------------------------------------------------------------------------------------------------------*/
// 状态控制器读写
wire        inst_csr;
wire        inst_csrrd;   /*           csrrd rd, csr_num              GR[rd] = CSR[csr_num]           */
wire        inst_csrwr;   /*           csrwr rd, csr_num              CSR[csr_num] = GR[rj], GR[rj] = CSR[csr_num] */
wire        inst_csrxchg; /*           csrxchg rd, rj, csr_num        CSR[csr_num] = GR[rj] & GR[rd], GR[rd] = CSR[csr_num]*/
/*-------------------------------------------------------------------------------------------------------------*/
// 异常返回指令
wire        inst_ertn;    /*           ertn                                                                  */
/*-------------------------------------------------------------------------------------------------------------*/
// 软件中断指令
wire        inst_syscall; /*           syscall code                   cause a SYS exception                     */
/*-------------------------------------------------------------------------------------------------------------*/
// 断点指令
wire        inst_break;   /*           break code                     cause a BRK exception                     */
/*-------------------------------------------------------------------------------------------------------------*/
// 读计时器指令 
wire        inst_rdtimel_w; /*         rdtimel.w rd, rj               GR[rd] = Stable_Counter[31:0], GR[rj] = Counter_ID*/
wire        inst_rdtimeh_w; /*         rdtimeh.w rd, rj               GR[rd] = Stable_Counter[63:32], GR[rj] = Counter_ID*/
wire        inst_rdcntvl_w; /*         rdcntvl.w rd                   rdtimel.w rd, zero                        */
wire        inst_rdcntvh_w; /*         rdcntvh.w rd                   rdtimeh.w rd, zero                        */
wire        inst_rdcntid;   /*         rdcntid rj                     rdtimel.w zero, rj                        */
/*-------------------------------------------------------------------------------------------------------------*/
// TLB相关指令
wire        inst_tlbsrch;  /*           tlbsrch                                                                 */
wire        inst_tlbwr;    /*           tlbwr                                                                   */
wire        inst_tlbrd;    /*           tlbrd                                                                   */
wire        inst_tlbfill;  /*           tlbfill                                                                 */
wire        inst_invtlb;   /*           invtlb op, rj, rk                                                       */
/*-------------------------------------------------------------------------------------------------------------*/

// 异常信号定义
reg  [13:0] exception_source_IF;/*     exception source from IF                                              */
wire        ex_int;       /*           interrupt signal                                                      */
wire        ex_sys;       /*           exception syscall signal                                              */
wire        ex_brk;       /*           exception break signal                                                */
wire        ex_ine;       /*           exception ine signal                                                  */



wire        need_ui5;           // 各类指令是需要立即数，据此对立即数进行赋值
wire        need_si12;
wire        need_ui12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;

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

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d )); // 解码器
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
assign inst_ld_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h0];
assign inst_ld_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h1];
assign inst_ld_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h2];
assign inst_st_b   = op_31_26_d[6'h0a] & op_25_22_d[4'h4];
assign inst_st_h   = op_31_26_d[6'h0a] & op_25_22_d[4'h5];
assign inst_st_w   = op_31_26_d[6'h0a] & op_25_22_d[4'h6];
assign inst_ld_bu  = op_31_26_d[6'h0a] & op_25_22_d[4'h8];
assign inst_ld_hu  = op_31_26_d[6'h0a] & op_25_22_d[4'h9];
assign inst_jirl   = op_31_26_d[6'h13];
assign inst_b      = op_31_26_d[6'h14];
assign inst_bl     = op_31_26_d[6'h15];
assign inst_beq    = op_31_26_d[6'h16];
assign inst_bne    = op_31_26_d[6'h17];
assign inst_blt    = op_31_26_d[6'h18];
assign inst_bge    = op_31_26_d[6'h19];
assign inst_bltu   = op_31_26_d[6'h1a];
assign inst_bgeu   = op_31_26_d[6'h1b];
assign inst_lu12i_w= op_31_26_d[6'h05] & ~inst[25];
assign inst_pcaddu12i= op_31_26_d[6'h07] & ~inst[25];
assign inst_mul_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h18];
assign inst_mulh_w      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h19];
assign inst_mulh_wu     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h1] & op_19_15_d[5'h1a];
assign inst_div_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h00];
assign inst_mod_w       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h01];
assign inst_div_wu      = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h02];
assign inst_mod_wu      = op_31_26_d[ 6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h03];
assign inst_csr         = op_31_26_d[6'h01] & ~inst[25];
assign inst_csrrd       = inst_csr & (rj == 5'b0);
assign inst_csrwr       = inst_csr & (rj == 5'b1);
assign inst_csrxchg     = inst_csr & ~(inst_csrrd | inst_csrwr);
assign inst_ertn        = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0e) & (rj == 5'h00) & (rd == 5'h00);
assign inst_syscall     = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h16];
assign inst_break       = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h2] & op_19_15_d[5'h14];

assign inst_rdtimel_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & (rk == 5'h18);
assign inst_rdtimeh_w   = op_31_26_d[6'h00] & op_25_22_d[4'h0] & op_21_20_d[2'h0] & op_19_15_d[5'h0] & (rk == 5'h19);

assign inst_rdcntvl_w   = inst_rdtimel_w & (rj == 5'h0);
assign inst_rdcntvh_w   = inst_rdtimeh_w & (rj == 5'h0);
assign inst_rdcntid     = inst_rdtimel_w & (rd == 5'h0);

assign inst_tlbsrch     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0a);
assign inst_tlbrd       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0b);
assign inst_tlbwr       = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0c);
assign inst_tlbfill     = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h10] & (rk == 5'h0d);
assign inst_invtlb      = op_31_26_d[6'h01] & op_25_22_d[4'h9] & op_21_20_d[2'h0] & op_19_15_d[5'h13];




assign alu_op[ 0] = inst_add_w | inst_addi_w | inst_pcaddu12i | 
                    inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu |
                    inst_st_w | inst_st_b | inst_st_h |
                    inst_jirl | inst_bl | inst_csr;
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
assign alu_op[12] = inst_mul_w;
assign alu_op[13] = inst_mulh_w;
assign alu_op[14] = inst_mulh_wu;
assign alu_op[15] = inst_div_w;
assign alu_op[16] = inst_mod_w;
assign alu_op[17] = inst_div_wu;
assign alu_op[18] = inst_mod_wu;

assign need_ui5   =  inst_slli_w | inst_srli_w | inst_srai_w;
assign need_si12  =  inst_addi_w | inst_slti | inst_sltui |
                        inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu |
                        inst_st_b | inst_st_h | inst_st_w;
assign need_ui12  =  inst_andi | inst_ori | inst_xori;
assign need_si16  =  inst_jirl | inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu;
assign need_si20  =  inst_lu12i_w | inst_pcaddu12i;
assign need_si26  =  inst_b | inst_bl;
assign src2_is_4  =  inst_jirl | inst_bl;

assign imm = src2_is_4 ? 32'h4                      :
                need_si20 ? {i20[19:0], 12'b0}         :
                need_ui12 ? {{20'b0}, i12[11:0]}       :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                                {{14{i16[15]}}, i16[15:0], 2'b0} ; // 选择PC的偏移量�???16位还�???26�???
// 设置jirl指令的偏移量
assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};
// 判断寄存器堆第二个读地址在哪个数据段中，rd还是rk
assign src_reg_is_rd = inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu |
                        inst_st_b | inst_st_h | inst_st_w | inst_csrwr | inst_csrxchg;
// 源操作数1是否为PC
assign src1_is_pc    = inst_jirl | inst_bl | inst_pcaddu12i;
// 源操作数2是否为立即数
assign src2_is_imm   = inst_slli_w | inst_srli_w | inst_srai_w |
                        inst_addi_w |
                        inst_ld_w   | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu |
                        inst_st_w   | inst_st_b | inst_st_h |
                        inst_lu12i_w|
                        inst_pcaddu12i|
                        inst_jirl   |
                        inst_bl     |
                        inst_slti   | inst_sltui | inst_andi | inst_ori | inst_xori;
    
assign dst_is_r1     = inst_bl;                     // link操作会将返回地址写入1号寄存器，且这个是隐含的，并不在指令中体现，因此�???要特殊处�???
assign gr_we         = ~(inst_st_w | inst_st_b | inst_st_h |
                            inst_beq | inst_bne | inst_blt | inst_bge | inst_bltu | inst_bgeu | 
                            inst_b | inst_ertn | inst_syscall | inst_break |
                            inst_tlbfill | inst_invtlb | inst_tlbwr | inst_tlbrd | inst_tlbsrch
                        ); // 判断是否�???要写回寄存器
assign dest          = dst_is_r1 ? 5'd1 : (inst_rdcntid ? rj : rd);

assign raddr1_valid = ~(inst_b | inst_bl | inst_lu12i_w | inst_pcaddu12i | inst_tlbrd | inst_tlbfill | inst_tlbsrch | inst_tlbwr);
assign raddr2_valid = ~(inst_slli_w | inst_srli_w | inst_srai_w
                        | inst_addi_w
                        | inst_slti | inst_sltui 
                        | inst_andi | inst_ori | inst_xori
                        | inst_ld_w | inst_ld_b | inst_ld_bu | inst_ld_h | inst_ld_hu
                        | inst_lu12i_w
                        | inst_pcaddu12i
                        | inst_jirl
                        | inst_b | inst_bl
                        | inst_tlbrd | inst_tlbfill | inst_tlbsrch | inst_tlbwr
                    );

assign rf_raddr1 = {5{raddr1_valid}} & rj;
assign rf_raddr2 = {5{raddr2_valid}} & (src_reg_is_rd ? rd :rk);

// 写后读冲突相关的处理
assign load_rw_conflict = (rf_raddr1 != 5'b0) && 
                            (rf_we_EX && res_from_mem_EX && (rf_raddr1 == rf_waddr_EX) || 
                             rf_we_MEM && mem_waiting && (rf_raddr1 == rf_waddr_MEM))  ||
                          (rf_raddr2 != 5'b0) && 
                            (rf_we_EX && res_from_mem_EX && (rf_raddr2 == rf_waddr_EX) ||
                             rf_we_MEM && mem_waiting && (rf_raddr2 == rf_waddr_MEM));

assign csrr_rw_conflict = ((rf_raddr1 != 5'b0) || (rf_raddr2 != 5'b0)) && 
                          (((csr_en_EX || rd_cnt_EX) && (rf_raddr1 == rf_waddr_EX || rf_raddr2 == rf_waddr_EX)) ||
                           ((csr_en_MEM || rd_cnt_MEM) && (rf_raddr1 == rf_waddr_MEM || rf_raddr2 == rf_waddr_MEM))); // csrrd, csrxchg指令在EX/MEM级不前递，到WB级前递


assign gr_rw_conflict = load_rw_conflict || csrr_rw_conflict;

assign rj_value  = {32{(rf_raddr1 != 5'b0)}} &
                (
                    ((rf_raddr1 == rf_waddr_EX) & rf_we_EX) ? alu_result_EX 
                    : ((rf_raddr1 == rf_waddr_MEM) & rf_we_MEM) ? rf_wdata_MEM
                    : ((rf_raddr1 == rf_waddr_WB) & rf_we_WB) ? rf_wdata_WB
                    : rf_rdata1
                );  //数据前递逻辑

assign rkd_value = {32{(rf_raddr2 != 5'b0)}} &
                (
                    ((rf_raddr2 == rf_waddr_EX) & rf_we_EX) ? alu_result_EX 
                    : ((rf_raddr2 == rf_waddr_MEM) & rf_we_MEM) ? rf_wdata_MEM
                    : ((rf_raddr2 == rf_waddr_WB) & rf_we_WB) ? rf_wdata_WB
                    : rf_rdata2
                );


comparator_32 u_comparator_32(
    .src1(rj_value),
    .src2(rkd_value),
    .sign(inst_blt || inst_bge),
    .res(rj_lt_ltu_rd)
);

assign rj_eq_rd  = (rj_value == rkd_value);
assign br_taken  = (  inst_beq  &&  rj_eq_rd
                    || inst_bne  && !rj_eq_rd
                    ||(inst_blt || inst_bltu) &&  rj_lt_ltu_rd
                    ||(inst_bge || inst_bgeu) && !rj_lt_ltu_rd
                    || inst_jirl
                    || inst_bl
                    || inst_b
                    ) && valid && ~gr_rw_conflict;
assign br_target = (inst_beq || inst_bne || inst_blt || inst_bge || inst_bltu || inst_bgeu || inst_bl || inst_b) ? 
                                (PC + br_offs) :
                    /*inst_jirl*/ (rj_value + jirl_offs); // 获取下一个PC跳转地址
assign rf_waddr = dest;
assign rf_we = gr_we && valid;
assign res_from_mem = inst_ld_w | inst_ld_b | inst_ld_h | inst_ld_bu | inst_ld_hu;
assign load_op      = {inst_ld_b, inst_ld_bu, inst_ld_h, inst_ld_hu, inst_ld_w};
assign store_op     = {inst_st_b, inst_st_h, inst_st_w};

assign alu_src1 = src1_is_pc ? PC[31:0] : rj_value;
assign alu_src2 = src2_is_imm ? imm : rkd_value;

assign mem_wdata = inst_st_b ? {4{rkd_value[ 7:0]}} :
                   inst_st_h ? {2{rkd_value[15:0]}} :
                                  rkd_value[31:0];

// 控制寄存器逻辑
wire [13:0] csr_num_special;
assign csr_num_special = {14{inst_rdcntid}} & `CSR_TID
                       | {14{inst_tlbsrch}} & `CSR_TLBIDX
                       | {14{inst_tlbrd}} & 14'h3fff; // num全为1表示要写csr寄存器，但是不通过正常的写入口
assign csr_num = (csr_num_special != 14'b0)? csr_num_special : inst[23:10];
assign csr_wdata = rkd_value;
assign csr_en = inst_csr | inst_tlbsrch | inst_tlbrd;
assign csr_we = inst_csrwr | inst_csrxchg | inst_tlbsrch | inst_tlbrd; // csr写使能
assign csr_wmask = (inst_csrxchg)? rj_value : 32'hffffffff;

assign rd_cnt_op = {inst_rdcntvh_w, inst_rdcntvl_w, inst_rdcntid};

// 当后三个流水级上有csr写入指令，ID级标记中断就要阻塞
assign csr_rw_conflict = (csr_we_EX | csr_we_MEM | csr_we_WB);


// tlb 相关指令逻辑
assign tlb_command = {inst_invtlb, inst_tlbrd, inst_tlbfill, inst_tlbwr, inst_tlbsrch};
assign invtlb_op = rd;

wire ex_invtlb; // invtlb op 值不为0-6时，触发指令不存在异常
assign ex_invtlb =  inst_invtlb & (invtlb_op[2:0] == 3'h7 | invtlb_op[4:3] != 2'h0);

wire tlb_conflict; // tlb修改和访存冲突，通过标记后面所有的流水级进行消除
assign tlb_conflict = (inst_tlbwr | inst_tlbfill | inst_tlbrd | inst_invtlb |
                        (csr_we & (csr_num == `CSR_CRMD 
                        | csr_num == `CSR_DWM0 
                        | csr_num == `CSR_DWM1
                        | csr_num == `CSR_ASID
                        ))) & valid;
always @(posedge clk) begin
    if (reset) begin
        tlb_flush <= 1'b0;
    end
    else if (tlb_conflict) begin
        tlb_flush <= 1'b1;
    end
    else if (tlb_flush_WB) begin
        tlb_flush <= 1'b0;
    end
end
                    

assign ertn_flush = inst_ertn;

assign ex_int = has_int;
assign ex_sys = inst_syscall;
assign ex_brk = inst_break;
assign ex_ine = (~inst_add_w & ~inst_sub_w & ~inst_slt & ~inst_sltu & ~inst_nor &
                ~inst_and & ~inst_or & ~inst_xor & ~inst_mul_w & ~inst_mulh_w & ~inst_mulh_wu &
                ~inst_div_w & ~inst_mod_w & ~inst_div_wu & ~inst_mod_wu & ~inst_sll_w &
                ~inst_srl_w & ~inst_sra_w & ~inst_slli_w & ~inst_srli_w & ~inst_srai_w &
                ~inst_slti & ~inst_sltui & ~inst_addi_w & ~inst_andi & ~inst_ori &
                ~inst_xori & ~inst_ld_b & ~inst_ld_h & ~inst_ld_bu & ~inst_ld_hu &
                ~inst_ld_w & ~inst_st_b & ~inst_st_h & ~inst_st_w & ~inst_syscall &
                ~inst_break & ~inst_csrrd & ~inst_csrwr & ~inst_csrxchg & ~inst_ertn &
                ~inst_rdcntid & ~inst_rdcntvl_w & ~inst_rdcntvh_w & ~inst_jirl & ~inst_b &
                ~inst_bl & ~inst_beq & ~inst_bne & ~inst_blt & ~inst_bge &
                ~inst_bltu & ~inst_bgeu & ~inst_lu12i_w & ~inst_pcaddu12i & 
                ~inst_tlbsrch & ~inst_tlbwr & ~inst_tlbrd & ~inst_invtlb & ~inst_tlbfill 
                | ex_invtlb) 
                && (exception_source_IF == 14'b0); // IF级无异常



always @(posedge clk) begin
    if (reset) begin
        exception_source_IF <= 14'b0;
    end
    else if(data_allowin) begin
        exception_source_IF <= exception_source_in;
    end
end
// {TLBR(IF), TLBR(EX), INE, BRK, SYS, ALE, ADEF, PPI(IF), PPI(EX), PME, PIF, PIS, PIL, INT}
assign exception_source = exception_source_IF | {2'b0, ex_ine, ex_brk, ex_sys, 8'b0, ex_int};

endmodule