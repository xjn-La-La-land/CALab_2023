module comparator_32(
    input wire [31:0] src1,
    input wire [31:0] src2,
    input wire        sign,
    output wire       res
    );

    wire [31:0] adder_a = src1;
    wire [31:0] adder_b = ~src2;
    wire        adder_cin = 1'b1;
    wire [31:0] adder_res;
    wire        adder_cout;

    assign {adder_cout, adder_res} = adder_a + adder_b + adder_cin;

    wire        slt_res;
    wire        sltu_res;

    assign slt_res =  (src1[31] & ~src2[31]) |   // src1<0 && src2>=0
                      ((src1[31] ~^ src2[31]) & adder_res[31]);  // src1,src2同号，且result<0
    assign sltu_res = ~adder_cout;

    assign res = sign? slt_res : sltu_res;  

endmodule
