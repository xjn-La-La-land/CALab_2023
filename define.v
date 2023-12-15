/* ----------------------------------------CSR寄存器编号(地址)---------------------------------------- */
`define CSR_CRMD   14'h0
`define CSR_PRMD   14'h1
`define CSR_ECFG   14'h4 
`define CSR_ESTAT  14'h5
`define CSR_ERA    14'h6
`define CSR_BADV   14'h7
`define CSR_EENTRY 14'hc
`define CSR_TLBIDX 14'h10
`define CSR_TLBEHI 14'h11
`define CSR_TLBELO0 14'h12
`define CSR_TLBELO1 14'h13
`define CSR_ASID   14'h18
`define CSR_SAVE0  14'h30
`define CSR_SAVE1  14'h31
`define CSR_SAVE2  14'h32
`define CSR_SAVE3  14'h33
`define CSR_TID    14'h40
`define CSR_TCFG   14'h41
`define CSR_TVAL   14'h42
`define CSR_TICLR  14'h44
`define CSR_TLBRENTRY 14'h88
`define CSR_DWM0   14'h180
`define CSR_DWM1   14'h181

/* ----------------------------------------CSR寄存器的各个域---------------------------------------- */
// CRMD
`define CSR_CRMD_PLV 1:0
`define CSR_CRMD_IE 2
`define CSR_CRMD_DA 3
`define CSR_CRMD_PG 4
`define CSR_CRMD_DATF 6:5
`define CSR_CRMD_DATM 8:7

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

// DWM
`define CSR_DWM_PLV0 0
`define CSR_DWM_PLV3 3
`define CSR_DWM_MAT  5:4
`define CSR_DWM_PSEG 27:25
`define CSR_DWM_VSEG 31:29

// ASID
`define CSR_ASID_ASID 9:0
`define CSR_ASID_ASIDBITS 23:16

// TLBEHI
`define CSR_TLBEHI_VPPN 31:13

// TLBELO
`define CSR_TLBELO_V 0
`define CSR_TLBELO_D 1
`define CSR_TLBELO_PLV 3:2
`define CSR_TLBELO_MAT 5:4
`define CSR_TLBELO_G 6
`define CSR_TLBELO_PPN 27:8

// TLBIDX 
`define CSR_TLBIDX_IDX 3:0  // 如果TLBNUM不是16的话这里要修改
`define CSR_TLBIDX_PS 29:24
`define CSR_TLBIDX_NE 31

// TLBRENTRY
`define CSR_TLBRENTRY_PA 31:6 // TLB重填例外入口的物理地址

/* ----------------------------------------各种异常一级编码---------------------------------------- */
`define ECODE_INT     6'h00 // 中断例外
`define ECODE_PIL     6'h01 // load 操作页无效例外
`define ECODE_PIS     6'h02 // store 操作页无效例外
`define ECODE_PIF     6'h03 // 取指操作页无效例外
`define ECODE_PME     6'h04 // 页修改例外
`define ECODE_PPI     6'h07 // 页特权等级不合规例外
`define ECODE_ADE     6'h08 // 取指地址错例外           
`define ECODE_ALE     6'h09 // 地址非对齐例外
`define ECODE_SYS     6'h0b // 系统调用例外
`define ECODE_BRK     6'h0c // 断点例外
`define ECODE_INE     6'h0d // 指令不存在例外
`define ECODE_TLBR    6'h3f // TLB重填例外

/* ----------------------------------------各种异常二级编码---------------------------------------- */
`define ESUBCODE_ADEF 8'h0  // 取指地址错例外
`define ESUBCODE_ADEM 8'h1  // 访存地址错例外
