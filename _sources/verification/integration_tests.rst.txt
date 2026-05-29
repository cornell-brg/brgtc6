Integration Tests
=================

-  `Standard Integration Tests (DualLinkV4-test.sv) <#IntegrationTests-StandardIntegrationTests(DualLinkV4-test.sv)>`__

   -  `Test Case Types <#IntegrationTests-TestCaseTypes>`__
   -  `LFSR Tests w/ Equal Clock Periods <#IntegrationTests-LFSRTestsw/EqualClockPeriods>`__
   -  `Fixed Pattern Tests w/ Equal Clock Periods <#IntegrationTests-FixedPatternTestsw/EqualClockPeriods>`__
   -  `Channel Message Tests (Pattern Bypass) w/ Equal Clock Periods <#IntegrationTests-ChannelMessageTests(PatternBypass)w/EqualClockPeriods>`__
   -  `Unequal Clock Period Tests <#IntegrationTests-UnequalClockPeriodTests>`__
   -  `CRC Error Generation Tests <#IntegrationTests-CRCErrorGenerationTests>`__
   -  `Repair Tests <#IntegrationTests-RepairTests>`__
   -  `Debug Counter Tests <#IntegrationTests-DebugCounterTests>`__
   -  `Long Tests (Take Too Long with Verilator) <#IntegrationTests-LongTests(TakeTooLongwithVerilator)>`__

-  `Backpressure Integration Tests (DualLinkV4Backpressure-test.sv) <#IntegrationTests-BackpressureIntegrationTests(DualLinkV4Backpressure-test.sv)>`__

   -  `Test Case Types <#IntegrationTests-TestCaseTypes.1>`__
   -  `One-Way Message Tests <#IntegrationTests-One-WayMessageTests>`__
   -  `Two-Way Message Tests <#IntegrationTests-Two-WayMessageTests>`__
   -  `Config Message Tests <#IntegrationTests-ConfigMessageTests>`__

|

**NOTE: This section only goes over the V4 integration test cases with two links talking to each other since they include all the tests earlier versions have and more**

|

.. _IntegrationTests-StandardIntegrationTests(DualLinkV4-test.sv):

Standard Integration Tests (DualLinkV4-test.sv)
-----------------------------------------------

.. _IntegrationTests-TestCaseTypes:

Test Case Types
~~~~~~~~~~~~~~~

-  ``test_standard_pattern_two_way`` **(referred to as TCT1 below)**

-

   -  Configures both links to use the pattern generators and checkers
   -  Configures user-provided DUT values including clock divider factors, clock skew factors, pattern modes and repair selects
   -  Configures testbench element values including injected skew and bit-error enables
   -  Checks all user-provided config values against returned value from configuration interface
   -  Checks pattern state to ensure it is locked at the end of the test
   -  Checks debug counters if appropriate input set
   -  Checks CRC error bit if appropriate input set
   -  Checks received fixed patterns are correct if in fixed-pattern mode
   -  Checks to ensure all messages were successfully sent and received

-  ``test_standard_msg_two_way`` **(referred to as TCT2 below)**

-

   -  Configures both links to bypass the pattern generators and checkers - uses channel messages provided through config instead
   -  Configures user-provided DUT values including clock divider factors, clock skew factors, pattern modes and repair selects
   -  Configures testbench element values including injected skew and bit-error enables
   -  Checks all user-provided config values against returned value from configuration interface
   -  Checks all channel messages sent on the respective sending side are received in order and to completion on the receiving side
   -  Checks to ensure all messages were successfully sent and received

.. _IntegrationTests-LFSRTestsw/EqualClockPeriods:

LFSR Tests w/ Equal Clock Periods
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#. ``lfsr_eq_100_mhz_all_skew_0`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on both chips
   #. No skew

#. ``lfsr_eq_100_mhz_under_deskew_thresh_rand_skew`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on both chips
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed

#. ``lfsr_eq_100_mhz_under_deskew_thresh_alt_skew`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on both chips
   #. Skew that is the value that is just below the threshold when explicit deskewing is needed

#. ``lfsr_eq_100_mhz_at_deskew_thresh`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on both chips
   #. Random skew between 0 and the value that is just at the threshold when explicit deskewing is needed

#. ``lfsr_eq_100_mhz_5x_over_deskew_thresh_rand_skew`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on both chips
   #. Random skew between 0 and 5 times the clock period
   #. Clock divider and deskewing value set manually to simulate configuration with actual chip

#. ``lfsr_eq_100_mhz_5x_over_deskew_thresh_alt_skew`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on both chips
   #. Skew that is 5 times the clock period
   #. Clock divider and deskewing value set manually to simulate configuration with actual chip

#. ``lfsr_highest_freq_under_deskew_thresh`` (TCT1)

   #. Confirm no error count detected from PatternChk with 167 MHz (highest supported frequency) clock on both chips
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed

#. ``lfsr_rand_freq_under_deskew_thresh`` (TCT1)

   #. Confirm no error count detected from PatternChk with random clock frequency that is equal on both chips
   #. Skew that is the value that is just below the threshold when explicit deskewing is needed

.. _IntegrationTests-FixedPatternTestsw/EqualClockPeriods:

Fixed Pattern Tests w/ Equal Clock Periods
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#. ``fixed_eq_rand_freq_under_deskew_thresh`` (TCT1)

   #. Confirm no error count detected from PatternChk with random clock frequency that is equal on both chips
   #. Skew that is the value that is just below the threshold when explicit deskewing is needed

.. _IntegrationTests-ChannelMessageTests(PatternBypass)w/EqualClockPeriods:

Channel Message Tests (Pattern Bypass) w/ Equal Clock Periods
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#. ``single_msg_eq_rand_freq_under_deskew_thresh`` (TCT2)

   #. Confirm single input message on one side equals single output message on the other side with random clock frequency that is equal on both chips
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed

#. ``rand_msgs_eq_rand_freq_under_deskew_thresh`` (TCT2)

   #. Confirm all (random number of) input messages on one side equal all output messages on the other side with random clock frequency that is equal on both chips
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed

.. _IntegrationTests-UnequalClockPeriodTests:

Unequal Clock Period Tests
~~~~~~~~~~~~~~~~~~~~~~~~~~

#. ``lfsr_100_50_mhz_under_deskew_thresh`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on one chip and 50 MHz clock on other chip
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed

#. ``lfsr_100_25_mhz_under_deskew_thresh`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on one chip and 25 MHz clock on other chip
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed

#. ``lfsr_uneq_rand_mhz_under_deskew_thresh`` (TCT1)

   #. Confirm no error count detected from PatternChk with both chips have unequal random clock frequencies
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed

.. _IntegrationTests-CRCErrorGenerationTests:

CRC Error Generation Tests
~~~~~~~~~~~~~~~~~~~~~~~~~~

#. ``lfsr_100_25_mhz_under_deskew_thresh_error_1`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on one chip and 25 MHz clock on other chip
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed
   #. Testbench Errorer unit introduces errors (bits flipped) on 3 of the bits of the credit interface from side 1 to side 2

#. ``fixed_uneq_rand_freq_under_deskew_thresh_error_both`` (TCT1)

   #. Confirm no error count detected from PatternChk with both chips have unequal random clock frequencies
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed
   #. Testbench Errorer unit introduces errors (bits flipped) on an odd number of the bits of the credit interface from side 1 to side 2 and side 2 to side 1

#. ``fixed_uneq_rand_freq_under_deskew_thresh_error_2`` (TCT1)

   #. Confirm no error count detected from PatternChk with both chips have unequal random clock frequencies
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed
   #. Testbench Errorer unit introduces errors (bits flipped) on 3 of the bits of the credit interface from side 2 to side 1

.. _IntegrationTests-RepairTests:

Repair Tests
~~~~~~~~~~~~

#. ``lfsr_100_25_mhz_under_deskew_thresh_repair_msg_bit`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on one chip and 25 MHz clock on other chip
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed
   #. Testbench Errorer unit introduces error (bit flipped) on MSB of the message bits of the credit interface from side 1 to side 2
   #. Repair offset is set on both side 1 and side 2 to bypass this lane through the repair lane

#. ``lfsr_100_25_mhz_under_deskew_thresh_repair_clk_bit`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on one chip and 25 MHz clock on other chip
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed
   #. Testbench Errorer unit introduces error (bit flipped) on clock bit of the credit interface from side 2 to side 1
   #. Repair offset is set on both side 1 and side 2 to bypass this lane through the repair lane

.. _IntegrationTests-DebugCounterTests:

Debug Counter Tests
~~~~~~~~~~~~~~~~~~~

#. ``lfsr_100_25_mhz_under_deskew_thresh_repair_clk_bit`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on one chip and 25 MHz clock on other chip
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed
   #. Testbench Errorer unit introduces error (bit flipped) on clock bit of the credit interface from side 2 to side 1
   #. Repair offset is set on both side 1 and side 2 to bypass this lane through the repair lane
   #. Debug counters are read and compared against expected values

.. _IntegrationTests-LongTests(TakeTooLongwithVerilator):

Long Tests (Take Too Long with Verilator)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#. ``lfsr_eq_100_mhz_100x_over_deskew_thresh_rand_skew`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on both chips
   #. Random skew between 0 and 100 times the clock period
   #. Clock divider and deskewing value set manually to simulate configuration with actual chip

#. ``lfsr_eq_100_mhz_100x_over_deskew_thresh_alt_skew`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on both chips
   #. Skew that is 100 times the clock period
   #. Clock divider and deskewing value set manually to simulate configuration with actual chip

#. ``lfsr_100_25_mhz_100x_over_deskew_thresh_rand_skew`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on one chip and 25 MHz clock on other chip
   #. Random skew between 0 and 100 times the clock period
   #. Clock divider and deskewing value set manually to simulate configuration with actual chip

#. ``lfsr_100_25_mhz_100x_over_deskew_thresh_alt_skew`` (TCT1)

   #. Confirm no error count detected from PatternChk with 100 MHz clock on one chip and 25 MHz clock on other chip
   #. Skew that is 100 times the clock period
   #. Clock divider and deskewing value set manually to simulate configuration with actual chip

#. ``ten_msgs_100_5_mhz_under_deskew_thresh_rand_skew`` (TCT2)

   #. Confirm all (10) input messages on one side equal all output messages on the other side with100 MHz clock on one chip and 5 MHz clock on other chip
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed

#. ``ten_msgs_100_5_mhz_under_deskew_thresh_alt_skew`` (TCT2)

   #. Confirm all (num_msgs = 10) input messages on one side equal all output messages on the other side with100 MHz clock on one chip and 5 MHz clock on other chip
   #. Skew that is the value that is just below the threshold when explicit deskewing is needed

|

.. _IntegrationTests-BackpressureIntegrationTests(DualLinkV4Backpressure-test.sv):

Backpressure Integration Tests (DualLinkV4Backpressure-test.sv)
---------------------------------------------------------------

.. _IntegrationTests-TestCaseTypes.1:

Test Case Types
~~~~~~~~~~~~~~~

-  ``test_send_all_wait_receive_all_one_way`` **(referred to as TCT1 below)**

-

   -  Configures both links to bypass the pattern generators and checkers - uses channel messages provided through config instead
   -  Configures user-provided DUT values including clock divider factors and clock skew factors
   -  Configures testbench element values including injected skew and bit-error enables
   -  Sends all messages *on one send side* with random delays between each message (other send side is idle)
   -  Waits a random, long amount of time before receiving messages
   -  Receives and checks all messages *on corresponding receive side* are received in order and to completion with random delays for sink readiness

-  ``test_send_all_wait_receive_all_two_way`` **(referred to as TCT2 below)**

-

   -  Configures both links to bypass the pattern generators and checkers - uses channel messages provided through config instead
   -  Configures user-provided DUT values including clock divider factors and clock skew factors
   -  Configures testbench element values including injected skew and bit-error enables
   -  Sends all messages *on respective send sides* with random delays between each message
   -  Waits a random, long amount of time before receiving messages
   -  Receives and checks all messages *on respective receive sides* are received in order and to completion with random delays for sink readiness

-  ``test_interlaced_one_way`` **(referred to as TCT3 below)**

-

   -  Configures both links to bypass the pattern generators and checkers - uses channel messages provided through config instead
   -  Configures user-provided DUT values including clock divider factors and clock skew factors
   -  Configures testbench element values including injected skew and bit-error enables
   -  The following two actions happen concurrently *on one pair of send/receive units only*

      -  Sends segments of messages with random delays between each message and then waits for a long time between each segment
      -  Waits a long time between each segment and receives segments of messages with random delays between sink readiness

-  ``test_interlaced_two_way`` **(referred to as TCT4 below)**

-

   -  Configures both links to bypass the pattern generators and checkers - uses channel messages provided through config instead
   -  Configures user-provided DUT values including clock divider factors and clock skew factors
   -  Configures testbench element values including injected skew and bit-error enables
   -  The following two actions happen concurrently *on both pairs of send/receive units*

      -  Sends segments of messages with random delays between each message and then waits for a long time between each segment
      -  Waits a long time between each segment and receives segments of messages with random delays between sink readiness

-  ``test_config_backpressure`` **(referred to as TCT5 below)**

   -  Creates messages that map to various registers in the configuration interface
   -  Confirms the messages that are received have the same address in the correct order (data values may be different for read-only registers)
   -  The following two actions happen *only on one of the links*

      -  Sends segments of messages with random delays between each message and then waits for a long time between each segment
      -  Waits a long time between each segment and receives segments of messages with random delays between sink readiness

.. _IntegrationTests-One-WayMessageTests:

One-Way Message Tests
~~~~~~~~~~~~~~~~~~~~~

#. ``one_way_max_credit_msgs_uneq_rand_freq_under_deskew_thresh`` (TCT1)

   #. Confirm all (num_msgs = maximum credit) input messages on one side equal all output messages on the other side with both chips have unequal random clock frequencies
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed

#. ``one_way_thousand_msgs_uneq_rand_freq_under_deskew_thresh`` (TCT3)

   #. Confirm all (num_msgs = 1000) input messages on one side equal all output messages on the other side with both chips have unequal random clock frequencies
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed
   #. 1 segment of messages containing 1000 messages

#. ``one_way_hundred_msgs_three_segs_uneq_rand_freq_under_deskew_thresh`` (TCT3)

   #. Confirm all (num_msgs = 1000) input messages on one side equal all output messages on the other side with both chips have unequal random clock frequencies
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed
   #. 3 segments of messages containing 100 messages each

.. _IntegrationTests-Two-WayMessageTests:

Two-Way Message Tests
~~~~~~~~~~~~~~~~~~~~~

#. ``two_way_max_credit_msgs_uneq_rand_freq_under_deskew_thresh`` (TCT2)

   #. Confirm all (num_msgs = maximum credit) input messages on one side equal all output messages on the other side with both chips have unequal random clock frequencies
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed

#. ``two_way_thousand_msgs_uneq_rand_freq_under_deskew_thresh`` (TCT4)

   #. Confirm all (num_msgs = 1000) input messages on one side equal all output messages on the other side with both chips have unequal random clock frequencies
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed
   #. 1 segment of messages containing 1000 messages

#. ``two_way_hundred_msgs_three_segs_uneq_rand_freq_under_deskew_thresh`` (TCT4)

   #. Confirm all (num_msgs = 1000) input messages on one side equal all output messages on the other side with both chips have unequal random clock frequencies
   #. Random skew between 0 and the value that is just below the threshold when explicit deskewing is needed
   #. 3 segments of messages containing 100 messages each

.. _IntegrationTests-ConfigMessageTests:

Config Message Tests
~~~~~~~~~~~~~~~~~~~~

#. ``config_thousand_msgs_uneq_rand_freq_under_deskew_thresh`` (TCT5)

   #. Confirm all (num_msgs = 1000) input config message addresses equal the response config message addresses from the same link with random clock frequency
   #. 1 segment of messages containing 1000 messages

#. ``config_hundred_msgs_three_segs_uneq_rand_freq_under_deskew_thresh`` (TCT5)

   #. Confirm all (num_msgs = 1000) input config message addresses equal the response config message addresses from the same link with random clock frequency
   #. 3 segments of messages containing 100 messages

|

|
