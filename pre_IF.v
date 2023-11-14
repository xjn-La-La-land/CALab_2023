module pre_IF(
    input  wire        clk,
    input  wire        reset, 

    input  wire        br_taken,            // 跳转信号
    input  wire [31:0] br_target,           // 跳转地址

    input  wire        from_allowin,        // IF周期允许数据进入

    input  wire        ex_en,               // 出现异常处理信号，或者ertn指令
    input  wire [31:0] ex_entry,            // 异常处理入口地址，或者异常返回地址
    
    output wire        to_valid,
    output wire [31:0] nextpc,              // 在下一个时钟周期，pre_IF和IF的PC都会更新为next_pc

    // from/to指令RAM
    output wire        inst_sram_req,
    output wire        inst_sram_wr,
    output wire [ 1:0] inst_sram_size,
    output wire [ 3:0] inst_sram_wstrb,
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire        inst_sram_addr_ok
);

wire        ready_go;
wire        data_allowin;
reg         inst_sram_addr_ok_reg;
reg         inst_sram_req_reg;

assign ready_go     = inst_sram_addr_ok || inst_sram_addr_ok_reg;
assign to_valid     = ready_go;
assign data_allowin = ready_go && from_allowin;

reg  [31:0] PC;
wire [31:0] seq_pc; // pc+4

reg         br_taken_hold;
reg  [31:0] br_target_hold; // 保持跳转目标

reg         ex_en_hold;
reg  [31:0] ex_entry_hold;

wire        seq_taken = ~(ex_en | ex_en_hold | br_taken | br_taken_hold);

assign seq_pc       = PC + 32'h4;
assign nextpc       = {32{ex_en}} & ex_entry |
                      {32{ex_en_hold}} & ex_entry_hold |
                      {32{br_taken}} & br_target |
                      {32{br_taken_hold}} & br_target_hold |
                      {32{seq_taken}} & seq_pc;

always @(posedge clk) begin
    if (reset) begin
        PC <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
    end
    else if(data_allowin) begin // 当数据有效且IF允许数据进入时再更新PC；当ex_en拉高时，不管后面有没有阻塞，都要更新pc
        PC <= nextpc;
    end
end

always @(posedge clk) begin
    if (reset) begin
        br_target_hold <= 32'b0;
        br_taken_hold <= 1'b0; 
    end
    else if(br_taken && ~ready_go) begin
        br_target_hold <= br_target;
        br_taken_hold <= 1'b1;
    end
    else if(data_allowin) begin
        br_taken_hold <= 1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        ex_entry_hold <= 32'b0;
        ex_en_hold <= 1'b0; 
    end
    else if(ex_en && ~ready_go) begin
        ex_entry_hold <= ex_entry;
        ex_en_hold <= 1'b1;
    end
    else if(data_allowin) begin
        ex_en_hold <= 1'b0;
    end
end


always @(posedge clk) begin
    if(reset) begin
        inst_sram_req_reg <= 1'b1;
    end
    else if(inst_sram_req_reg && inst_sram_addr_ok) begin
        inst_sram_req_reg <= 1'b0;
    end
    else if(from_allowin) begin
        inst_sram_req_reg <= 1'b1;
    end
end

always @(posedge clk) begin
    if(reset) begin
        inst_sram_addr_ok_reg <= 1'b0;
    end
    else if(from_allowin) begin
        inst_sram_addr_ok_reg <= 1'b0;
    end
    else if(inst_sram_addr_ok) begin
        inst_sram_addr_ok_reg <= 1'b1;
    end
end


assign inst_sram_req   = inst_sram_req_reg;
assign inst_sram_wr    = 1'b0;
assign inst_sram_size  = 2'b10;  // 4bytes
assign inst_sram_wstrb = 4'b0;
assign inst_sram_addr  = nextpc;
assign inst_sram_wdata = 32'b0;

endmodule