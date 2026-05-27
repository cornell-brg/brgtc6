`ifndef BRGTC6_CONFIG_ADDR_MAP
`define BRGTC6_CONFIG_ADDR_MAP

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
`define CFG_ADDR_CRC_ERROR          `BRGTC6_ADDR_WIDTH'(4'hc)  //  Read 

//-------------------------------+---------------------------+-----------+-
// REPAIR                        |  Addr                     |   Type    |
//-------------------------------+---------------------------+-----------+-
`define CFG_ADDR_UP_RPR_OFFSET      `BRGTC6_ADDR_WIDTH'(4'hd)  //  Write 
`define CFG_ADDR_DN_RPR_OFFSET      `BRGTC6_ADDR_WIDTH'(4'he)  //  Write 

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
`define CFG_DEF_CRC_ERROR           `BRGTC6_CONFIG_WIDTH'(0)

//-------------------------------+-----------------------------------------
// REPAIR                        |  Value
//-------------------------------+-----------------------------------------
`define CFG_DEF_UP_RPR_OFFSET       `BRGTC6_CONFIG_WIDTH'(11)
`define CFG_DEF_DN_RPR_OFFSET       `BRGTC6_CONFIG_WIDTH'(12)

`endif /* BRGTC6_CONFIG_ADDR_MAP */
