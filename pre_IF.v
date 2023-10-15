module pre_IF(
    input  wire        clk,
    input  wire        reset, 

    input  wire        br_taken,            // 跳转信号
    input  wire [31:0] br_target,           // 跳转地址

    input  wire        from_allowin,       // IF周期允许数据进入
    
    output wire        to_valid,
    output wire [31:0] nextpc
);
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
    assign to_valid = valid;

    reg  [31:0] PC;              // IF级当前PC�?
    wire [31:0] seq_pc;             // 顺序化的PC�?
    assign seq_pc       = PC + 3'h4;
    assign nextpc       = br_taken ? br_target : seq_pc;

    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'h1bfffffc;  //trick: to make nextpc be 0x1c000000 during reset 
        end
        else if(valid && from_allowin) begin // 当数据有效且IF允许数据进入时再修改PC�?
            PC <= nextpc; 
        end
    end    
endmodule