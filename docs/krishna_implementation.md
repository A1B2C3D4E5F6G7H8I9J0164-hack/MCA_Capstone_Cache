# Krishna's Phase I Implementation Notes

Scope: issues #1, #2 and #3.

## Deliverables

- `docs/architecture.md`: frozen cache geometry, address organisation, policy, datapath and FSM.
- `docs/rtl_interface_contract.md`: exact named-port contracts, widths and timing for all modules.
- `rtl/cache_controller.v`: FSM, hit/miss, four-word refill, write-through hit, write-allocate miss, busy-request handling and performance events.
- `rtl/cache_top.v`: top-level wiring of the controller, decoder, storage, main memory and performance monitor.
- `sim/testbenches/tb_cache_controller.v`: controller-level verification using behavioural cache and memory models.
- `sim/run_krishna_tests.sh`: reproducible local simulation and integration-elaboration commands.

## Controller behaviour

The FSM captures one CPU request in IDLE and evaluates the cache in LOOKUP. Read hit returns the selected word. Read miss issues one block read, waits for memory ready, pulses line refill, then returns the selected word. Write hit updates the cached word and issues a single-word main-memory write. Write miss refills the line, updates the requested word, writes through, then responds after memory acknowledgement.

A request is accepted once per assertion of `cpu_req`. A held-high request is not replayed. A request first asserted while busy is dropped, not queued. The requester must wait for `cpu_ready`, then deassert `cpu_req` for at least one rising edge before another request.

## Validation boundary

The controller testbench models the decoder/cache storage and a delayed single-outstanding-request memory. It checks read hits/misses, word selection, same-index/different-tag replacement, write-hit and write-miss consistency, busy-request suppression and counters.

The top-level elaboration depends on Aditya's `rtl/address_decoder.v` and Rachit's `rtl/cache_storage.v`. Those modules are intentionally not duplicated because they belong to other owners. Do not claim full `cache_top` validation until both are merged and the integrated compile and end-to-end tests run.

## Acceptance mapping

### #1 — Architecture and interface contract
Configuration and policy are documented in `architecture.md`; ports, signal widths, reset, handshake and memory timing are documented in `rtl_interface_contract.md`.

### #2 — Controller FSM and refill
Request acceptance, lookup, refill, selected-word return and debug-state visibility are implemented in `cache_controller.v`.

### #3 — Write policy and top-level integration
Write-hit and write-miss write-through handling, one completion classification, and top-level module wiring are implemented in `cache_controller.v` and `cache_top.v`.

## Build

From repository root, install Icarus Verilog (`iverilog` and `vvp`) and run:

```sh
bash sim/run_krishna_tests.sh
```
