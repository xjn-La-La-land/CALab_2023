`include "define.v"

module pipe_IF(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入

    input  wire        br_taken,       // 后面有跳转，当前指令和PC被取�?
    input  wire [31:0] br_target,      // 跳转地址

    input  wire        ex_WB,           // 异常指令到达WB级，清空流水线
    input  wire        flush_WB,        // ertn指令到达WB级，清空流水线
    input  wire        tlb_flush_WB,    // TLB刷新指令到达WB级，清空流水线
    
    output wire        to_valid,       // IF数据可以发出

    output reg  [31:0] PC,

    input  wire [31:0] ex_entry,        // 异常处理入口地址，或者异常返回地�?

    // from/to指令RAM
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 2:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok,

    // 取指时需要读取的csr寄存器
    input  wire [31:0] csr_crmd_value,
    input  wire [ 9:0] csr_asid_asid,
    input  wire [31:0] csr_dwm0_value,
    input  wire [31:0] csr_dwm1_value,
    // tlb查询结果，from tlb
    input  wire        tlb_found,
    input  wire [ 3:0] tlb_index,
    input  wire [19:0] tlb_ppn,
    input  wire [ 5:0] tlb_ps,
    input  wire [ 1:0] tlb_plv,
    input  wire [ 1:0] tlb_mat,
    input  wire        tlb_d,
    input  wire        tlb_v,

    // 传给tlb的查询信号
    output wire [18:0] tlb_vppn,
    output wire        tlb_va_bit12,
    output wire [ 9:0] tlb_asid,

    // 传给cache的查询信号
    output wire [11:0] vaddr_offset, 

    output wire [13:0] exception_source
    // {TLBR(IF), TLBR(EX), INE, BRK, SYS, ALE, ADEF, PPI(IF), PPI(EX), PME, PIF, PIS, PIL, INT}
); 

localparam WAIT_ADDR_OK = 3'b001;
localparam WAIT_DATA_OK = 3'b010;
localparam WAIT_STUCK_OK = 3'b100;
reg  [2:0] state;  // IF级共�?3种状态：等待addr_OK拉高；等待data_OK拉高；等待ID级阻塞消�?

wire        ready_go;
reg         valid;
wire        data_allowin; // 拉手成功，数据可以进�?


wire [31:0] seq_pc;
wire        ex_en;           // 出现异常处理信号，或者ertn指令

reg         data_ok_cancel;   // 下一个data_ok信号忽略

assign ex_en        = ex_WB || flush_WB || tlb_flush_WB;
assign seq_pc       = PC + 32'h4;


// state
always @(posedge clk) begin
    if(reset) begin
        state <= WAIT_ADDR_OK;
    end
    else if(state == WAIT_ADDR_OK && (inst_sram_addr_ok || (exception_source != 14'b0))) begin // 当前取指请求的addr_ok返回
        state <= WAIT_DATA_OK;
    end
    else if(state == WAIT_DATA_OK && (inst_sram_data_ok || (exception_source != 14'b0))) begin // 当前取指请求的data_ok返回
        if(data_ok_cancel || inst_cancel) begin
            state <= WAIT_ADDR_OK;
        end
        else begin
            state <= WAIT_STUCK_OK;
        end
    end
    else if(state == WAIT_STUCK_OK && from_allowin)begin // ID级可以进�?
        state <= WAIT_ADDR_OK;
    end
end

assign ready_go = (state == WAIT_DATA_OK) && (inst_sram_data_ok || (exception_source != 14'b0)) && !(data_ok_cancel || inst_cancel);
assign data_allowin = ready_go && from_allowin;
assign to_valid = valid && ready_go && ~ex_en;

// valid
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b1;
    end
    else if(data_allowin) begin // 如果当前阶段允许数据进入，则数据是否有效就取决于上一阶段数据是否可以发出
        valid <= 1'b1;
    end
end

// pc
always @(posedge clk) begin
    if (reset) begin
        PC <= 32'h1c000000;
    end
    else if(ex_en) begin
        PC <= ex_entry;
    end
    else if(br_taken) begin
        PC <= br_target;
    end
    else if(data_allowin) begin
        PC <= seq_pc;
    end
end

// data_ok_cancel
always @(posedge clk) begin
    if(reset) begin
        data_ok_cancel <= 1'b0;
    end
    else if((ex_en || br_taken) && ((state == WAIT_ADDR_OK && inst_sram_addr_ok) || (state == WAIT_DATA_OK && ~inst_sram_data_ok))) begin
        data_ok_cancel <= 1'b1;
    end
    else if(inst_sram_data_ok) begin
        data_ok_cancel <= 1'b0;
    end
end

wire inst_cancel;
assign inst_cancel = (ex_en || br_taken) && (state == WAIT_DATA_OK && inst_sram_data_ok);

// 取指级出现的例外信号
wire ex_adef; // 取指地址错例外
wire ex_pif; // 取指操作页无效例外
wire ex_ppi_IF; // 页特权等级不合规例外(取指)
wire ex_tlbr_IF; // TLB 重填例外(取指)


// 虚地址 ----> 物理地址 转换过程
wire [31:0] inst_vaddr = (ex_en) ? ex_entry : PC;
wire [ 1:0] plv = csr_crmd_value[`CSR_CRMD_PLV];
wire        da  = csr_crmd_value[`CSR_CRMD_DA];
wire        pg  = csr_crmd_value[`CSR_CRMD_PG];

assign tlb_vppn = inst_vaddr[31:13];
assign tlb_va_bit12 = inst_vaddr[12];
assign tlb_asid = csr_asid_asid;

// 直接地址翻译
wire [31:0] direct_inst_paddr = inst_vaddr;
wire        direct_inst_paddr_v = ({pg, da} == 2'b01); // valid

// 直接映射窗口地址翻译
wire        dwm0_plv0 = csr_dwm0_value[`CSR_DWM_PLV0];
wire        dwm0_plv3 = csr_dwm0_value[`CSR_DWM_PLV3];
wire [ 2:0] dwm0_pseg = csr_dwm0_value[`CSR_DWM_PSEG];
wire [ 2:0] dwm0_vseg = csr_dwm0_value[`CSR_DWM_VSEG];
wire        dwm1_plv0 = csr_dwm1_value[`CSR_DWM_PLV0];
wire        dwm1_plv3 = csr_dwm1_value[`CSR_DWM_PLV3];
wire [ 2:0] dwm1_pseg = csr_dwm1_value[`CSR_DWM_PSEG];
wire [ 2:0] dwm1_vseg = csr_dwm1_value[`CSR_DWM_VSEG];

wire [31:0] dwm0_inst_paddr = {dwm0_pseg, inst_vaddr[28:0]};
wire [31:0] dwm1_inst_paddr = {dwm1_pseg, inst_vaddr[28:0]};
wire        dwm0_inst_paddr_v = ((plv == 2'b00) && dwm0_plv0 || (plv == 2'b11) && dwm0_plv3) &&
                                (dwm0_vseg == inst_vaddr[31:29]) &&
                                ({pg, da} == 2'b10);
wire        dwm1_inst_paddr_v = ((plv == 2'b00) && dwm1_plv0 || (plv == 2'b11) && dwm1_plv3) &&
                                (dwm1_vseg == inst_vaddr[31:29]) &&
                                ({pg, da} == 2'b10);

// TLB地址翻译
wire [31:0] tlb_inst_paddr = {32{tlb_ps == 6'd12}} & {tlb_ppn, inst_vaddr[11:0]} | {32{tlb_ps == 6'd21}} & {tlb_ppn[19:9], inst_vaddr[20:0]};
wire        tlb_inst_paddr_v = tlb_found && ({pg, da} == 2'b10) && (!dwm0_inst_paddr_v && !dwm1_inst_paddr_v);


wire [31:0] inst_paddr = {32{direct_inst_paddr_v}} & direct_inst_paddr |
                         {32{dwm0_inst_paddr_v}} & dwm0_inst_paddr |
                         {32{dwm1_inst_paddr_v}} & dwm1_inst_paddr |
                         {32{tlb_inst_paddr_v}} & tlb_inst_paddr;

// cache需要的地址低位信号
assign vaddr_offset = inst_vaddr[11:0];

// 取指例外信号赋值
assign ex_adef = (inst_vaddr[1:0] != 2'b00);
assign ex_pif = tlb_inst_paddr_v && (!tlb_v);
assign ex_ppi_IF = tlb_inst_paddr_v && tlb_v && (plv == 2'b11) && (tlb_plv == 2'b00);
assign ex_tlbr_IF = (!direct_inst_paddr_v) && (!dwm0_inst_paddr_v) && (!dwm1_inst_paddr_v) && (!tlb_inst_paddr_v);

// {TLBR(IF), TLBR(EX), INE, BRK, SYS, ALE, ADEF, PPI(IF), PPI(EX), PME, PIF, PIS, PIL, INT}
assign exception_source = {ex_tlbr_IF, 5'b0, ex_adef, ex_ppi_IF, 2'b0, ex_pif, 3'b0};


assign inst_sram_req   = (state == WAIT_ADDR_OK && exception_source == 14'b0);  // 等待valid信号拉高后再开始取指令
assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 3'b10;  // 4bytes
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr  = inst_paddr;
assign inst_sram_wdata = 32'b0;


endmodule