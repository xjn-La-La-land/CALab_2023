# 用于 CaLab 的合作仓库
## 实验10记录
1. 除法器导致的EX阶段阻塞可能会导致原有数据前递逻辑出错，需要修正一下。错误！其实完全没有必要，因为除法器导致的阻塞本身就可以使ID阶段停止运行，自然就不会将读错的数据继续前送
2. div aluop在ID阶段的设置与EX阶段的使用不符：
   错误现象：写寄存器值与金标准不同
   发现过程：通过指令波形发现div_wu指令第一次出现时计算出错，之前执行多次div_w指令均正确，考虑可能是无符号除法部分出现错误，因此定位到无符号除法的相关信号定义。
    ID阶段定义：
    assign alu_op[15] = div_w;
    assign alu_op[16] = div_wu;
    assign alu_op[17] = mod_w;
    assign alu_op[18] = mod_wu;
    EX阶段使用：
    assign alu_op[15] = div_w;
    assign alu_op[16] = mod_w;
    assign alu_op[17] = div_wu;
    assign alu_op[18] = mod_wu;
    将ID阶段修改为与EX阶段相符即可
3. div_wu运算一直无法停止：
   错误现象：div_wu指令运行时out_valid信号一直不拉高，也就是运算一直没有结束。
   定位过程：通过指令波形发现，与unsigned_div模块的握手信号valid在运算过程中一直为1，因此考虑是否是因为握手成功没有将valid信号清零，定位到代码中的clear_valid逻辑发现错误。
   ```
   else if(divisor_tvalid && (dividend_tready_signed || div_out_valid_unsigned)) begin
        clear_valid <= 1'b0;
    end
    ```
    应该是
    ```
    else if(divisor_tvalid && (dividend_tready_signed || dividend_tready_unsigned)) begin
        clear_valid <= 1'b0;
    end
    ```
4. div_wu运算一直无法停止
    错误现象：div_wu指令运算一直不结束
    定位过程：考虑与无符号除法器握手是否成功，查看握手信号时发现valid信号在ready信号拉高的前一拍被清零，导致握手一直不成功，之后发现是因为clear_valid信号的判断逻辑出错。判断逻辑如下。
    ```
    else if(divisor_tvalid && (dividend_tready_signed || dividend_tready_unsigned)) begin
        clear_valid <= 1'b0;
    end
    ```
    由于divsor的ready信号的赋值逻辑是每个一个固定的时间就拉高一次，在例化了两个除法器导致两个除法器的ready信号总是在相邻的两个周期内拉高。因此有符号除法器的ready信号每次都提前于无符号除法器将valid信号清零，因此导致无符号除法器始终无法拉手成功。
    修改：
    ```
    else if(divisor_tvalid && (dividend_tready_signed & signed_en || dividend_tready_unsigned & unsigned_en)) begin
            clear_valid <= 1'b0;
        end
    ```