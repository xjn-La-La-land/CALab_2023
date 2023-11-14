/* ----------------------------------------CSR寄存器编号(地址)---------------------------------------- */
`define CSR_CRMD   14'h0
`define CSR_PRMD   14'h1
`define CSR_ECFG   14'h4 
`define CSR_ESTAT  14'h5
`define CSR_ERA    14'h6
`define CSR_BADV   14'h7
`define CSR_EENTRY 14'hc
`define CSR_SAVE0  14'h30
`define CSR_SAVE1  14'h31
`define CSR_SAVE2  14'h32
`define CSR_SAVE3  14'h33
`define CSR_TID    14'h40
`define CSR_TCFG   14'h41
`define CSR_TVAL   14'h42
`define CSR_TICLR  14'h44

/* ----------------------------------------CSR寄存器的各个域---------------------------------------- */
// CRMD
`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE 2

// PRMD
`define CSR_PRMD_PPLV 1:0
`define CSR_PRMD_PIE 2

// ECFG
`define CSR_ECFG_LIE 12:0

// ESTAT
`define CSR_ESTAT_IS10 1:0

// ERA
`define CSR_ERA_PC 31:0

// EENTRY
`define CSR_EENTRY_VA 31:12

// SAVE
`define CSR_SAVE_DATA 31:0

// TID
`define CSR_TID_TID 31:0

// TCGF
`define CSR_TCFG_EN 0
`define CSR_TCFG_PERIOD 1
`define CSR_TCFG_INITV 31:2

// TICLR
`define CSR_TICLR_CLR 0


/* ----------------------------------------各种异常一级编码---------------------------------------- */
`define ECODE_INT     6'h00 // 中断例外
`define ECODE_ADE     6'h08 // 取指地址错例外           
`define ECODE_ALE     6'h09 // 地址非对齐例外
`define ECODE_SYS     6'h0b // 系统调用例外
`define ECODE_BRK     6'h0c // 断点例外
`define ECODE_INE     6'h0d // 指令不存在例外

/* ----------------------------------------各种异常二级编码---------------------------------------- */
`define ESUBCODE_ADEF 8'h0  // 取指地址错例外
`define ESUBCODE_ADEM 8'h1  // 访存地址错例外