// 控制寄存器相关
`define CSR_CMRD 14'b0
`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE 2

`define CSR_PRMD 14'b1
`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE 2

`define CSR_ECFG   0x4 
`define CSR_ECFG_LIE 12:0

`define CSR_ESTAT  0x5 
`define CSR_ESTAT_IS10 1:0

`define CSR_ERA    0x6
`define CSR_ERA_PC 31:0

`define CSR_BADV   0x7

`define CSR_EENTRY 0xc
`define CSR_EENTRY_VA 31:12

`define CSR_SAVE0  0x30
`define CSR_SAVE1  0x31
`define CSR_SAVE2  0x32
`define CSR_SAVE3  0x33
`define CSR_SAVE_DATA 31:0

`define CSR_TID    0x40
`define CSR_TID_TID 31:0

`define CSR_TCFG   0x41
`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV 31:2

`define CSR_TVAL   0x42

`define CSR_TICLR  0x44

// 异常编码相关
`define EXC_SYS 6'h0b // 系统调用
