module pipe_WB(
    input  wire        clk,
    input  wire        reset, 

    input  wire        from_valid,     // preIF数据可以发出

    input  wire [31:0] from_pc, 

    output wire        to_allowin,     // 允许preIF阶段的数据进�?
    output wire        to_valid, 

    input  wire        rf_we_MEM,
    input  wire [ 4:0] rf_waddr_MEM,
    input  wire [31:0] rf_wdata_MEM,   // 之后要写进寄存器的结果是否来自�?

    input  wire [13:0] csr_num_MEM,
    input  wire        csr_en_MEM,
    input  wire        csr_we_MEM,
    input  wire [31:0] csr_wmask_MEM,
    input  wire [31:0] csr_wdata_MEM,

    input  wire        eret_flush_MEM,  
       
    input  wire [31:0] csr_rvalue,

    input  wire        wb_ex_MEM,     // 异常信号
    input  wire [5:0]  wb_ecode_MEM,  // 异常类型�?级代�?
    input  wire [8:0]  wb_esubcode_MEM, // 异常类型二级代码

    output reg          rf_we,          // 用于读写对比
    output reg   [ 4:0] rf_waddr,//!!!!!!!!!!!!!
    output wire  [31:0] rf_wdata,       // 用于MEM阶段计算�??

    output reg [13:0] csr_num,
    output wire       csr_we,
    output reg [31:0] csr_wmask,
    output reg [31:0] csr_wdata,

    output wire       eret_flush,     // 之后要写进寄存器的结果是否来自内�?

    output wire       wb_ex,     // 异常信号
    output reg [5:0]  wb_ecode,  // 异常类型�?级代�?
    output reg [8:0]  wb_esubcode, // 异常类型二级代码
    output reg [31:0] wb_pc,    // 无效指令地址
    output reg [31:0] wb_vaddr, // 无效数据地址

    output reg [31:0]  PC
);
    reg valid;
    assign to_allowin = 1'b1; 
    assign to_valid = valid;
      
    always @(posedge clk) begin
        if (reset) begin
            valid <= 1'b0;
        end
        else if(to_allowin) begin // 如果当前阶段允许数据进入，则数据是否有效就取决于上一阶段数据是否可以发出
            valid <= from_valid;
        end
    end

    wire data_allowin; // 拉手成功，数据可以进�??
    assign data_allowin = from_valid && to_allowin;

    always @(posedge clk) begin
        if (reset) begin
            PC <= 32'b0;
        end
        else if(data_allowin) begin
            PC <= from_pc;
        end
    end

    reg [31:0] rf_wdata1; // 未�?�虑csr读数的情�?
    always @(posedge clk) begin
        if (reset) begin
            rf_waddr <= 5'b0;
            rf_we <= 1'b0;
            rf_wdata1 <= 31'b0;
        end
        else if(data_allowin) begin
            rf_waddr <= rf_waddr_MEM;
            rf_we <= rf_we_MEM;
            rf_wdata1 <= rf_wdata_MEM;
        end
    end

    reg csr_en;
    reg csr_we_WB;
    reg eret_flush_WB;
    always @(posedge clk) begin
        if (reset) begin
            csr_num <= 14'b0;
            csr_en <= 1'b0;
            csr_we_WB <= 1'b0;
            csr_wmask <= 32'b0;
            csr_wdata <= 32'b0;
            eret_flush_WB <= 1'b0;
        end
        else if(data_allowin) begin
            csr_num <= csr_num_MEM;
            csr_en <= csr_en_MEM;
            csr_we_WB <= csr_we_MEM;
            csr_wmask <= csr_wmask_MEM;
            csr_wdata <= csr_wdata_MEM;
            eret_flush_WB <= eret_flush_MEM;
        end
    end
    assign rf_wdata =  csr_en ? csr_rvalue : rf_wdata1;
    assign csr_we = csr_we_WB & valid;
    assign eret_flush = eret_flush_WB & valid;

    reg wb_ex_WB;
    always @(posedge clk) begin
        if (reset) begin
            wb_ex_WB <= 1'b0;
            wb_ecode <= 9'b0;
            wb_esubcode <= 9'b0;
            wb_pc <= 32'b0;
            wb_vaddr <= 32'b0;
        end
        else if(data_allowin) begin
            wb_ex_WB <= wb_ex_MEM;
            wb_ecode <= wb_ecode_MEM;
            wb_esubcode <= wb_esubcode_MEM;
            /*--------------------------------------*/
            // 这两个异常信号并未实现生成和传�?�，这里时钟将其设置为零，需要进行实现！！！
            wb_pc <= 32'b0;
            wb_vaddr <= 32'b0;
            /*--------------------------------------*/
        end
    end
    assign wb_ex = wb_ex_WB & valid;

endmodule