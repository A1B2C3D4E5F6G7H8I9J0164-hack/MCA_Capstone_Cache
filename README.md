# Direct-Mapped Cache Controller — Phase I

A 32-bit, 1 KiB direct-mapped cache prototype with 64 lines, 16-byte blocks, four 32-bit words per line, write-through and write-allocate.

## Design documents

- [Architecture](docs/architecture.md)
- [RTL interface contract](docs/rtl_interface_contract.md)
- [Krishna's implementation notes](docs/krishna_implementation.md)
- [Aditya's implementation notes](docs/aditya_implementation.md)

## Modules and owners

| Module | Owner | File |
|---|---|---|
| Address decoder | Aditya | `rtl/address_decoder.v` |
| Cache storage | Rachit | `rtl/cache_storage.v` |
| Main memory model | Saumya | `memory/main_memory_model.v` |
| Performance monitor | Saumya | `rtl/performance_monitor.v` |
| Cache controller | Krishna | `rtl/cache_controller.v` |
| Integrated cache top | Krishna | `rtl/cache_top.v` |

The decoder and storage source files remain with their respective task owners. Their exact required interfaces are in the interface contract.

## Simulation

Install Icarus Verilog and run:

```sh
bash sim/run_krishna_tests.sh
```

The controller-level bench models decoder/storage behaviour and delayed main memory. Memory and performance-monitor unit benches are run separately. Once the decoder and storage are merged, the script also elaborates the real `cache_top`.

## Processor request protocol

`cpu_req` marks one request. The controller captures the request only while idle. `cpu_ready` is a one-cycle completion pulse; read data is valid with that pulse. Requests asserted while busy are not queued. Deassert `cpu_req` for at least one rising edge between transactions.
