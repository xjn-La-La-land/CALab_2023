// 控制寄存器相�?
`define CSR_CRMD 14'h0
`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE 2

`define CSR_PRMD 14'h1
`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE 2

`define CSR_ECFG 14'h4 
`define CSR_ECFG_LIE 12:0

`define CSR_ESTAT 14'h5 
`define CSR_ESTAT_IS10 1:0

`define CSR_ERA 14'h6
`define CSR_ERA_PC 31:0

`define CSR_BADV   14'h7

`define CSR_EENTRY 14'hc
`define CSR_EENTRY_VA 31:12

`define CSR_SAVE0  14'h30
`define CSR_SAVE1  14'h31
`define CSR_SAVE2  14'h32
`define CSR_SAVE3  14'h33
`define CSR_SAVE_DATA 31:0

`define CSR_TID    14'h40
`define CSR_TID_TID 31:0

`define CSR_TCFG   14'h41
`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV 31:2

`define CSR_TVAL   14'h42

`define CSR_TICLR  14'h44

// 异常编码相关
`define EXC_SYS 6'h0b // 系统调用

module csr(
    // 指令访问接口
    input         clk,
    input         reset,

    input  [13:0] csr_num,
    input         csr_we,
    input  [31:0] csr_wmask,
    input  [31:0] csr_wdata,

    input  [7:0]  hw_int_in,  // 硬件外部中断
    input         ipi_int_in, // 核间中断

    input         wb_ex,     // 异常信号
    input  [5:0]  wb_ecode,  // 异常类型�?级代�?
    input  [8:0]  wb_esubcode, // 异常类型二级代码
    input  [31:0] wb_pc,    // 异常指令地址
    input  [31:0] wb_vaddr, // 无效地址

    input         ertn_flush, // 异常返回信号

    input  [31:0] coreid_in, // 核ID

    output [31:0] csr_rvalue,
    output [31:0] ex_entry   // 异常入口地址，�?�往pre_IF阶段
);

// CRMD
reg [1:0] csr_crmd_plv;  // 特权等级
reg csr_crmd_ie;         // 全局中断使能
wire csr_crmd_da;
wire csr_crmd_pg;
wire [1:0] csr_crmd_datf;
wire [1:0] csr_crmd_datm;
wire [31:0] csr_crmd_rvalue; // 用于读取

always @(posedge clk) begin
    if (reset)
        csr_crmd_plv <= 2'b0;
    else if (wb_ex) // 触发例外后处于最高特权等�?
        csr_crmd_plv <= 2'b0;
    else if (ertn_flush) // 保证从异常返回后返回原有特权等级
        csr_crmd_plv <= csr_prmd_pplv;
    else if (csr_we && csr_num==`CSR_CRMD) 
        csr_crmd_plv <= csr_wmask[`CSR_CRMD_PLV] & csr_wdata[`CSR_CRMD_PLV] 
                        | ~csr_wmask[`CSR_CRMD_PLV] & csr_crmd_plv;
end

always @(posedge clk) begin
    if (reset)
        csr_crmd_ie <= 1'b0;
    else if (wb_ex) // 触发例外后关闭中�?
        csr_crmd_ie <= 1'b0;
    else if (ertn_flush) // 保证从异常返回后返回原有中断状�??
        csr_crmd_ie <= csr_prmd_pie;
    else if (csr_we && csr_num==`CSR_CRMD)
        csr_crmd_ie <= csr_wmask[`CSR_CRMD_IE] & csr_wdata[`CSR_CRMD_IE]
                        | ~csr_wmask[`CSR_CRMD_IE] & csr_crmd_ie;
end

    // 未实现相关域的功�?
    assign csr_crmd_da = 1'b1;
    assign csr_crmd_pg = 1'b0;
    assign csr_crmd_datf = 2'b00;
    assign csr_crmd_datm = 2'b00;

    assign csr_crmd_rvalue = {23'b0, csr_crmd_datm, csr_crmd_datf, csr_crmd_pg, csr_crmd_da, csr_crmd_ie, csr_crmd_plv};

    // PRMD
    reg [1:0] csr_prmd_pplv;     // 保存中断前特权等�?
    reg csr_prmd_pie;            // 保存中断前中断使�?
    wire [31:0] csr_prmd_rvalue;

    always @(posedge clk) begin
        // 不需要复位时赋初始�?�，由软件人员保证访问时已赋�?
        if (wb_ex) begin // 异常发生时保�? plv �? ie
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

    // ECFG
    reg  [12:0] csr_ecfg_lie; // �?部中断使能，高位有效
    wire [31:0] csr_ecfg_rvalue;

    always @(posedge clk) begin
        if (reset)
            csr_ecfg_lie <= 13'b0;
        else if (csr_we && csr_num==`CSR_ECFG)
            csr_ecfg_lie <= csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_wdata[`CSR_ECFG_LIE]
                            | ~csr_wmask[`CSR_ECFG_LIE] & 13'h1bff & csr_ecfg_lie;
    end

    assign csr_ecfg_rvalue = {19'b0, csr_ecfg_lie};

    // ESTAT
    reg  [12:0] csr_estat_is;       // 中断状�?�位
    reg  [5:0]  csr_estat_ecode;    // 异常类型�?级代�?
    reg  [8:0]  csr_estat_esubcode; // 异常类型二级代码
    wire [31:0] csr_estat_rvalue;
    always @(posedge clk) begin
        if (reset)
            csr_estat_is[1:0] <= 2'b0;
        else if (csr_we && csr_num==`CSR_ESTAT) // 写两个软件中�?
            csr_estat_is[1:0] <= csr_wmask[`CSR_ESTAT_IS10] & csr_wdata[`CSR_ESTAT_IS10]
                                | ~csr_wmask[`CSR_ESTAT_IS10] & csr_estat_is[1:0]; 
        csr_estat_is[9:2] <= hw_int_in[7:0];    // 写外部硬件中�?
        csr_estat_is[10] <= 1'b0;
        csr_estat_is[11] <= 1'b0;
//        if (csr_tcfg_e[11] && timer_cnt[31:0]==32'b0) // 写时钟中�?
//            csr_estat_is[11] <= 1'b1;
//        else if (csr_we && csr_num==`CSR_TICLR && csr_wmask[`CSR_TICLR_CLR] && csr_wdata[`CSR_TICLR_CLR]) // 清空时钟中断
//            csr_estat_is[11] <= 1'b0;
        csr_estat_is[12] <= ipi_int_in; // 核间中断
    end

    always @(posedge clk) begin
        if (wb_ex) begin
            csr_estat_ecode <= wb_ecode;
            csr_estat_esubcode <= wb_esubcode;
        end
    end

    assign csr_estat_rvalue = {1'b0, csr_estat_esubcode, csr_estat_ecode, 3'b0, csr_estat_is};

    // ERA
    reg  [31:0] csr_era_pc; // 异常返回地址
    wire [31:0] csr_era_rvalue;
    always @(posedge clk) begin
        if (wb_ex) // 异常发生时保存异常指令的 pc
            csr_era_pc <= wb_pc;
        else if (csr_we && csr_num==`CSR_ERA) 
            csr_era_pc <= csr_wmask[`CSR_ERA_PC] & csr_wdata[`CSR_ERA_PC]
                          | ~csr_wmask[`CSR_ERA_PC] & csr_era_pc;
    end
    assign csr_era_rvalue = csr_era_pc;

    // BADV
    reg [31:0] csr_badv_vaddr;      // 无效地址
    wire       wb_ex_addr_err;
    wire [31:0] csr_badv_rvalue;

/*-----------------------------*/
//    assign wb_ex_addr_err = wb_ecode==`ECODE_ADE || wb_ecode==`ECODE_ALE;
//    always @(posedge clk) begin
//        if (wb_ex && wb_ex_addr_err) 
//            csr_badv_vaddr <= (wb_ecode==`ECODE_ADE && wb_esubcode==`ESUBCODE_ADEF) ? wb_pc : wb_vaddr;
//    end

    assign csr_badv_rvalue = 32'b0;
/*-----------------------------*/

    // EENTRY
    reg [19:0] csr_eentry_va; // 异常入口地址�?在页的页�?
    wire [31:0] csr_eentry_rvalue;

    always @(posedge clk) begin
        if (csr_we && csr_num==`CSR_EENTRY) 
            csr_eentry_va <= csr_wmask[`CSR_EENTRY_VA] & csr_wdata[`CSR_EENTRY_VA]
                            | ~csr_wmask[`CSR_EENTRY_VA] & csr_eentry_va;
    end
    assign csr_eentry_rvalue = {csr_eentry_va, 12'b0};

    // SAVE 
    reg [31:0] csr_save0_data; // 保存寄存�?
    reg [31:0] csr_save1_data;
    reg [31:0] csr_save2_data;
    reg [31:0] csr_save3_data;
    always @(posedge clk) begin
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

    /*-------------------------------------*/
    // 下面是定时器中断相关实现，暂时不�?要，下一个实验需要补上！！！！！�?

    // // TID
    // reg [31:0] csr_tid_tid; // 定时器编�?
    // wire [31:0] csr_tid_rvalue;

    // always @(posedge clk) begin
    //     if (reset)
    //         csr_tid_tid <= coreid_in; // 可能是在复位阶段读取当前核的id
    //     else if (csr_we && csr_num==`CSR_TID)
    //         csr_tid_tid <= csr_wmask[`CSR_TID_TID] & csr_wdata[`CSR_TID_TID]
    //                     | ~csr_wmask[`CSR_TID_TID] & csr_tid_tid;
    // end
    // assign csr_tid_rvalue = csr_tid_tid;

    // // TCFG
    // reg csr_tcfg_en;              // 定时器使�?
    // reg csr_tcfg_periodic;        // 定时器循环模式控�?
    // reg [29:0] csr_tcfg_initval;  // 定时器自减数初始值，赋�?�给计时器要低位接两�?0
    // wire [31:0] csr_tcfg_rvalue;

    // always @(posedge clk) begin
    //     if (reset)
    //         csr_tcfg_en <= 1'b0;
    //     else if (csr_we && csr_num==`CSR_TCFG)
    //         csr_tcfg_en <= csr_wmask[`CSR_TCFG_EN] & csr_wdata[`CSR_TCFG_EN]
    //                         | ~csr_wmask[`CSR_TCFG_EN] & csr_tcfg_en;
    //     if (csr_we && csr_num==`CSR_TCFG) begin
    //         csr_tcfg_periodic <= csr_wmask[`CSR_TCFG_PERIOD] & csr_wdata[`CSR_TCFG_PERIOD]
    //                         | ~csr_wmask[`CSR_TCFG_PERIOD] & csr_tcfg_periodic;
    //         csr_tcfg_initval <= csr_wmask[`CSR_TCFG_INITV] & csr_wdata[`CSR_TCFG_INITV]
    //                         | ~csr_wmask[`CSR_TCFG_INITV] & csr_tcfg_initval;
    //     end
    // end
    // assign csr_tcfg_rvalue = {csr_tcfg_initval, csr_tcfg_periodic, csr_tcfg_en};

    // // TVAL
    // wire [31:0] tcfg_next_value;  // 下一个定时器�?
    // wire [31:0] csr_tval;         // 当前定时器�??
    // reg  [31:0] timer_cnt;        // 定时器计数器
    // assign tcfg_next_value = csr_wmask[31:0] & csr_wdata[31:0] | ~csr_wmask[31:0] & csr_tcfg_rvalue;
    // always @(posedge clk) begin
    //     if (reset)
    //         timer_cnt <= 32'hffffffff;
    //     else if (csr_we && csr_num==`CSR_TCFG && tcfg_next_value[`CSR_TCFG_EN]) 
    //         timer_cnt <= {tcfg_next_value[`CSR_TCFG_INITVAL], 2'b0};
    //     else if (csr_tcfg_en && timer_cnt!=32'hffffffff) begin 
    //         if (timer_cnt[31:0]==32'b0 && csr_tcfg_periodic)
    //             timer_cnt <= {csr_tcfg_initval, 2'b0};
    //         else
    //             timer_cnt <= timer_cnt - 1'b1;
    //     end
    // end
    // assign csr_tval = timer_cnt[31:0];

    // // TICLR
    // wire csr_ticlr_clr;
    // assign csr_ticlr_clr = 1'b0;
    /*-------------------------------------*/


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
                      | {32{csr_num == `CSR_SAVE3}} & csr_save3_data;
                    //   | {32{csr_num == `CSR_TID}} & csr_tid_rvalue
                    //   | {32{csr_num == `CSR_TCFG}} & csr_tcfg_rvalue
                    //   | {32{csr_num == `CSR_TVAL}} & csr_tval
                    //   | {32{csr_num == `CSR_TVAL}} & {31'b0, csr_ticlr_clr};
    
    assign ex_entry = ertn_flush ? csr_era_rvalue : csr_eentry_rvalue; // 异常发生时为异常入口地址，异常返回时为异常返回地�?
    endmodule