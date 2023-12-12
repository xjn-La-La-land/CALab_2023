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
    output        has_int,       // 中断发生信号，送往ID阶段

    // 额外端口，供tlb指令使用
    input  wire        tlbrd,
    input  wire [18:0] csr_tlbehi_vppn_in,
    input  wire [31:0] csr_tlbelo0_in,
    input  wire [31:0] csr_tlbelo1_in,
    input  wire [31:0] csr_tlbidx_in, 
    input  wire [ 9:0] csr_asid_asid_in,

    output reg  [ 9:0] csr_asid_asid,  
    output reg  [18:0] csr_tlbehi_vppn,  
    output wire [31:0] csr_tlbidx,
    output wire [31:0] csr_tlbelo0,
    output wire [31:0] csr_tlbelo1

);



/* ----------------------------------------CSR寄存器声明--------------------------------------------- */



// CRMD
reg  [1:0] csr_crmd_plv;    // 当前特权等级
reg        csr_crmd_ie;     // 全局中断使能
reg        csr_crmd_da;     // 直接地址翻译模式的使能
reg        csr_crmd_pg;     // 映射地址翻译模式的使能
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

/*------------------TLB相关寄存器-------------------------*/
// 访存可能用到这些寄存器，因此需要提供额外的接口
// DMW
reg         csr_dmw_plv0 [1:0];            // 允许plv0访问
reg         csr_dmw_plv3 [1:0];            // 允许plv3访问
wire [1:0]  csr_dmw_mat  [1:0];      // 访存操作的存储访问类型
reg  [2:0]  csr_dmw_pseg [1:0];      // 直接映射窗口的物理地址的[31:29]位
reg  [2:0]  csr_dmw_vseg [1:0];      // 直接映射窗口的虚拟地址的[31:29]位
wire [31:0] csr_dmw_rvalue [1:0];    

// ASID
// reg [9:0]   csr_asid_asid;           // ASID
wire [7:0]  csr_asid_asidbits;       // ASID 域的位宽。其直接等于这个域的数值
wire [31:0] csr_asid_rvalue;

// TLBEHI
// reg [18:0]  csr_tlbehi_vppn;        
wire [31:0] csr_tlbehi_rvalue;

// TLBELO
reg         csr_tlbelo_v [1:0];        
reg         csr_tlbelo_d [1:0];        
reg  [1:0]  csr_tlbelo_plv [1:0];      
wire [1:0]  csr_tlbelo_mat [1:0];      
reg         csr_tlbelo_g [1:0];       
reg  [19:0] csr_tlbelo_ppn [1:0];      
wire [31:0] csr_tlbelo_rvalue [1:0]; 
wire [31:0] csr_tlbelo_in [1:0]; // for tlbrd

// TLBIDX
reg  [3:0] csr_tlbidx_index;    // 如果TLBNUM不是16的话这里要修改
reg  [5:0] csr_tlbidx_ps;       // 页大小
reg        csr_tlbidx_ne;       // 有效位
wire [31:0] csr_tlbidx_rvalue;

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

always @(posedge clk) begin // CRMD.DA, CRMD.PG
    if (reset) begin
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
    end
    else if(wb_ex && wb_ecode==`ECODE_TLBR) begin // 触发 TLB 重填例外，da赋值为1，pg为0。
        csr_crmd_da <= 1'b1;
        csr_crmd_pg <= 1'b0;
    end
    else if(ertn_flush && csr_estat_ecode==`ECODE_TLBR) begin // 从TLB例外处理程序返回时，da赋值为0，pg为1
        csr_crmd_da <= 1'b0;
        csr_crmd_pg <= 1'b1;
    end
    else if (csr_we && csr_num==`CSR_CRMD) begin
        csr_crmd_da <= csr_wmask[`CSR_CRMD_DA] & csr_wdata[`CSR_CRMD_DA]
                        | ~csr_wmask[`CSR_CRMD_DA] & csr_crmd_da;
        csr_crmd_pg <= csr_wmask[`CSR_CRMD_PG] & csr_wdata[`CSR_CRMD_PG]
                        | ~csr_wmask[`CSR_CRMD_PG] & csr_crmd_pg;
    end
end

// 未实现的CRMD相关域的功能
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

// DMW寄存器的赋值
genvar i;
generate for (i = 0; i < 2; i = i + 1) begin: gen_dmw_and_tlblo
    // DMW
    always @(posedge clk) begin // DMW.Plv0, DMW.Plv3
        if (reset) begin
            csr_dmw_plv0[i] <= 1'b0;
            csr_dmw_plv3[i] <= 1'b0;
        end
        else if (csr_we && csr_num==`CSR_DWM0+i) begin
            csr_dmw_plv0[i] <= csr_wmask[`CSR_DWM_PLV0] & csr_wdata[`CSR_DWM_PLV0]
                            | ~csr_wmask[`CSR_DWM_PLV0] & csr_dmw_plv0[i];
            csr_dmw_plv3[i] <= csr_wmask[`CSR_DWM_PLV3] & csr_wdata[`CSR_DWM_PLV3]
                            | ~csr_wmask[`CSR_DWM_PLV3] & csr_dmw_plv3[i];
        end
    end

    always @(posedge clk) begin // DMW.Pseg DMW.Vseg
        if (reset) begin
            csr_dmw_pseg[i] <= 3'b0;
            csr_dmw_vseg[i] <= 3'b0;
        end
        else if (csr_we && csr_num==`CSR_DWM0+i) begin
            csr_dmw_pseg[i] <= csr_wmask[`CSR_DWM_PSEG] & csr_wdata[`CSR_DWM_PSEG]
                            | ~csr_wmask[`CSR_DWM_PSEG] & csr_dmw_pseg[i];
            csr_dmw_vseg[i] <= csr_wmask[`CSR_DWM_VSEG] & csr_wdata[`CSR_DWM_VSEG]
                            | ~csr_wmask[`CSR_DWM_VSEG] & csr_dmw_vseg[i];
        end
    end

    // 未实现 DMW.Mat 域的功能
    assign csr_dmw_mat[i] = 2'b00;
    assign csr_dmw_rvalue[i] = {csr_dmw_vseg[i], 1'b0, csr_dmw_pseg[i], 19'b0, csr_dmw_mat[i], csr_dmw_plv3[i], 2'b0,csr_dmw_plv0[i]};


    // TLBELO
    always @(posedge clk) begin // TLBELO.V, TLBELO.D, TLBELO.PLV, TLBELO.G
        if (reset) begin
            csr_tlbelo_v[i] <= 1'b0;
            csr_tlbelo_d[i] <= 1'b0;
            csr_tlbelo_plv[i] <= 2'b0;
            csr_tlbelo_g[i] <= 1'b0;
        end
        else if (csr_we && csr_num==`CSR_TLBELO0+i) begin
            csr_tlbelo_v[i] <= csr_wmask[`CSR_TLBELO_V] & csr_wdata[`CSR_TLBELO_V]
                            | ~csr_wmask[`CSR_TLBELO_V] & csr_tlbelo_v[i];
            csr_tlbelo_d[i] <= csr_wmask[`CSR_TLBELO_D] & csr_wdata[`CSR_TLBELO_D]
                            | ~csr_wmask[`CSR_TLBELO_D] & csr_tlbelo_d[i];
            csr_tlbelo_plv[i] <= csr_wmask[`CSR_TLBELO_PLV] & csr_wdata[`CSR_TLBELO_PLV]
                            | ~csr_wmask[`CSR_TLBELO_PLV] & csr_tlbelo_plv[i];
            csr_tlbelo_g[i] <= csr_wmask[`CSR_TLBELO_G] & csr_wdata[`CSR_TLBELO_G]
                            | ~csr_wmask[`CSR_TLBELO_G] & csr_tlbelo_g[i];
        end
        else if(tlbrd) begin
            csr_tlbelo_v[i] <= csr_tlbelo_in[i][`CSR_TLBELO_V];
            csr_tlbelo_d[i] <= csr_tlbelo_in[i][`CSR_TLBELO_D];
            csr_tlbelo_plv[i] <= csr_tlbelo_in[i][`CSR_TLBELO_PLV];
            csr_tlbelo_g[i] <= csr_tlbelo_in[i][`CSR_TLBELO_G];
        end

    end

    always @(posedge clk) begin // TLBELO.PPN
        if (reset)
            csr_tlbelo_ppn[i] <= 20'b0;
        else if (csr_we && csr_num==`CSR_TLBELO0+i)
            csr_tlbelo_ppn[i] <= csr_wmask[`CSR_TLBELO_PPN] & csr_wdata[`CSR_TLBELO_PPN]
                            | ~csr_wmask[`CSR_TLBELO_PPN] & csr_tlbelo_ppn[i];
        else if (tlbrd) 
            csr_tlbelo_ppn[i] <= csr_tlbelo_in[i][`CSR_TLBELO_PPN];
    end
    // 未实现 TLBELO.Mat 域的功能
    assign csr_tlbelo_mat[i] = 2'b00;
    assign csr_tlbelo_rvalue[i] = {4'b0, csr_tlbelo_ppn[i], 1'b0, csr_tlbelo_g[i], csr_tlbelo_mat[i], csr_tlbelo_plv[i], csr_tlbelo_d[i], csr_tlbelo_v[i]};

end
endgenerate

// ASID寄存器的赋值
always @(posedge clk) begin // ASID.ASID
    if (reset)
        csr_asid_asid <= 10'b0;
    else if (csr_we && csr_num==`CSR_ASID)
        csr_asid_asid <= csr_wmask[`CSR_ASID_ASID] & csr_wdata[`CSR_ASID_ASID]
                        | ~csr_wmask[`CSR_ASID_ASID] & csr_asid_asid;
    else if (tlbrd) begin
        csr_asid_asid <= csr_asid_asid_in;
    end
end
assign csr_asid_asidbits = 8'ha; // ASID 域的位宽设置为 10 位
assign csr_asid_rvalue = {8'b0, csr_asid_asidbits, 6'b0, csr_asid_asid};

// TLBEHI
always @(posedge clk) begin // TLBEHI.VPPN
    if (reset)
        csr_tlbehi_vppn <= 19'b0;
    else if (csr_we && csr_num==`CSR_TLBEHI)
        csr_tlbehi_vppn <= csr_wmask[`CSR_TLBEHI_VPPN] & csr_wdata[`CSR_TLBEHI_VPPN]
                        | ~csr_wmask[`CSR_TLBEHI_VPPN] & csr_tlbehi_vppn;
    else if (tlbrd) 
        csr_tlbehi_vppn <= csr_tlbehi_vppn_in;
end
assign csr_tlbehi_rvalue = {csr_tlbehi_vppn, 13'b0};

// TLBELO
assign csr_tlbelo_in[0] = csr_tlbelo0_in; // tlbrd输入
assign csr_tlbelo_in[1] = csr_tlbelo1_in;
assign csr_tlbelo0 = csr_tlbelo_rvalue[0]; // tlbrd输出
assign csr_tlbelo1 = csr_tlbelo_rvalue[1];

// TLBIDX
always @(posedge clk) begin // TLBIDX.Index, TLBIDX.PS, TLBIDX.NE
    if (reset) begin
        csr_tlbidx_index <= 4'b0;
        csr_tlbidx_ps <= 6'b0;
        csr_tlbidx_ne <= 1'b0;
    end
    else if (csr_we && csr_num==`CSR_TLBIDX) begin
        csr_tlbidx_index <= csr_wmask[`CSR_TLBIDX_IDX] & csr_wdata[`CSR_TLBIDX_IDX]
                        | ~csr_wmask[`CSR_TLBIDX_IDX] & csr_tlbidx_index;
        csr_tlbidx_ps <= csr_wmask[`CSR_TLBIDX_PS] & csr_wdata[`CSR_TLBIDX_PS]
                        | ~csr_wmask[`CSR_TLBIDX_PS] & csr_tlbidx_ps;
        csr_tlbidx_ne <= csr_wmask[`CSR_TLBIDX_NE] & csr_wdata[`CSR_TLBIDX_NE]
                        | ~csr_wmask[`CSR_TLBIDX_NE] & csr_tlbidx_ne;
    end
    else if (tlbrd) begin
        csr_tlbidx_ps <= csr_tlbidx_in[`CSR_TLBIDX_PS];
        csr_tlbidx_ne <= csr_tlbidx_in[`CSR_TLBIDX_NE];
    end
end
assign csr_tlbidx_rvalue = {csr_tlbidx_ne, 1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};
assign csr_tlbidx = {(csr_estat_ecode!=`ECODE_TLBR) & csr_tlbidx_ne, 
                        1'b0, csr_tlbidx_ps, 20'b0, csr_tlbidx_index};

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
                    | {32{csr_num == `CSR_TICLR}} & csr_ticlr_rvalue
                    | {32{csr_num == `CSR_DWM0}} & csr_dmw_rvalue[0]
                    | {32{csr_num == `CSR_DWM1}} & csr_dmw_rvalue[1]
                    | {32{csr_num == `CSR_ASID}} & csr_asid_rvalue
                    | {32{csr_num == `CSR_TLBEHI}} & csr_tlbehi_rvalue
                    | {32{csr_num == `CSR_TLBELO0}} & csr_tlbelo_rvalue[0]
                    | {32{csr_num == `CSR_TLBELO1}} & csr_tlbelo_rvalue[1]
                    | {32{csr_num == `CSR_TLBIDX}} & csr_tlbidx_rvalue;


assign ex_entry = ertn_flush ? csr_era_rvalue : csr_eentry_rvalue; // 异常发生时为异常入口地址，异常返回时为异常返回地址
assign has_int = ((csr_estat_is[12:0] & csr_ecfg_lie[12:0]) != 13'b0) && (csr_crmd_ie == 1'b1); // 中断发生信号赋值

endmodule