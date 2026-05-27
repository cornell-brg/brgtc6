`ifndef BRGTC6_CONFIG_ADDR_MAP_V4
`define BRGTC6_CONFIG_ADDR_MAP_V4

`include "top-full/BRGTC6TopParams.sv"

//=========================================================================
// Configuration Register Address Map
//=========================================================================

//-------------------------------+---------------------------+-----------+-
// Loopback                      |  Addr                     |   Type    |
//-------------------------------+---------------------------+-----------+-
`define CFG_ADDR_LOOPBACK           `BRGTC6_ADDR_WIDTH'(4'h0)  //  Write 

//-------------------------------+---------------------------+-----------+-
// Pattern Gen & Chk             |  Addr                     |   Type    |
//-------------------------------+---------------------------+-----------+-
`define CFG_ADDR_PAT_BYPASS         `BRGTC6_ADDR_WIDTH'(4'h1)  //  Write 
`define CFG_ADDR_PATTERN_MODE       `BRGTC6_ADDR_WIDTH'(4'h2)  //  Write 
`define CFG_ADDR_PATTERN_1_UP       `BRGTC6_ADDR_WIDTH'(4'h3)  //  Write 
`define CFG_ADDR_PATTERN_2_UP       `BRGTC6_ADDR_WIDTH'(4'h4)  //  Write
`define CFG_ADDR_PATTERN_1_DOWN     `BRGTC6_ADDR_WIDTH'(4'h5)  //  Read
`define CFG_ADDR_PATTERN_2_DOWN     `BRGTC6_ADDR_WIDTH'(4'h6)  //  Read

`define CFG_ADDR_PATTERN_STATE      `BRGTC6_ADDR_WIDTH'(4'h7)  //  Read 
`define CFG_ADDR_PAT_ERR_COUNT      `BRGTC6_ADDR_WIDTH'(4'h8)  //  Read 

//-------------------------------+---------------------------+-----------+-
// Credit-Val/Rdy Adapters       |  Addr                     |   Type    |
//-------------------------------+---------------------------+-----------+-
`define CFG_ADDR_GO                 `BRGTC6_ADDR_WIDTH'(4'h9)  //  Write   
`define CFG_ADDR_CLK_DIV_FACTOR     `BRGTC6_ADDR_WIDTH'(4'ha)  //  Write 
`define CFG_ADDR_CLK_DIV_SKEW       `BRGTC6_ADDR_WIDTH'(4'hb)  //  Write 

//-------------------------------+---------------------------+-----------+-
// CRC                           |  Addr                     |   Type    |
//-------------------------------+---------------------------+-----------+-
`define CFG_ADDR_CRC_ERROR_BIT      `BRGTC6_ADDR_WIDTH'(4'hc)  //  Read 

//-------------------------------+---------------------------+-----------+-
// REPAIR                        |  Addr                     |   Type    |
//-------------------------------+---------------------------+-----------+-
`define CFG_ADDR_UP_REPAIR_SEL      `BRGTC6_ADDR_WIDTH'(4'hd)  //  Write 
`define CFG_ADDR_DOWN_REPAIR_SEL    `BRGTC6_ADDR_WIDTH'(4'he)  //  Write 

//-------------------------------+---------------------------+-----------+-
// DEBUG COUNTERS                |  Addr                     |   Type    |
//-------------------------------+---------------------------+-----------+-
`define CFG_ADDR_DBG_TICK_COUNT     `BRGTC6_ADDR_WIDTH'(4'hf)  //  Read
`define CFG_ADDR_DBG_NEXT_CRED_CNT  `BRGTC6_ADDR_WIDTH'(5'h10) //  Read
`define CFG_ADDR_DBG_CRED_RST_DELAY `BRGTC6_ADDR_WIDTH'(5'h11) //  Read


//=========================================================================
// Configuration Register Default Values
//=========================================================================

//-------------------------------+-----------------------------------------
// Loopback                      |  Value  
//-------------------------------+-----------------------------------------
`define CFG_DEF_LOOPBACK            `BRGTC6_CONFIG_WIDTH'(0)

//-------------------------------+-----------------------------------------
// Pattern Gen & Chk             |  Value  
//-------------------------------+-----------------------------------------
`define CFG_DEF_PAT_BYPASS          `BRGTC6_CONFIG_WIDTH'(0)
`define CFG_DEF_PATTERN_MODE        `BRGTC6_CONFIG_WIDTH'(0)
`define CFG_DEF_PATTERN_1           {(`BRGTC6_CONFIG_WIDTH/2){2'b10}}
`define CFG_DEF_PATTERN_2           {(`BRGTC6_CONFIG_WIDTH/2){2'b01}}
`define CFG_DEF_PATTERN_EMPTY       `BRGTC6_CONFIG_WIDTH'(0)

`define CFG_DEF_PATTERN_STATE       `BRGTC6_CONFIG_WIDTH'(0)
`define CFG_DEF_PAT_ERR_COUNT       `BRGTC6_CONFIG_WIDTH'(0)

//-------------------------------+-----------------------------------------
// Credit-Val/Rdy Adapters       |  Value  
//-------------------------------+-----------------------------------------
`define CFG_DEF_GO                  `BRGTC6_CONFIG_WIDTH'(0)
`define CFG_DEF_CLK_DIV_FACTOR      `BRGTC6_CONFIG_WIDTH'(1)
`define CFG_DEF_CLK_DIV_SKEW        `BRGTC6_CONFIG_WIDTH'(0)

//-------------------------------+-----------------------------------------
// CRC                           |  Value
//-------------------------------+-----------------------------------------
`define CFG_DEF_CRC_ERROR_BIT       `BRGTC6_CONFIG_WIDTH'(0)

//-------------------------------+-----------------------------------------
// REPAIR                        |  Value
//-------------------------------+-----------------------------------------
`define CFG_DEF_UP_REPAIR_SEL       `BRGTC6_CONFIG_WIDTH'(0)
`define CFG_DEF_DOWN_REPAIR_SEL     `BRGTC6_CONFIG_WIDTH'(0)

//-------------------------------+-----------------------------------------
// DEBUG COUNTERS                |  Value
//-------------------------------+-----------------------------------------
`define CFG_DEF_DBG_TICK_COUNT      `BRGTC6_CONFIG_WIDTH'(0)
`define CFG_DEF_DBG_NEXT_CRED_CNT   `BRGTC6_CONFIG_WIDTH'(0)
`define CFG_DEF_DBG_CRED_RST_DELAY  `BRGTC6_CONFIG_WIDTH'(0)

`endif /* BRGTC6_CONFIG_ADDR_MAP_V4 */
