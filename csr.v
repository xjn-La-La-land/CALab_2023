`include "define.v"

module csr(
    // 指令访问接口
    input         clk,
    input         reset,

    input  [13:0] csr_num,      // 目标CSR寄存器编号
    input         csr_we,       // CSR寄存器写使能
    input  [31:0] csr_wmask,    // 写掩码
    input  [31:0] csr_wdata,    // 写数据

    input  [7:0]  hw_int_in,    // 硬件外部中断
    input         ipi_int_in,   // 核间中断

    input         wb_ex,        // 异常信号
    input  [5:0]  wb_ecode,     // 异常类型一级代码
    input  [8:0]  wb_esubcode,  // 异常类型二级代码
    input  [31:0] wb_pc,        // 异常指令地址
    input  [31:0] wb_vaddr,     // 无效地址

    input         ertn_flush,   // 异常返回信号

    input  [31:0] coreid_in,    // 核ID

    output [31:0] csr_rvalue,   // 读数据
    output [31:0] ex_entry,     // 异常入口地址，送往pre_IF阶段
    output        has_int       // 中断发生信号，送往ID阶段
);



/* ----------------------------------------CSR寄存器声明--------------------------------------------- */



// CRMD
reg  [1:0] csr_crmd_plv;    // 当前特权等级
reg        csr_crmd_ie;     // 全局中断使能
wire       csr_crmd_da;     // 直接地址翻译模式的使能
wire       csr_crmd_pg;     // 映射地址翻译模式的使能
wire [1:0] csr_crmd_datf;   // 直接地址翻译模式时，取指操作的存储访问类型
wire [1:0] csr_crmd_datm;   // 直接地址翻译模式时，load和store操作的存储访问类型
wire [31:0] csr_crmd_rvalue; // 用于读取CRMD


// PRMD
reg [1:0] csr_prmd_pplv;        // 保存中断前特权等级
reg csr_prmd_pie;               // 保存中断前中断使能
wire [31:0] csr_prmd_rvalue;


// ERA
reg  [31:0] csr_era_pc;         // 异常返回地址
wire [31:0] csr_era_rvalue;


// ESTAT
reg  [12:0] csr_estat_is;       // 中断状态位
reg  [5:0]  csr_estat_ecode;    // 异常类型一级代码
reg  [8:0]  csr_estat_esubcode; // 异常类型二级代码
wire [31:0] csr_estat_rvalue;


// ECFG
reg  [12:0] csr_ecfg_lie;       // 局部中断使能，高位有效
wire [31:0] csr_ecfg_rvalue;


// BADV
reg [31:0] csr_badv_vaddr;      // 无效虚地址
wire       wb_ex_addr_err;
wire [31:0] csr_badv_rvalue;


// EENTRY
reg  [19:0] csr_eentry_va;      // 异常入口地址所在页的页号
wire [31:0] csr_eentry_rvalue;


// TID
reg [31:0] csr_tid_tid;         // 定时器编号
wire [31:0] csr_tid_rvalue;


// SAVE 
reg [31:0] csr_save0_data;      // 保存寄存器
reg [31:0] csr_save1_data;
reg [31:0] csr_save2_data;
reg [31:0] csr_save3_data;


// TCFG
reg csr_tcfg_en;              // 定时器使能
reg csr_tcfg_periodic;        // 定时器循环模式控制位
reg [29:0] csr_tcfg_initval;  // 定时器自减数初始值，赋给计时器要低位接2'b0
wire [31:0] csr_tcfg_rvalue;


// TVAL
wire [31:0] tcfg_next_value;  // 下一个定时器值
wire [31:0] csr_tval;         // 当前定时器值
wire [31:0] csr_tval_rvalue;
reg  [31:0] timer_cnt;        // 定时器计数器


// TICLR
wire csr_ticlr_clr;
wire [31:0] csr_ticlr_rvalue;


/* ------------------------------------------CSR寄存器赋值--------------------------------------------- */


// CRMD寄存器的赋值
always @(posedge clk) begin // CRMD.PLV
    if (reset)
        csr_crmd_plv <= 2'b0;
    else if (wb_ex) // 触发例外后处于最高特权等级
        csr_crmd_plv <= 2'b0;
    else if (ertn_flush) // 保证从异常返回后返回原有特权等级
        csr_crmd_plv <= csr_prmd_pplv;
    else if (csr_we && csr_num ==`CSR_CRMD) 
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wdata[`CSR_CRMD_PLV] 
                        | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
end

always @(posedge clk) begin // CRMD.IE
    if (reset)
        csr_crmd_ie <= 1'b0;
    else if (wb_ex) // 触发例外后关闭中断
        csr_crmd_ie <= 1'b0;
    else if (ertn_flush) // 保证从异常返回后返回原有中断状态
        csr_crmd_ie <= csr_prmd_pie;
    else if (csr_we && csr_num==`CSR_CRMD)
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wdata[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
end

// 未实现的CRMD相关域的功能
assign csr_crmd_da = 1'b1;
assign csr_crmd_pg = 1'b0;
assign csr_crmd_datf = 2'b00;
assign csr_crmd_datm = 2'b00;

assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

// PRMD寄存器的赋值
always @(posedge clk) begin // PRMD.PPLV, PRMD.PIE
    // 不需要复位时赋初始值，由软件人员保证访问时已赋值
    if (wb_ex) begin // 异常发生时保存 plv 和 ie
        csr_prmd_pplv <= csr_crmd_plv;
        csr_prmd_pie <= csr_crmd_ie;
    end
    else if (csr_we && csr_num==`CSR_PRMD) begin
        csr_prmd_pplv <= csr_wmask[`CSR_PRMD_PPLV] & csr_wdata[`CSR_PRMD_PPLV]
                        | ~csr_wmask[`CSR_PRMD_PPLV] & csr_prmd_pplv;
        csr_prmd_pie <= csr_wmask[`CSR_PRMD_PIE] & csr_wdata[`CSR_PRMD_PIE]
                        | ~csr_wmask[`CSR_PRMD_PIE] & csr_prmd_pie;
    end
end

assign csr_prmd_rvalue = {29'b0, csr_prmd_pie, csr_prmd_pplv};


// ECFG寄存器的赋值
always @(posedge clk) begin // ECFG.LIE
    if (reset)
        csr_ecfg_lie <= 13'b0;
    else if (csr_we && csr_num==`CSR_ECFG) // 只能对LIE的 1..0 位、9..2 位、11 位、12 位写入，LIE[10]性能计数器溢出中断不支持
        csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wdata[`CSR_ECFG_LIE]
                        | ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
end

assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};


// ESTAT寄存器的赋值
always @(posedge clk) begin // ESTAT.IS
    if (reset)
        csr_estat_is[1:0] <= 2'b0;
    else if (csr_we && csr_num==`CSR_ESTAT) // 写两个软件中断
        csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wdata[`CSR_ESTAT_IS10]
                            | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0]; 
    csr_estat_is[9:2] <= hw_int_in[7:0];    // 写外部硬件中断
    csr_estat_is[10] <= 1'b0;
    if (timer_cnt[31:0] == 32'b0) // 写时钟中断
        csr_estat_is[11] <= 1'b1;
    else if (csr_we && csr_num == `CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wdata[`CSR_TICLR_CLR]) // 清空时钟中断
        csr_estat_is[11] <= 1'b0;
    csr_estat_is[12] <= ipi_int_in; // 核间中断
end


always @(posedge clk) begin // ESTAT.Ecode, ESTAT.EsubCode
    if (wb_ex) begin
        csr_estat_ecode <= wb_ecode;
        csr_estat_esubcode <= wb_esubcode;
    end
end

assign csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};


// ERA寄存器的赋值
always @(posedge clk) begin // ERA.PC
    if (wb_ex) // 异常发生时保存异常指令的 pc
        csr_era_pc <= wb_pc;
    else if (csr_we && csr_num==`CSR_ERA) 
        csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wdata[`CSR_ERA_PC]
                        | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
end
assign csr_era_rvalue = csr_era_pc;


// BADV寄存器的赋值
assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE; // 出现地址错误相关例外
always @(posedge clk) begin // BADV.VAddr
    if (wb_ex && wb_ex_addr_err) 
        csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
end
assign csr_badv_rvalue = csr_badv_vaddr;


// EENTRY寄存器的赋值
always @(posedge clk) begin // EENTRY.VA
    if (csr_we && csr_num==`CSR_EENTRY) 
        csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wdata[`CSR_EENTRY_VA]
                        | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
end
assign csr_eentry_rvalue = {csr_eentry_va, 12'b0};


// SAVE0~3寄存器的赋值
always @(posedge clk) begin // SAVE.DATA
    if (csr_we && csr_num==`CSR_SAVE0)
        csr_save0_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wdata[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA]&csr_save0_data;
    if (csr_we && csr_num==`CSR_SAVE1)
        csr_save1_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wdata[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA]&csr_save1_data;
    if (csr_we && csr_num==`CSR_SAVE2)
        csr_save2_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wdata[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA]&csr_save2_data;
    if (csr_we && csr_num==`CSR_SAVE3)
        csr_save3_data <= csr_wmask[`CSR_SAVE_DATA]&csr_wdata[`CSR_SAVE_DATA]
                        | ~csr_wmask[`CSR_SAVE_DATA]&csr_save3_data;
end



// TID寄存器的赋值
always @(posedge clk) begin // TID.TID
    if (reset)
        csr_tid_tid <= coreid_in; // 可能是在复位阶段读取当前核的id
    else if (csr_we && csr_num==`CSR_TID)
        csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wdata[`CSR_TID_TID]
                    | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
end
assign csr_tid_rvalue = csr_tid_tid;


// TCFG寄存器的赋值
always @(posedge clk) begin
    if (reset) // TCFG.EN
        csr_tcfg_en <= 1'b0;
    else if (csr_we && csr_num==`CSR_TCFG)
        csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wdata[`CSR_TCFG_EN]
                        | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
    if (csr_we && csr_num==`CSR_TCFG) begin // TCFG.Periodic, TCFG.InitVal
        csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wdata[`CSR_TCFG_PERIOD]
                        | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
        csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV] & csr_wdata[`CSR_TCFG_INITV]
                        | ~csr_wmask[`CSR_TCFG_INITV] & csr_tcfg_initval;
    end
end
assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

// TVAL寄存器的赋值
assign tcfg_next_value = csr_wmask[31:0] & csr_wdata[31:0] | ~csr_wmask[31:0] & csr_tcfg_rvalue;
always @(posedge clk) begin // 定时器timer_cnt寄存器的赋值
    if (reset)
        timer_cnt <= 32'hffffffff;
    else if (csr_we && csr_num == `CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN]) 
        timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITV], 2'b0};
    else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin 
        if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
            timer_cnt <= {csr_tcfg_initval, 2'b0};
        else
            timer_cnt <= timer_cnt - 1'b1;
    end
end
assign csr_tval = timer_cnt[31:0];
assign csr_tval_rvalue = csr_tval;


// TICLR“寄存器”的赋值
assign csr_ticlr_clr = 1'b0;
assign csr_ticlr_rvalue = {31'b0, csr_ticlr_clr};


// 读出数据
assign csr_rvalue = {32{csr_num == `CSR_CRMD}} & csr_crmd_rvalue
                    | {32{csr_num == `CSR_PRMD}} & csr_prmd_rvalue
                    | {32{csr_num == `CSR_ECFG}} & csr_ecfg_rvalue
                    | {32{csr_num == `CSR_ESTAT}} & csr_estat_rvalue
                    | {32{csr_num == `CSR_ERA}} & csr_era_rvalue
                    | {32{csr_num == `CSR_BADV}} & csr_badv_rvalue
                    | {32{csr_num == `CSR_EENTRY}} & csr_eentry_rvalue
                    | {32{csr_num == `CSR_SAVE0}} & csr_save0_data
                    | {32{csr_num == `CSR_SAVE1}} & csr_save1_data
                    | {32{csr_num == `CSR_SAVE2}} & csr_save2_data
                    | {32{csr_num == `CSR_SAVE3}} & csr_save3_data
                    | {32{csr_num == `CSR_TID}} & csr_tid_rvalue
                    | {32{csr_num == `CSR_TCFG}} & csr_tcfg_rvalue
                    | {32{csr_num == `CSR_TVAL}} & csr_tval_rvalue
                    | {32{csr_num == `CSR_TICLR}} & csr_ticlr_rvalue;

assign ex_entry = ertn_flush ? csr_era_rvalue : csr_eentry_rvalue; // 异常发生时为异常入口地址，异常返回时为异常返回地址
assign has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1); // 中断发生信号赋值

endmodule