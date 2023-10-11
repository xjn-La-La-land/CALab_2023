module mycpu_top(
    input  wire        clk,
    input  wire        resetn,
    // inst sram interface
    output wire        inst_sram_en, // 片选信号
    output wire [ 3:0] inst_sram_we, // 4bit写使能信号
    output wire [31:0] inst_sram_addr,
    output wire [31:0] inst_sram_wdata,
    input  wire [31:0] inst_sram_rdata,
    // data sram interface
    output wire        data_sram_en, // 片选信号
    output wire [ 3:0] data_sram_we, // 4bit写使能信号
    output wire [31:0] data_sram_addr,
    output wire [31:0] data_sram_wdata,
    input  wire [31:0] data_sram_rdata,
    // trace debug interface
    output wire [31:0] debug_wb_pc,
    output wire [ 3:0] debug_wb_rf_we,
    output wire [ 4:0] debug_wb_rf_wnum,
    output wire [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge clk) reset <= ~resetn;

reg         valid;
always @(posedge clk) begin
    if (reset) begin
        valid <= 1'b0;
    end
    else begin
        valid <= 1'b1;
    end
end

// 各级流水之间传递的控制信号
wire in_valid;
wire IF_allowin;
wire IF_to_ID_valid;
wire ID_allowin;
wire ID_to_EXE_valid;
wire EXE_allowin;
wire EXE_to_MEM_valid;
wire MEM_allowin;
wire MEM_to_WB_valid;
wire WB_allowin;
wire WB_to_out_valid;
wire out_allow;

// 各级流水之间传递的数据信号
wire        br_taken;
wire [31:0] br_target;
wire        alu_res_need_bypass;

wire [31:0] IF_to_ID_pc;
wire [31:0] ID_to_EXE_pc;
wire [31:0] EXE_to_MEM_pc;
wire [31:0] MEM_to_WB_pc;
wire [31:0] WB_pc_out;

wire [31:0] IF_to_ID_inst;

wire [ 4:0] ID_to_EXE_rf_waddr;
wire [ 4:0] EXE_to_MEM_rf_waddr;
wire [ 4:0] MEM_to_WB_rf_waddr;
wire [ 4:0] WB_rf_waddr_out;

wire [31:0] EXE_to_MEM_alu_res;
wire [31:0] MEM_to_WB_rf_wdata;
wire [31:0] WB_rf_wdata_out;

wire [31:0] ID_to_EXE_rdata1;
wire [31:0] ID_to_EXE_rdata2;
wire [31:0] ID_to_EXE_imm;
wire [ 1:0] ID_to_EXE_alu_ctrl;
wire [11:0] ID_to_EXE_alu_op;
wire        ID_to_EXE_mem_rd;
wire        ID_to_EXE_mem_we;
wire        ID_to_EXE_res_from_mem;


wire        EXE_bypass_valid;
wire        MEM_bypass_valid;
wire        WB_bypass_valid;

wire        EXE_to_ID_stuck;

wire        EXE_to_MEM_mem_we;
wire        EXE_to_MEM_res_from_mem;

wire        ID_to_EXE_rf_we;
wire        EXE_to_MEM_rf_we;
wire        MEM_to_WB_rf_we;
wire        WB_rf_we_out;


assign in_valid = 1'b1;
assign out_allow = 1'b1;

assign MEM_bypass_valid = MEM_to_WB_rf_we;
assign WB_bypass_valid  = WB_rf_we_out;

IF_stream IF_stream(
    .clk            (clk            ),
    .reset          (reset          ),
    .valid          (valid          ),
    .in_valid       (in_valid       ),
    .ID_allowin     (ID_allowin     ),
    .IF_inst_in     (inst_sram_rdata),
    .br_taken_in    (br_taken       ),
    .br_target_in   (br_target      ),
    .IF_pc_out      (IF_to_ID_pc    ),
    .IF_inst_out    (IF_to_ID_inst  ),
    .inst_sram_en   (inst_sram_en   ),
    .inst_sram_we   (inst_sram_we   ),
    .inst_sram_addr (inst_sram_addr ),
    .inst_sram_wdata(inst_sram_wdata),
    .IF_to_ID_valid (IF_to_ID_valid ),
    .IF_allowin     (IF_allowin     )
);


ID_stream ID_stream(
    .clk                (clk               ),
    .reset              (reset             ),
    .valid              (valid             ),

    .IF_to_ID_valid     (IF_to_ID_valid    ),
    .EXE_allowin        (EXE_allowin       ),

    .ID_pc_in           (IF_to_ID_pc       ),
    .ID_inst_in         (IF_to_ID_inst     ),
    .EXE_rf_waddr_in    (EXE_to_MEM_rf_waddr),
    .MEM_rf_waddr_in    (MEM_to_WB_rf_waddr),
    .WB_rf_waddr_in     (WB_rf_waddr_out   ),
    .EXE_rf_wdata_in    (EXE_to_MEM_alu_res),
    .MEM_rf_wdata_in    (MEM_to_WB_rf_wdata),
    .WB_rf_wdata_in     (WB_rf_wdata_out   ),
    .EXE_need_bypass_in (EXE_bypass_valid  ),
    .MEM_need_bypass_in (MEM_bypass_valid  ),
    .rf_we_in           (WB_bypass_valid   ),
    .EXE_to_ID_stuck_in (EXE_to_ID_stuck   ),

    .ID_pc_out          (ID_to_EXE_pc      ),
    .ID_rdata1_out      (ID_to_EXE_rdata1  ),
    .ID_rdata2_out      (ID_to_EXE_rdata2  ),
    .ID_imm_out         (ID_to_EXE_imm     ),
    .ID_alu_ctrl_out    (ID_to_EXE_alu_ctrl),
    .ID_alu_op_out      (ID_to_EXE_alu_op  ),
    .ID_mem_rd_out      (ID_to_EXE_mem_rd  ),
    .ID_mem_we_out      (ID_to_EXE_mem_we  ),
    .ID_res_from_mem_out(ID_to_EXE_res_from_mem),
    .ID_rf_we_out       (ID_to_EXE_rf_we ),
    .ID_rf_waddr_out    (ID_to_EXE_rf_waddr),
    .br_taken_out       (br_taken          ),
    .br_target_out      (br_target         ),
    .alu_res_need_bypass_out(alu_res_need_bypass),

    .ID_to_EXE_valid    (ID_to_EXE_valid   ),
    .ID_allowin         (ID_allowin        )
);


EXE_stream EXE_stream(
    .clk                (clk               ),
    .reset              (reset             ),
    .valid              (valid             ),

    .ID_to_EXE_valid    (ID_to_EXE_valid   ),
    .MEM_allowin        (MEM_allowin       ),

    .EXE_pc_in          (ID_to_EXE_pc      ),
    .EXE_rdata1_in      (ID_to_EXE_rdata1  ),
    .EXE_rdata2_in      (ID_to_EXE_rdata2  ),
    .EXE_imm_in         (ID_to_EXE_imm     ),
    .EXE_alu_ctrl_in    (ID_to_EXE_alu_ctrl),
    .EXE_alu_op_in      (ID_to_EXE_alu_op  ),
    .alu_res_need_bypass_in (alu_res_need_bypass),
    .EXE_mem_rd_in      (ID_to_EXE_mem_rd  ),
    .EXE_mem_we_in      (ID_to_EXE_mem_we  ),
    .EXE_res_from_mem_in (ID_to_EXE_res_from_mem),
    .EXE_rf_we_in       (ID_to_EXE_rf_we   ),
    .EXE_rf_waddr_in    (ID_to_EXE_rf_waddr),

    .EXE_pc_out         (EXE_to_MEM_pc     ),
    .EXE_alu_res_out    (EXE_to_MEM_alu_res),
    .EXE_res_from_mem_out (EXE_to_MEM_res_from_mem),
    .EXE_rf_we_out      (EXE_to_MEM_rf_we  ),
    .EXE_rf_waddr_out   (EXE_to_MEM_rf_waddr),
    .EXE_need_bypass_out (EXE_bypass_valid ),
    .EXE_to_ID_stuck_out (EXE_to_ID_stuck  ),

    .data_sram_en       (data_sram_en      ),
    .data_sram_we       (data_sram_we      ),
    .data_sram_addr     (data_sram_addr    ),
    .data_sram_wdata    (data_sram_wdata   ),

    .EXE_to_MEM_valid   (EXE_to_MEM_valid  ),
    .EXE_allowin        (EXE_allowin       )
);


MEM_stream MEM_stream(
    .clk                (clk               ),
    .reset              (reset             ),
    .valid              (valid             ),

    .EXE_to_MEM_valid   (EXE_to_MEM_valid  ),
    .WB_allowin         (WB_allowin        ),

    .MEM_pc_in          (EXE_to_MEM_pc     ),
    .MEM_alu_res_in     (EXE_to_MEM_alu_res),
    .MEM_mem_res_in     (data_sram_rdata   ),
    .MEM_res_from_mem_in (EXE_to_MEM_res_from_mem),
    .MEM_rf_we_in       (EXE_to_MEM_rf_we),
    .MEM_rf_waddr_in    (EXE_to_MEM_rf_waddr),

    .MEM_pc_out         (MEM_to_WB_pc      ),
    .MEM_rf_wdata_out   (MEM_to_WB_rf_wdata),
    .MEM_rf_we_out      (MEM_to_WB_rf_we   ),
    .MEM_rf_waddr_out   (MEM_to_WB_rf_waddr),

    .MEM_to_WB_valid    (MEM_to_WB_valid   ),
    .MEM_allowin        (MEM_allowin       )
);


WB_stream WB_stream(
    .clk                (clk               ),
    .reset              (reset             ),
    .valid              (valid             ),

    .MEM_to_WB_valid    (MEM_to_WB_valid   ),
    .out_allow          (out_allow         ),

    .WB_pc_in           (MEM_to_WB_pc      ),
    .WB_rf_wdata_in     (MEM_to_WB_rf_wdata),
    .WB_rf_we_in        (MEM_to_WB_rf_we   ),
    .WB_rf_waddr_in     (MEM_to_WB_rf_waddr),

    .WB_pc_out          (WB_pc_out         ),
    .WB_rf_we_out       (WB_rf_we_out      ),
    .WB_rf_waddr_out    (WB_rf_waddr_out   ),
    .WB_rf_wdata_out    (WB_rf_wdata_out   ),

    .WB_to_out_valid    (WB_to_out_valid   ),
    .WB_allowin         (WB_allowin        )
);

reg debug_wb_rf_we_reg;

// debug info generate
assign debug_wb_pc       = WB_pc_out;
assign debug_wb_rf_we    = {4{WB_rf_we_out}};
assign debug_wb_rf_wnum  = WB_rf_waddr_out;
assign debug_wb_rf_wdata = WB_rf_wdata_out;

endmodule