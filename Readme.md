## 各类控制信号的作用
1. pipeX_valid: 第X流水级的有效位，表示该流水级在当前周期有有效数据，当要清空流水级时将此信号置为零即可
2. pipeX_allowin: 第X流水级传递给X-1级的信号，表示下一个周期X级可以更新为当前周期X-1级上的数据，为零则不可以接受数据，
3. pipeX_ready_go: 描述当前时钟周期处理任务的完成状态。值为1表示数据在第 X 级的处理任务已经完成，可以传递到第X+1流水级。
4. pipeX_to_pipeY_valid: 第X级传递给第X+1级的信号，表示第X级的数据希望在下一个时钟周期进入到X+1级
总结：
    pipeX_valid：不发出，表示当前流水线的源数据有效
    pipeX_allowin：传给上一级流水线的拉手信号
    pipeX_ready_go：不发出，表示当前流水线的任务完成
    pipeX_to_pipeY_valid：传给下一级流水线的拉手信号
1. 控制信号生成逻辑：  
```
assign pipe2_ready_go = ...
assign pipe2_allowin = !pipe2_valid || pipe2_ready_go && pipe3_allowin;
assign pipe2_to_pipe3_valid = pipe2_valid && pipe2_ready_go;
always @(posedge clk) begin
    if (rst) begin
        pipe2_valid <= 1'b0;
    end else if(pipe2_allowin) begin
        pipe2_valid <= pipe1_to_pipe2_valid;
    end
    if (pipe1_to_pipe2_valid && pipe2_allowin) begin
        pipe2_data <= pipe1_data;
    end
end
```
生成patch文件：git format-patch -1 HEAD

# 将每个流水级分成不同的模块
# 添加完整的握手信号
# 不同类型寄存器分成不同always块

# 添加阻塞功能防止指令冲突以及写后读冲突
1. 阻塞功能：当一个流水级处于阻塞状态时，要同时防止后面数据进来，以及不再向前面传送数据
2. 写后读冲突
    主要在译码阶段进行处理，需要对比当前读寄存器好和当前处于执行、译码、访存阶段的指令的写寄存器号是否相同。
    * 为防止不必要的对比，要判断读寄存器号是否真是寄存器号、是否为零。使用每个流水级存储的写寄存器信息进行对比即可。注意首先用we信号判断一下。
3. 指令冲突
    译码阶段需要判断一下当前指令是不是跳转指令，是的话就需要将后面这个指令取消，即这个指令对应的valid设置为零，取指令阶段也需要设置为零，防止读数据需要多个周期的情况，且将preIF阶段nextpc设置为跳转值。需要考虑ID被写后读阻塞的情况。

各个阶段的任务
1. preIF: 生成pc、将pc传送至下一个流水线，根据跳转信号进行跳转。

2. IF: 接收指令RAM返回的数据，存储到寄存器中，并将存储的PC、inst传给ID，接收跳转信号将自身信号的valid取消
   当有跳转指令，且当前处理的数据不能在下一个周期内传递给ID段进行取消操作时，需要在本流水线上进行取消，

3. 寄存器中存的是当前流水线的源数据，输出到下一个流水线的数据都使用wire类型进行输出

注：
    当前流水线生成的数据output 用wire，接收的数据并且要把它发送到下一个流水线的用reg，接收的数据当前阶段要使用的都要用reg存储一下。

1. 问题1：
   .rf_we_EX(rf_we_EX & EX_valid), // 用于读写对比，EX阶段的数据有效时才能进行对比，！！！！！！！
2. 问题2:
   .we     (rf_we_WB & WB_valid), // 写寄存器数据在WB阶段数据有效时才能写入，如果阻塞的话残留值需要被屏蔽掉
3. 问题3:ID
        .data_sram_we_ID(data_sram_we),？ID
        .data_sram_wdata_ID(data_sram_wdata_ID),
        .data_sram_en_ID(data_sram_en_ID),
4. 问题4: 写后读对比需要将WB阶段也用于对比！！！