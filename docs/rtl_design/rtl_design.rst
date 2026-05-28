RTL Design
==========

.. _RTLDesign-SourceDirectoryStructure:

Source Directory Structure
--------------------------

Note that this is mirrored in the ``unit`` and ``integration`` sub-directories of ``test``:

| src/
| ├─ asyncfifo/
| ├─ common/
| ├─ config/
| ├─ crc/
| ├─ credit/
| ├─ pattern/
| ├─ repair/
| ├─ spi/
| ├─ top-full/

``top-full`` contains the top-level Upstream and Downstream modules, with one subdirectory per link revision (``v0`` through ``v4``). ``v4`` is the configuration that was taped out.
