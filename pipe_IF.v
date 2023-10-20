module pipe_IF(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_allowin,   // ID周期允许数据进入
    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc,

    input wire         br_taken,       // 后面有跳转，当前指令和PC被取代
    
    output wire        to_valid,       // IF数据可以发出
    output wire        to_allowin,     // 允许preIF阶段的数据进入?

    output reg [31:0] PC
); 

    wire ready_go;              // 数据处理完成信号
    reg valid;   
    assign ready_go = valid;    // 此时由于RAM�?定能够在�?周期内完成数据处�?
    assign to_allowin = !valid || ready_go && from_allowin; 
    assign to_valid = valid && ready_go;
   
    always @(posedge clk) begin
        if (reset) begin
            valid <= 1'b0;
        end
        else if(to_allowin) begin // 如果当前阶段允许数据进入，则数据是否有效就取决于上一阶段数据是否可以发出
            valid <= from_valid;
        end
        else if(br_taken) begin // 如果�?要跳转，当前阶段数据不能在下�?周期传到下一个流水线，则�?要将当前的数据给无效化，但当前没有什么用，这个判断一定要放在上一个的后面
            valid <= 1'b0;
        end
    end

    wire data_allowin; // 拉手成功，数据可以进�?
    assign data_allowin = from_valid && to_allowin;

    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'b0;
        end
        else if(data_allowin) begin       // 当数据有效时再传�?
            PC <= from_pc;
        end
    end

endmodule