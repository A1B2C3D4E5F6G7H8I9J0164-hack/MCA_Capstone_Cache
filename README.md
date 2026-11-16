# Direct-Mapped Cache Controller

A 32-bit, 1 KiB direct-mapped cache prototype with 64 lines, 16-byte blocks, four 32-bit words per line, write-through and write-allocate.

## Design documents

- [Architecture](docs/architecture.md)
- [RTL interface contract](docs/rtl_interface_contract.md)
- [Krishna's implementation notes](docs/krishna_implementation.md)
- [Aditya's implementation notes](docs/aditya_implementation.md)
- [Saumya's memory and performance-monitor notes](docs/saumya_implementation.md)
- [IEEE report](report/Cache_Controller_IEEE_Report.pdf) ([source](report/Cache_Controller_IEEE_Report.tex); figures rebuild with `python3 report/make_figures.py`)
- [Synthesis results](synth/README.md)

## Phase I prototype video report

[Watch/download the Phase I prototype video report](demo/Phase_I_Prototype_Video_Report.mov) (4 minutes 2 seconds).

The recording covers the project idea, team roles and planned individual contributions, and the prototype implementation/progress. It does not demonstrate testing. The testing demonstration is pending for Phase II; existing test results and verification artefacts remain documented below.

See [video scope and phase requirements](demo/README.md). This recording is the Phase I submission video, not a Phase II final demonstration.

## Modules and owners

| Module | Owner | File |
|---|---|---|
| Address decoder | Aditya | `rtl/address_decoder.v` |
| Cache storage | Rachit | `rtl/cache_storage.v` |
| Main memory model | Saumya | `memory/main_memory_model.v` |
| Performance monitor | Saumya | `rtl/performance_monitor.v` |
| Cache controller | Krishna | `rtl/cache_controller.v` |
| Integrated cache top | Krishna | `rtl/cache_top.v` |
| Integrated system verification | Nishtha | `sim/testbenches/tb_cache_top.v` |

## Results at a glance

| Workload | Reads | Hit rate | Measured AMAT |
|---|---:|---:|---:|
| Sequential | 20 | 80.00% | 3.80 cycles |
| Repeated block | 16 | 93.75% | 2.56 cycles |
| Conflict thrashing | 8 | 0.00% | 11.00 cycles |
| Random (seed 2026) | 64 | 35.94% | 7.77 cycles |

Read hit 2 cycles, read miss 11. ECP5-85F: 18,851 LUTs, 10,978 FFs, 1 block RAM, **61.1 MHz** post-route.

## Trace benchmark

```sh
bash sim/run_trace_benchmark.sh            # replays each trace through cache_top, measures cycles
python3 analysis/cache_trace_benchmark.py  # Python model of the same mapping
python3 analysis/gen_random_trace.py       # rebuilds the seeded random workload
```

The RTL replay and the Python model agree on every hit and miss count. See [results](docs/trace_benchmark_results.md), [methodology](docs/trace_benchmark.md) and `docs/results/rtl_trace_results.csv`.

## Synthesis

```sh
bash synth/run_synthesis.sh
```

Yosys for the gate counts, nextpnr-ecp5 for place-and-route timing. Details and limits are in [synth/README.md](synth/README.md).

## Simulation

Install Icarus Verilog (`iverilog` and `vvp`) and run the full Phase I regression from the repository root:

```sh
bash sim/run_krishna_tests.sh
```

The runner executes the address-decoder, cache-storage, controller, main-memory, memory-initialization and performance-monitor unit testbenches, then invokes `sim/run_cache_top_verification.sh` to run the actual integrated `cache_top` test and generate eight isolated VCD scenarios.

The committed integrated verification report records 39 checks passed with 0 failures for the combined Issue #7 and Issue #8 sequence, with 26 processor accesses, 13 hits and 13 misses. The decoder test log records 374 checks and 0 errors. See [integrated verification evidence](sim/waveforms/verification_report.md) for scenario-level results and waveform names.

## Processor request protocol

`cpu_req` marks one request. The controller captures the request only while idle. `cpu_ready` is a one-cycle completion pulse; read data is valid with that pulse. Requests asserted while busy are not queued. Deassert `cpu_req` for at least one rising edge between transactions.

## Cache configuration

- 32-bit byte address
- 1 KiB direct-mapped cache
- 64 lines, 16-byte blocks
- Four 32-bit words per line
- Tag/index/offset fields: 22/6/4 bits
- Word-aligned requests only
- Write-through and write-allocate
