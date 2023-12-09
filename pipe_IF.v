module pipe_IF(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入

    input  wire        br_taken,       // 后面有跳转，当前指令和PC被取�?
    input  wire [31:0] br_target,      // 跳转地址

    input  wire        ex_WB,           // 异常指令到达WB级，清空流水�?
    input  wire        flush_WB,        // ertn指令到达WB级，清空流水�?
    
    output wire        to_valid,       // IF数据可以发出

    output wire        ex_adef,        // 取指地址错例外寄存器
    output reg  [31:0] PC,

    input  wire [31:0] ex_entry,        // 异常处理入口地址，或者异常返回地�?

    // from/to指令RAM
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 1:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok,
    input  wire        inst_sram_data_ok
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

assign ex_en        = ex_WB || flush_WB;
assign seq_pc       = PC + 32'h4;

// {32{ex_en}} & ex_entry |
// {32{ex_en_hold}} & ex_entry_hold |
// {32{br_taken}} & br_taken |
// {32{br_taken_hold}} & br_target_hold |
// {32{seq_taken}} & seq_pc;


// state
always @(posedge clk) begin
    if(reset) begin
        state <= WAIT_ADDR_OK;
    end
    else if(state == WAIT_ADDR_OK && inst_sram_addr_ok) begin // 当前取指请求的addr_ok返回
        state <= WAIT_DATA_OK;
    end
    else if(state == WAIT_DATA_OK && inst_sram_data_ok) begin // 当前取指请求的data_ok返回
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

assign ready_go = (state == WAIT_DATA_OK) && (state == WAIT_DATA_OK && inst_sram_data_ok) && !(data_ok_cancel || inst_cancel);
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

assign ex_adef = (PC[1:0] != 2'b00);

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

assign inst_sram_req   = (state == WAIT_ADDR_OK);  // 等待valid信号拉高后再�?始取�?
assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'b10;  // 4bytes
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr  = (ex_en) ? ex_entry : PC;
assign inst_sram_wdata = 32'b0;


endmodule