BRGTC6 Config Interface
=======================

The BRGTC6 Chip can be configured through the configuration interface, which consists of an array of configuration registers.

Write-type registers can be set to configure the link. They must be set before enabling the link. Write type registers should not be modified after GO is set to 1.

Read type register can be polled to check for link operation status.

================== ====== ======= ================================================================================================== ================================================================================================================== =============
Configuration      Type   Address Description                                                                                        Value                                                                                                              Default Value
================== ====== ======= ================================================================================================== ================================================================================================================== =============
PAT_BYPASS         Write  0x1     Whether to bypass the pattern generator                                                            0 for using the PatternGen/Chk modules, 1 for direct msgs through the link.                                        0
PATTERN_MODE       Write  0x2     Whether to use a fixed or random pattern                                                           0 for using a random pattern, 1 for using the fixed pattern                                                        0
PATTERN_1_UP       Write  0x3     The first fixed pattern to send in the upstream                                                    8-bit value                                                                                                        0b10101010
PATTERN_2_UP       Write  0x4     The second fixed pattern to send in the upstream                                                   8-bit value                                                                                                        0b01010101
PATTERN_1_DOWN     Read   0x5     The first pattern received in the downstream                                                       8-bit value                                                                                                        /
PATTERN_2_DOWN     Read   0x6     The second pattern received in the downstream                                                      8-bit value                                                                                                        /
PATTERN_STATE      Read   0x7     Indicates what state the pattern checker is in                                                     0b00: Idle, the pattern checker has yet to receive a msg                                                           /

                   |                                                                                                                 0b01: Calibrating, the pattern checker has received some messages, but is still trying to match that to a pattern.

                                                                                                                                     0b10: Locked, the pattern checker has identified a pattern and the link is steady.

                                                                                                                                     0b11: Error, the pattern checker discovered an error after the link was steady
PAT_ERROR_COUNT    Read   0x8     Indicates the number of errors the pattern checker had                                             6-bit value: will overflow if there are more than this                                                             /
GO                 Write  0x9     Whether to enable the upstream and start sending msgs                                              0 for idle link, 1 for enabled link                                                                                0
CLK_DIV_FACTOR     Write  0xA     The factor to divide the core clk by in the clk divider                                            12-bit unsigned int (Must be either 1 or a value                                                                   1
CLK_SKEW_FACTOR    Write  0xB     The number of cycles to skew data and clk by. (Only works when div factor > 1)                     12-bit unsigned int (Must be smaller than the value set for CLK_DIV_FACTOR)                                        0
CTC_ERROR_BIT      Read   0xC     The parity bit of the received messages                                                            1-bit (Only reset on a full-chip reset or credit-interface reset)                                                  /
UP_REPAIR_SEL      Write  0xD     Selects which bit of the credit interface should be driven onto the repair lane                    8-bit value (0 = no repair, 1 = CRC, 2: credit, 3 = reset, 4 = clock, 5 = val, 6+ = message bits)                  0
DOWN_REPAIR_SEL    Write  0xE     Selects which bit of the credit interface should use the value from the repair lane                8-bit value (0 = no repair, 1 = CRC, 2: credit, 3 = reset, 4 = clock, 5 = val, 6+ = message bits)                  0
DBG_TICK_COUNT     Read   0xF     Value of the CredRecv tick count for debugging purposes                                            8-bit value                                                                                                        /
DBG_NEXT_CRED_CNT  Read   0x10    Value of the next credit count in CredSend for debugging purposes                                  8-bit value: note that this value will be one clock cycle behind the actual value                                  /
DBG_CRED_RST_DELAY Read   0x11    Value of the reset delay counter for the reset signal generated by CredSend for debugging purposes 2-bit value                                                                                                        /
================== ====== ======= ================================================================================================== ================================================================================================================== =============

|
