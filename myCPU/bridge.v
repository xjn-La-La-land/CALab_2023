`define INST_ID 4'h0
`define DATA_ID 4'h1
`define EX_ENTRY 32'h1c008000

module sram_to_axi_bridge(
    input  wire        aclk,
    input  wire        areset,

    // inst sram interface
    input wire         inst_sram_req,    // ???RAM???????????
    input wire         inst_sram_wr,     // ?1????????????0??????????(???RAM???0)
    input wire  [ 1:0] inst_sram_size,   // ??????????????0: 1 byte??1: 2 bytes??2: 4 bytes
    input wire  [ 3:0] inst_sram_wstrb,  // ???????????????
    input wire  [31:0] inst_sram_addr,   // ???????????
    input wire  [31:0] inst_sram_wdata,  // ?????????????(???RAM???0)
    output wire        inst_sram_addr_ok,// ??????????????OK??????????????????????????????????
    output wire        inst_sram_data_ok,// ???????????????OK?????????????????????????????
    output wire [31:0] inst_sram_rdata,  // ?????????????
    // data sram interface
    input wire         data_sram_req,
    input wire         data_sram_wr,
    input wire  [ 1:0] data_sram_size,
    input wire  [ 3:0] data_sram_wstrb,
    input wire  [31:0] data_sram_addr,
    input wire  [31:0] data_sram_wdata,
    output wire        data_sram_addr_ok,
    output wire        data_sram_data_ok,
    output wire [31:0] data_sram_rdata,
    // read request inferface
    output wire [3:0]  arid,
    output wire [31:0] araddr,
    output wire [7:0]  arlen,
    output wire [2:0]  arsize,
    output wire [1:0]  arburst,
    output wire [1:0]  arlock,
    output wire [3:0]  arcache,
    output wire [2:0]  arprot,
    output wire        arvalid,
    input  wire        arready,
    // read response interface
    input  wire [3:0]  rid,
    input  wire [31:0] rdata,
    input  wire [1:0]  rresp,
    input  wire        rlast,
    input  wire        rvalid,
    output wire        rready,
    // write request interface
    output wire [3:0]  awid,
    output wire [31:0] awaddr,
    output wire [7:0]  awlen,
    output wire [2:0]  awsize,
    output wire [1:0]  awburst,
    output wire [1:0]  awlock,
    output wire [3:0]  awcache,
    output wire [2:0]  awprot,
    output wire        awvalid,
    input  wire        awready,
    // write data interface
    output wire [3:0]  wid,
    output wire [31:0] wdata,
    output wire [3:0]  wstrb,
    output wire        wlast,
    output wire        wvalid,
    input  wire        wready,
    // write response interface
    input  wire [3:0]  bid,
    input  wire [1:0]  bresp,
    input  wire        bvalid,
    output wire        bready
    
);

//constant
assign arlen    = 0;
assign arburst  = 2'b01;
assign arlock   = 2'b00;
assign arcache  = 4'b0000;
assign arprot   = 3'b000;

assign awid     = 4'b0001;
assign awlen    = 8'b00000000;
assign awburst  = 2'b01;
assign awlock   = 2'b00;
assign awcache  = 4'b0000;
assign awprot   = 3'b000;

assign wid      = 4'b0001;
assign wlast    = 1;

reg         arvalid_r;
reg [3 :0]  arid_r;
reg [2 :0]  arsize_r;
reg [31:0]  araddr_r;

wire read_req;
wire read_from_data;
wire read_block;
wire [3:0]  rreq_id;
wire [2:0]  rreq_size;
wire [31:0] rreq_addr;

assign arvalid = arvalid_r;
assign arid = arid_r;
assign arsize = arsize_r;
assign araddr = (rreq_addr == `EX_ENTRY) ? `EX_ENTRY : araddr_r;
assign read_req = inst_sram_req && !inst_sram_wr || data_sram_req && !data_sram_wr;
assign read_from_data = data_sram_req && !data_sram_wr && arid != `INST_ID;
assign rreq_id = read_from_data ? `DATA_ID : `INST_ID;
assign rreq_size = read_from_data ? data_sram_size : inst_sram_size;
assign rreq_addr = read_from_data ? data_sram_addr : inst_sram_addr;

always @(posedge aclk) begin
    if (areset) begin
        arvalid_r <= 1'b0;
        arid_r    <= 4'b0010;
        arsize_r  <= 3'h0;
        araddr_r  <= 32'h0;
    end else if (!arvalid && read_req && !read_block) begin
        arvalid_r <= 1'b1;
        arid_r    <= rreq_id;
        arsize_r  <= rreq_size;
        araddr_r  <= rreq_addr;
    end else if (arvalid && arready) begin
        arvalid_r <= 1'b0;
        arid_r    <= 4'b0010;
        arsize_r  <= 3'h0;
        araddr_r  <= 32'h0;
    end
end

assign rready = 1'b1;
assign inst_sram_data_ok = rready && rvalid && rid == `INST_ID;
assign data_sram_data_ok = rready && rvalid && rid == `DATA_ID || bready && bvalid;
assign inst_sram_rdata   = (rid == `INST_ID) ? rdata : 32'h0;
assign data_sram_rdata   = (rid == `DATA_ID) ? rdata : 32'h0;


reg         awvalid_r;
reg         wvalid_r;
reg [2 :0]  awsize_r;
reg [31:0]  awaddr_r;
reg [31:0]  wdata_r;
reg [3 :0]  wstrb_r;

wire write_req;
wire data_sram_wreq_shake;
wire data_sram_wresp_shake;

assign awvalid = awvalid_r;
assign awsize = awsize_r;
assign awaddr = awaddr_r;
assign wvalid = wvalid_r;
assign wdata = wdata_r;
assign wstrb = wstrb_r;
assign write_req = data_sram_req && data_sram_wr;

always @(posedge aclk) begin
    if (areset) begin
        awvalid_r <= 1'b0;
        awsize_r  <= 3'h0;
        awaddr_r  <= 32'h0;
    end else if (!awvalid && write_req && !wvalid) begin
        awvalid_r <= 1'b1;
        awsize_r  <= data_sram_size;
        awaddr_r  <= data_sram_addr;
    end else if (awvalid && awready) begin
        awvalid_r <= 1'b0;
        awsize_r  <= 3'h0;
        awaddr_r  <= 32'h0;
    end

    if (areset) begin
        wvalid_r <= 1'b0;
        wdata_r <= 32'b0;
        wstrb_r <= 4'b0;
    end else if (!awvalid && write_req) begin
        wvalid_r <= 1'b1;
        wdata_r <= data_sram_wdata;
        wstrb_r <= data_sram_wstrb;
    end else if (wvalid && wready) begin
        wvalid_r <= 1'b0;
        wdata_r <= 32'b0;
        wstrb_r <= 4'b0;
    end
end

assign inst_sram_addr_ok = (arvalid && arready) && !read_from_data;
assign data_sram_addr_ok = awvalid && awready || arvalid && arready && read_from_data;

assign bready = 1'b1;
assign data_sram_wreq_shake = awvalid && awready;
assign data_sram_wresp_shake = bvalid && bready;

reg [2:0] cnt;
assign read_block = cnt != 3'b0;

always @(posedge aclk) begin
    if (areset) begin
        cnt <= 3'b0;
    end else if (data_sram_wreq_shake && !data_sram_wresp_shake) begin
        cnt <= cnt + 1;
    end else if (!data_sram_wreq_shake && data_sram_wresp_shake) begin
        cnt <= cnt - 1;
    end
end

endmodule