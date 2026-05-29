Design Verification
===================

.. _DesignVerification-TestCases:

Test Cases
----------

-  For integration tests, see :doc:`integration_tests`
-  For unit tests, see the testbench sources under ``test/unit/`` in the repository

|

.. _DesignVerification-TestDirectoryStructure:

Test Directory Structure
------------------------

| brgtc6/test/
| ├─ build/
| ├─ integration/
| ├─ unit/
| ├─ utils/
| ├─ CMakeLists.txt

.. _DesignVerification-build/:

build/
~~~~~~

-  Contains all build outputs with the same directory structure below including integration, unit, and utils sub-directories
-  Must be manually created by the user with ``mkdir -p build`` while in the ``brgtc6/test`` directory

.. _DesignVerification-integration/:

integration/
~~~~~~~~~~~~

-  Contains all Link-level integration tests for each version including single and double-link variants
-  ``integration/DualLinkV3-test.sv`` - Tests two V3 links communicating with each other
-  ``integration/DualLinkV4-test.sv`` - Tests two V4 links communicating with each other
-  ``integration/DualLinkV4Backpressure-test.sv`` - Tests backpressure handling on main channel and config interfaces for two V4 links when in both one-way and two-way operation
-  ``integration/SingleLinkV1-test.sv`` - Tests one V1 link communicating to itself (upstream is looped-back to downstream on the same link)
-  ``integration/SingleLinkV2-test.sv`` - Tests one V2 link communicating to itself (upstream is looped-back to downstream on the same link)
-  ``integration/SingleLinkV3-test.sv`` - Tests one V3 link communicating to itself (upstream is looped-back to downstream on the same link)

.. _DesignVerification-unit/:

unit/
~~~~~

-  Contains all unit tests for all modules
-  ``unit/<sub-dir>/<module>-test.sv`` - Tests specific characteristics of the module (in the given sub-directory) under test to achieve maximum coverage

.. _DesignVerification-utils/:

utils/
~~~~~~

-  Contains test utilities used by many testbenches in integration and unit
-  ``utils/auto_src_sink/SrcSinkDualClkTB.sv`` - Provides automated src/sink handling so rdy/val interfaces do not need to be controlled manually, specifically for dual clock setups
-  ``utils/auto_src_sink/SrcSinkSingleClkTB.sv`` - Provides automated src/sink handling so rdy/val interfaces do not need to be controlled manually, specifically for single clock setups
-  ``utils/auto_src_sink/TestSink.sv`` - Automated sink module for use with the automated src/sink TB modules
-  ``utils/auto_src_sink/TestSouce.sv`` - Automated source module for use with the automated src/sink TB modules
-  ``utils/auto_src_sink/TwoWaySrcSinkDualClkTB.sv`` - Provides automated src/sink handling with two sources and two sinks (each src/sink pair has its own clock) for use with DualLink tests
-  ``utils/clock/DualClkUtils.sv`` - Clock generation and reset control for dual clock testbenches, able to delay/disable each reset and handle timeout
-  ``utils/clock/SingleClockUtils.sv`` - Clock generation and reset control for single clock cases, able to delay reset and handle timeout
-  ``utils/cred_skewer/CredSkewer.sv`` - Creates skew on individual bits of a given credit interface to test deskewing capabilities of the link, used in V3 integration tests
-  ``utils/cred_skewer/CredSkewerErrorerV4.sv`` - Creates skew and introduces error on individual bits of a given credit interface of a V4 link to test deskewing and CRC detection capabilities of the V4 link, used in V4 integration tests
-  ``utils/cred_skewer/SkewShreg.sv`` - A shift register whose output is from the selected stage which allows for generating a configurable, artificial skew of a single bit, used in the CredSkewer's for skew generation
-  ``utils/manual/ManualCheckDualClkTB.sv`` - Provides test case framework for test benches where rdy/val interfaces are controlled manually, specifically for dual clock setups
-  ``utils/manual/ManualCheckSingleClkTB.sv`` - Provides test case framework for test benches where rdy/val interfaces are controlled manually, specifically for single clock setups
-  ``utils/spi/SpiDriver.sv`` - Acts as the controller equivalent to the BRG SPI minion's peripheral behavior, generates the SCLK signal and sends/receives data in a full-duplex manner on SPI mode 0
-  ``utils/spi/SpiDriverValRdy.sv`` - Controller-side equivalent to the BRG SPI minion adapter, wrapper around the SpiDriver to handle the extra val/rdy bits within the SPI transaction for the DUT, can interface with any standard val/rdy interface to essentially "mask" the fact that an SPI connection is underneath
-  ``utils/spi/SyncFifoNextFull.sv`` - Synchronous FIFO used by the SpiDriverValRdy with an output signal that asserts if the next valid write to it will cause it to be full
-  ``utils/timing_checks/DualLinkV4-test-no-sync-xprop.ucli.sv`` - UCLI script for Synopsys DC that disables X-propagation on DualLinkV4 integration tests' synchronizer inputs since simulation cannot model metastability correctly and will always cause false X-propagation if timing violations fail, the timing violation messages are still displayed for debugging purposes
-  ``utils/vc/*`` - Provides common modules including registers, assertions, and line-tracing utilities for use by other modules
-  ``get_system_time_seed.cpp`` - Simple C++ program to output the system clock for use with random seed generation by the testbenches, linked into Verilator and VCS through the DPI interface
-  ``sim.cpp`` - Verilator C++ main simulation program
-  ``utils/TestUtilsDefs.sv`` - Provides common DEFINE's used across the testing environment

.. _DesignVerification-CMakeLists.txt:

CMakeLists.txt
~~~~~~~~~~~~~~

-  Main CMake generation file for all verification

|

|
