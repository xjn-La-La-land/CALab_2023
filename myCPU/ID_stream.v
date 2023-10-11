module ID_stream(
    input wire         clk,
    input wire         reset,
    input wire         valid,

    // control in
    input wire         IF_to_ID_valid,
    input wire         EXE_allowin,

    // data in
    input wire  [31:0] ID_pc_in,
    input wire  [31:0] ID_inst_in,
    input wire  [ 4:0] EXE_rf_waddr_in,     // 后三个流水级的写回寄存器编号，其中WB阶段的写回寄存器地址就是要传给寄存器堆的rf_waddr
    input wire  [ 4:0] MEM_rf_waddr_in,
    input wire  [ 4:0] WB_rf_waddr_in,
    input wire  [31:0] EXE_rf_wdata_in,     // 后三个流水级的写回数据，用于前递，其中WB阶段的写回数据就是要传给寄存器堆的rf_wdata
    input wire  [31:0] MEM_rf_wdata_in,
    input wire  [31:0] WB_rf_wdata_in,

    input wire         EXE_need_bypass_in,     // 后三个流水级前递的有效信号，其中WB阶段的有效信号就是rf_we_in
    input wire         MEM_need_bypass_in,
    input wire         rf_we_in,
    input wire         EXE_to_ID_stuck_in,  // EXE阶段的load指令无法前递写回的数据给ID

    // data out
    output wire [31:0] ID_pc_out,
    output wire [31:0] ID_rdata1_out,
    output wire [31:0] ID_rdata2_out,
    output wire [31:0] ID_imm_out,
    output wire [ 1:0] ID_alu_ctrl_out,
    output wire [11:0] ID_alu_op_out,
    output wire        ID_mem_rd_out,
    output wire        ID_mem_we_out,  // 译码生成的访存控制信号
    output wire        ID_res_from_mem_out,
    output wire        ID_rf_we_out,    // 译码生成的寄存器写回使能信号
    output wire [ 4:0] ID_rf_waddr_out,

    output wire        br_taken_out,
    output wire [31:0] br_target_out,
    output wire        alu_res_need_bypass_out,

    // control out
    output wire        ID_to_EXE_valid,
    output wire        ID_allowin
    );


wire       ID_ready_go;
// ID一级的缓存寄存器
reg        ID_valid;
reg [31:0] ID_pc;
reg [31:0] ID_inst;


// 译码相关的数据信号
wire [11:0] alu_op;
//wire        load_op;
wire        src1_is_pc;
wire        src2_is_imm;
wire        alu_res_need_bypass; // EXE阶段生成的alu_result需要旁路
wire        res_from_mem;
wire        dst_is_r1;
wire        gr_we;
wire        mem_rd;
wire        mem_we;
wire        src_reg_is_rd;
wire [4: 0] dest;
wire [31:0] rj_value;
wire [31:0] rkd_value;
wire [31:0] imm;
wire [31:0] br_offs;
wire [31:0] jirl_offs;

wire        read_rj; // 需要从GR[rj]读数据
wire        read_rk; // 需要从GR[rk]读数据
wire        read_rd; // 需要从GR[rd]读数据

wire [ 5:0] op_31_26;
wire [ 3:0] op_25_22;
wire [ 1:0] op_21_20;
wire [ 4:0] op_19_15;
wire [ 4:0] rd;
wire [ 4:0] rj;
wire [ 4:0] rk;
wire [11:0] i12;
wire [19:0] i20;
wire [15:0] i16;
wire [25:0] i26;
wire [63:0] op_31_26_d;
wire [15:0] op_25_22_d;
wire [ 3:0] op_21_20_d;
wire [31:0] op_19_15_d;
// 计算类指令(在EXE阶段计算)
wire        inst_add_w;   // add.w rd, rj, rk
// GR[rd] = GR[rj] + GR[rk]
wire        inst_sub_w;   // sub.w rd, rj, rk
// GR[rd] = GR[rj] - GR[rk]
wire        inst_addi_w;  // addi.w rd, rj, si12
// GR[rd] = GR[rj] + sext32(si12)
wire        inst_slt;     // slt rd, rj, rk
// GR[rd] = GR[rj] <signed GR[rk]
wire        inst_sltu;    // sltu rd, rj, rk
// GR[rd] = GR[rj] <unsigned GR[rk]

wire        inst_and;     // and rd, rj, rk
// GR[rd] = GR[rj] & GR[rk]
wire        inst_or;      // or rd, rj, rk
// GR[rd] = GR[rj] | GR[rk]
wire        inst_nor;     // nor rd, rj, rk
// GR[rd] = ~(GR[rj] | GR[rk])
wire        inst_xor;     // xor rd, rj, rk
// GR[rd] = GR[rj] ^ GR[rk]

wire        inst_slli_w;  // slli.w rd, rj, ui5
// GR[rd] = GR[rj] << ui5
wire        inst_srli_w;  // srli.w rd, rj, ui5
// GR[rd] = GR[rj] >>logic ui5
wire        inst_srai_w;  // srai.w rd, rj, ui5
// GR[rd] = GR[rj] >>arith ui5

// load
wire        inst_ld_w;    // ld.w rd, rj, si12
// GR[rd] = MEM[GR[rj]+sext32(si12)][31:0]

// store
wire        inst_st_w;    // st.w rd, rj, si12
// MEM[GR[rj]+sext32(si12)][31:0] = GR[rd]

// 无条件间接跳转
wire        inst_jirl;    // jirl rd, rj, offs16 
//GR[rd] = PC+4; PC = GR[rj]+sext32({offs16, 2’b0})

// 无条件相对PC跳转; BrTarget = PC + sext32({off26, 2’b0}
wire        inst_b;       // b offs26 
// PC = BrTarget
wire        inst_bl;      // bl offs26
// GR[1] = PC+4; PC = BrTarget

// 条件分支; TakenTgt = PC + sext32({off16, 2’b0})
wire        inst_beq;     // beq rj, rd, off16
// if (GR[rj]==GR[rd]); PC = TakenTgt
wire        inst_bne;     // bne rj, rd, offs16
// if (GR[rj]!=GR[rd]); PC = TakenTgt

// 立即数装载
wire        inst_lu12i_w; // lu12i rd, si20
// GR[rd] = {si20, 12’b0}


wire        need_ui5;
wire        need_si12;
wire        need_si16;
wire        need_si20;
wire        need_si26;
wire        src2_is_4;


wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        br_taken;
wire [31:0] br_target;  // 忘记声明了！

// 译码信号的赋值
assign op_31_26  = ID_inst[31:26];
assign op_25_22  = ID_inst[25:22];
assign op_21_20  = ID_inst[21:20];
assign op_19_15  = ID_inst[19:15];

assign rd   = ID_inst[ 4: 0];
assign rj   = ID_inst[ 9: 5];
assign rk   = ID_inst[14:10];

// 12位和20位立即数是运算和访存指令使用的，在EXE阶段使用
assign i12  = ID_inst[21:10];
assign i20  = ID_inst[24: 5];
// 16位和26位立即数是分支跳转指令使用的，在ID阶段使用
assign i16  = ID_inst[25:10];
assign i26  = {ID_inst[ 9: 0], ID_inst[25:10]};

decoder_6_64 u_dec0(.in(op_31_26 ), .out(op_31_26_d ));
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
assign inst_lu12i_w= op_31_26_d[6'h05] & ~ID_inst[25];


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

assign read_rj = ~(inst_b | inst_bl | inst_lu12i_w);
assign read_rk = inst_add_w | inst_sub_w | inst_slt | inst_sltu
                | inst_and | inst_or | inst_nor | inst_xor;
assign read_rd = src_reg_is_rd;


assign imm = src2_is_4 ? 32'h4                      :
             need_si20 ? {i20[19:0], 12'b0}         :
/*need_ui5 || need_si12*/{{20{i12[11]}}, i12[11:0]} ;

assign br_offs = need_si26 ? {{ 4{i26[25]}}, i26[25:0], 2'b0} :
                             {{14{i16[15]}}, i16[15:0], 2'b0} ;

assign jirl_offs = {{14{i16[15]}}, i16[15:0], 2'b0};

assign src_reg_is_rd = inst_beq | inst_bne | inst_st_w;

assign src1_is_pc    = inst_jirl | inst_bl;

assign src2_is_imm   = inst_slli_w |
                       inst_srli_w |
                       inst_srai_w |
                       inst_addi_w |
                       inst_ld_w   |
                       inst_st_w   |
                       inst_lu12i_w|
                       inst_jirl   |
                       inst_bl     ;

assign alu_res_need_bypass = ~(inst_ld_w | inst_st_w | inst_b | inst_beq | inst_bne);

assign res_from_mem  = inst_ld_w;
assign dst_is_r1     = inst_bl;
assign gr_we         = ~inst_st_w & ~inst_beq & ~inst_bne & ~inst_b;
assign mem_rd        = inst_ld_w;
assign mem_we        = inst_st_w;
assign dest          = dst_is_r1 ? 5'd1 : rd;


assign rf_raddr1 = rj;
assign rf_raddr2 = src_reg_is_rd ? rd :rk;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we_in ),
    .waddr  (WB_rf_waddr_in),
    .wdata  (WB_rf_wdata_in)
    );
    
// 后三个流水级前递过来的地址和数据、有效信号要马上用，不能用寄存器缓存！！
wire EXE_hit_rj = ID_valid & (rj != 5'b0) & read_rj & (rj == EXE_rf_waddr_in);
wire MEM_hit_rj = ID_valid & (rj != 5'b0) & read_rj & (rj == MEM_rf_waddr_in);
wire WB_hit_rj  = ID_valid & (rj != 5'b0) & read_rj & (rj == WB_rf_waddr_in) ;

wire EXE_hit_rk = ID_valid & (rk != 5'b0) & read_rk & (rk == EXE_rf_waddr_in);
wire MEM_hit_rk = ID_valid & (rk != 5'b0) & read_rk & (rk == MEM_rf_waddr_in);
wire WB_hit_rk  = ID_valid & (rk != 5'b0) & read_rk & (rk == WB_rf_waddr_in) ;

wire EXE_hit_rd = ID_valid & (rd != 5'b0) & read_rd & (rd == EXE_rf_waddr_in);
wire MEM_hit_rd = ID_valid & (rd != 5'b0) & read_rd & (rd == MEM_rf_waddr_in);
wire WB_hit_rd  = ID_valid & (rd != 5'b0) & read_rd & (rd == WB_rf_waddr_in) ;

wire EXE_hit_rkd = src_reg_is_rd? EXE_hit_rd : EXE_hit_rk;
wire MEM_hit_rkd = src_reg_is_rd? MEM_hit_rd : MEM_hit_rk;
wire WB_hit_rkd  = src_reg_is_rd? WB_hit_rd  : WB_hit_rk ;

// 寄存器读数据与前递数据的选择
assign rj_value  = (EXE_need_bypass_in & EXE_hit_rj)? EXE_rf_wdata_in :
                    ((MEM_need_bypass_in & MEM_hit_rj)? MEM_rf_wdata_in :
                     ((rf_we_in & WB_hit_rj)? WB_rf_wdata_in : rf_rdata1));

assign rkd_value = (EXE_need_bypass_in & EXE_hit_rkd)? EXE_rf_wdata_in :
                    ((MEM_need_bypass_in & MEM_hit_rkd)? MEM_rf_wdata_in :
                     (rf_we_in & WB_hit_rkd)? WB_rf_wdata_in : rf_rdata2);

assign rj_eq_rd = (rj_value == rkd_value);
assign br_taken = (   inst_beq  &&  rj_eq_rd
                   || inst_bne  && !rj_eq_rd
                   || inst_jirl
                   || inst_bl
                   || inst_b
                  ) && valid 
                  && ID_valid // 当前指令有效时才跳转
                  && ID_ready_go; // 当前指令不被阻塞时才跳转
assign br_target = (inst_beq || inst_bne || inst_bl || inst_b) ? (ID_pc + br_offs) :      // 相对PC跳转要用ID阶段的PC!
                                                   /*inst_jirl*/ (rj_value + jirl_offs);


// ID输出数据信号的赋值
assign ID_rdata1_out   = rj_value;
assign ID_rdata2_out   = rkd_value;
assign ID_imm_out      = imm;
assign ID_alu_ctrl_out = {src2_is_imm, src1_is_pc}; // EXE阶段需要使用的alu控制信号的包装
assign ID_alu_op_out   = alu_op;
assign ID_mem_rd_out   = mem_rd;
assign ID_mem_we_out   = mem_we;
assign ID_res_from_mem_out = res_from_mem;
assign ID_rf_we_out    = gr_we;
assign ID_rf_waddr_out = dest;
assign ID_pc_out       = ID_pc;
assign br_taken_out    = br_taken;
assign br_target_out   = br_target;
assign alu_res_need_bypass_out = alu_res_need_bypass;

// 发生写后读阻塞的情况
wire rj_read_after_write = EXE_to_ID_stuck_in & EXE_hit_rj;
wire rk_read_after_write = EXE_to_ID_stuck_in & EXE_hit_rk;
wire rd_read_after_write = EXE_to_ID_stuck_in & EXE_hit_rd;

// ID输出控制信号的赋值
assign ID_allowin      = (!ID_valid) || (ID_ready_go && EXE_allowin);
assign ID_ready_go     = !(rj_read_after_write | rk_read_after_write | rd_read_after_write);
assign ID_to_EXE_valid = ID_valid && ID_ready_go;

// ID缓存数据域的赋值
always @(posedge clk)begin
    if(reset)begin
        ID_pc <= 32'b0;
    end
    else if(IF_to_ID_valid && ID_allowin)begin
        ID_pc <= ID_pc_in;
    end
end
always @(posedge clk)begin
    if(reset)begin
        ID_inst <= 32'b0;
    end
    else if(IF_to_ID_valid && ID_allowin)begin
        ID_inst <= ID_inst_in;
    end
end

// ID缓存控制信号valid域的赋值
always @(posedge clk)begin
    if(reset)begin
        ID_valid <= 1'b0;
    end
    else if(br_taken)begin
        ID_valid <= 1'b0; // !!!br_taken有效时，处于IF阶段的指令在下一个时钟周期进入ID时将它的valid置为0
    end
    else if(ID_allowin)begin
        ID_valid <= IF_to_ID_valid;
    end
end

endmodule