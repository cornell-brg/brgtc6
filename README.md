# BRGTC6: Source-Synchronous Parallel Chip-to-Chip Link

This repository contains the RTL, FPGA emulation, and RTL test bench for the
BRGTC6 chip-to-chip communication link project from Cornell University's
Computer Systems Laboratory (Barry Lyu, Parker Schless, Vayun Tiwari;
advisor: Christopher Batten).

BRGTC6 explores the balance between performance, latency, and complexity
through a unified, lightweight, parallel link applicable to chip-to-chip,
chiplet, and mesh-on-chip communications. The design is an 8-bit wide,
single-data-rate, source-synchronous interface with credit-based flow
control, built-in self testing, and repair-ability. A 1 mm², 200 MHz test
chip was taped out in TSMC 65nm for validation and evaluation, and achieved
a throughput of 1.6 Gb/s at 200 MT/s in post-silicon testing.

For the full architectural description and post-silicon results, see the
[project report](https://www.csl.cornell.edu/~cbatten/pdfs/lyu-brgtc6-cureport2025.pdf).

## Block Diagram of the C2C V1 Design

<img src="docs/C2C Link V1 Diagram.svg" width="1000">

## Repository layout

```
brgtc6/
├── src/        # RTL sources (SystemVerilog)
├── test/       # Verilator and VCS RTL testbenches (CMake-driven)
├── fpga/       # Altera FPGA emulation projects for upstream/downstream links
├── scripts/    # Helper scripts (e.g. batch test runners)
└── docs/       # Block diagrams and design documentation
```

## Cloning

```bash
git clone https://github.com/cornell-brg/brgtc6.git
```

## Dependencies

- Verilator 5.016
- Synopsys VCS R-2020.12 (optional, for 4-state RTL simulation)
- CMake 3.10 or newer

Ensure the `verilator` and (optionally) `vcs` executables are available on
your `PATH`.

## Running RTL simulation

```bash
cd test
mkdir -p build && cd build
cmake ..
```

### Verilator (2-state)

| Command                          | Description                                                       |
| -------------------------------- | ----------------------------------------------------------------- |
| `make <test-name>-verilator`     | Build a specific test                                             |
| `make check`                     | Build *and* run all tests                                         |
| `make test`                      | Only run the tests                                                |

Run an individual executable as
`./<subdirectory>/<test_name> <plusargs>`. Supported plusargs:

- `+dump-vcd=<name>.vcd` — dump signals to a VCD file
- `+verbose` — print more detail to the console
- `+test-case=<n>` — only run test case `n` from the testbench

### VCS (4-state)

| Command                          | Description                                                       |
| -------------------------------- | ----------------------------------------------------------------- |
| `make <test-name>-vcs-rtl`       | Build a specific RTL test with VCS                                |

Run an individual executable as
`./<subdirectory>/<test_name>-vcs-rtl <plusargs>`. Supported plusargs are
the Verilator set above plus:

- `+dump-saif=<name>.saif` — dump switching activity to a SAIF file
- `+long` — also run test cases that take a long time (skip these in Verilator)

### Notes on integration tests

When running the integration tests, randomized stimulus can cause the
synchronizers in the DUT to go metastable. Neither Verilator nor VCS can
accurately simulate metastability resolution as would happen on silicon, so
X's will be falsely propagated and the test will fail. To prevent this, pass
`-ucli -i ../utils/timing_checks/DualLinkV4-test-no-sync-xprop.ucli` when
executing the V4 integration tests; timing violations will still be
displayed but X's will not propagate through the first-stage flop in the
relevant synchronizers.

A batch-run script that executes `DualLinkV4-test` repeatedly and reports
aggregate results is also provided. From `test/build/`:

```bash
../../scripts/batchrunV4.sh -n <NUM>
```

## Coverage

| Command                          | Description                                                       |
| -------------------------------- | ----------------------------------------------------------------- |
| `make coverage`                  | Generate Verilator coverage for every test in `build/`            |
| `make <test_name>-coverage`      | Generate line/toggle coverage for a specific test                 |

Per-test outputs are put in `build/coverage/<test-name>` as SystemVerilog files
annotated with line and toggle coverage on the left margin.

## FPGA Emulation

The upstream and downstream links are also exercised on FPGA. The
[fpga/](fpga/) directory contains Altera projects for building both sides
of the link.
