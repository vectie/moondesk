# Native test linker investigation (2026-09-27)

## Symptom

On an Apple Silicon Mac with MoonBit `0.1.20260920` and `moonc v0.10.14+7d59c7ec9-dev`, `scripts/validate.sh fast` appeared idle for several minutes at `MoonBit native tests`. The process was actually `moonc link-core` at nearly 100% of one CPU core. It reached about 2.9 GB resident memory while linking `cmd/main/main.blackbox_test.o`.

The hosted PR validation at `77b31d4b` spent 47 minutes 34 seconds between starting `moon test --target native` for pinned MoonBook `d75aaaa6` and reporting 369 passing tests. The first unsigned `.21` preview timed out while running that same full suite on macOS.

## Root cause and evidence

- MoonBit generates `cmd/main/main.blackbox_test.core` even though `cmd/main/__blackbox_test_info.json` lists **zero** blackbox tests. Its native link command still pulls in 85 `.core` files totaling 17.7 MiB, including the 6.9 MiB MoonWiki core and the application entrypoint. The resulting debug object was 19 MiB.
- The observed slow process was `moonc -rsp-file .../main.blackbox_test.o.rsp`, not the C system linker or a test waiting on I/O. A macOS sample showed one active `moonc` OCaml runtime thread with allocation and garbage collection. This does not identify a more specific internal compiler algorithm because the distributed `moonc` has no useful symbols for that code path.
- Replaying the **same** linker inputs and flags, apart from removing `-g` and selecting a temporary output path, completed in **30.70 seconds** and produced a 13 MiB object. The original debug-symbol link had already consumed over eight CPU minutes and about 2.9 GB resident memory in the local gate. This isolates debug-symbol generation as the major cost for that link.
- `moon test --target native --strip` removes `-g` from the `moonc link-core` commands. The complete MoonDesk native suite then passed **491/491** in **61.15 seconds** on the same Mac. Pinned MoonBook passed **369/369** in **78.91 seconds** with `--strip`.

## Mitigation

Native validation now supplies `--strip` to MoonDesk and pinned cross-repository test suites. This keeps the same tests and warning settings while omitting native debug symbols from the test binaries. It does not change production package or release builds. A future MoonBit toolchain may avoid linking empty blackbox suites or improve debug-symbol link performance; this gate can be revisited then.

The Mac and Ubuntu durations are from different machines and are not a controlled cross-host speed comparison. The controlled comparison is the identical local linker input with and without `-g`.
