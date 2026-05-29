Daughter Boards
===============

Any daughter boards that are designed to be compatible with the Chip Tester board must implement the identical pinout to that seen on the Chip Tester Board, including pins for both voltage channels, grounds, and GPIO connections. The BRGTC6 daughter boards are quite simple, including only the 40-pin connector, 0.1uF decoupling capacitors for both voltage channels placed as close as possible to the chip pins, SMA connectors for the clock signals, as well as dedicated SPI connectors if needed. Note that the BRGTC6 single-chip daughter board does not support the Chip Tester as it is designed for standalone unit testing of the chip as well as link emulation with an FPGA. In addition, the ZIF sockets used for the BRGTC6 tapeout daughter boards are no longer manufactured. Sockets from `Aries Electronics <https://www.arieselec.com/wp-content/uploads/2020/12/10004-pga-zif-test-and-burn-in-socket.pdf>`__ should be used instead for future boards.

.. _DaughterBoards-Links:

Links
-----

-  `Altium Designer Single-Chip Daughter Board Source Files <https://github.com/cornell-brg/brg-test-board>`__
-  `Altium Designer Dual-Chip Daughter Board Source Files <https://github.com/cornell-brg/brg-test-board>`__

|
