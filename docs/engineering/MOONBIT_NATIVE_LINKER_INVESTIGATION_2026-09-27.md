# Native test linker investigation (2026-09-27)

## Symptom

On an Apple Silicon Mac with MoonBit `0.1.20260920` and `moonc v0.10.14+7d59c7ec9-dev`, `scripts/validate.sh fast` appeared idle for several minutes at `MoonBit native tests`. The process was actually `moonc link-core` at nearly 100% of one CPU core. It reached about 2.9 GB resident memory while linking `cmd/main/main.blackbox_test.o`.

The hosted PR validation at `77b31d4b` spent 47 minutes 34 seconds between starting `moon test --target native` for pinned MoonBook `d75aaaa6` and reporting 369 passing tests. The first unsigned `.21` preview timed out while running that same full suite on macOS.

## Root cause and evidence

- MoonBit generates `cmd/main/main.blackbox_test.core` even though `cmd/main/__blackbox_test_info.json` lists **zero** blackbox tests. Its native link command still pulls in 85 `.core` files totaling 17.7 MiB, including the 6.9 MiB MoonWiki core and the application entrypoint. The resulting debug object was 19 MiB.
- The observed slow process was `moonc -rsp-file .../main.blackbox_test.o.rsp`, not the C system linker or a test waiting on I/O. A macOS sample showed one active `moonc` OCaml runtime thread with allocation and garbage collection. This does not identify a more specific internal compiler algorithm because the distributed `moonc` has no useful symbols for that code path.
- Replaying the **same** linker inputs and flags, apart from removing `-g` and selecting a temporary output path, completed in **30.70 seconds** and produced a 13 MiB object. The original debug-symbol link had already consumed over eight CPU minutes and about 2.9 GB resident memory in the local gate. This isolates debug-symbol generation as the major cost for that link.
- `moon test --target native --strip` removes `-g` from the `moonc link-core` commands. The complete MoonDesk native suite then passed **491/491** in **61.15 seconds** on the same Mac. Pinned MoonBook passed **369/369** in **78.91 seconds** with `--strip`.

## Deeper process and graph measurements

The native test build has two distinct link steps. `moonc link-core` consumes
MoonBit `.core` intermediate files and emits one native `.o` per test target.
The following `/usr/bin/cc` invocation links that object with the runtime and
C stubs into an executable. Replaying the latter command for the same
`cmd/main` blackbox target completed in **0.194 seconds** and yielded an
11.85 MiB executable. The stalled step is therefore MoonBit whole-program
link/code generation, not Apple's `ld`.

On a fresh replay of the 85-core command without `-g`, `moonc` completed in
**33.64 seconds**, with **1,767 MiB** peak RSS and a 13.2 MiB object. An
otherwise identical `-g` replay was still at **99% of one CPU**, **1,241 MiB**
RSS, and had produced no object after **55 seconds**; it was deliberately
terminated then rather than repeat the eight-minute diagnostic stall. A
five-second `sample` during that run placed 3,767 of 3,867 main-thread samples
in `caml_interprete`. That confirms compiler CPU work, but the stripped
compiler binary does not expose which internal debug-information operation is
expensive. The controlled completed/noncompleted comparison and the earlier
eight-minute observation support `-g` as the dominant *avoidable* cost; they
do not prove a particular internal complexity class.

`moon --dry-run test --target native` describes **52** MoonDesk `moonc
link-core` tasks; its `--strip` form describes the same 52, with `-g` removed
from every command. Of 21 blackbox link tasks, **11** have zero registered
blackbox tests. In MoonClaw's full native test graph there are **320**
`link-core` tasks, including **134** blackbox links of which **66** have zero
registered tests. These are full build graph counts, not a claim that every
task reruns on an incremental build. In the existing MoonClaw build cache,
16 empty blackbox links alone represented a cumulative **0.313 GiB** of
repeated `.core` inputs. Its empty `cmd/main` blackbox target pulls **159**
cores totaling **39.0 MiB**, including daemon (7.63 MiB), job (5.41 MiB),
and Unicode width (3.14 MiB) cores. The width core originates from a
1.08 MiB generated table source. Large transitive graphs and empty test
targets amplify the cost even after debug symbols are disabled.

The measurements point to two separate causes: MoonBit emits a whole-program
native object for each test target, even some with no tests; and `-g` makes
that operation extremely expensive on large graphs in this toolchain version.
`--strip` removes the expensive flag while retaining every test. Skipping
empty blackbox links in MoonBit's test graph and improving debug metadata
generation are upstream opportunities; moving whitebox tests merely to avoid
the link would weaken coverage and is not part of this mitigation.

To reproduce the command inventory without building, run `moon --dry-run test
--target native` and `moon --dry-run test --target native --strip`. To inspect
the exact inputs for the worst MoonDesk target after a native test build, read
`_build/native/debug/test/cmd/main/__moonbit_link_core__/main.blackbox_test.o.rsp`.
For a controlled replay, copy that response file, replace the argument after
`-o` with a temporary output path, and add or remove the single `-g` line;
then invoke `moonc -rsp-file <copied-file>`. Do not run the debug variant as a
routine gate: it can consume minutes and several GiB for a zero-test target.

## Mitigation

Native validation now supplies `--strip` to MoonDesk and pinned cross-repository test suites. This keeps the same tests and warning settings while omitting native debug symbols from the test binaries. It does not change production package or release builds. A future MoonBit toolchain may avoid linking empty blackbox suites or improve debug-symbol link performance; this gate can be revisited then.

The Mac and Ubuntu durations are from different machines and are not a controlled cross-host speed comparison. The controlled comparison is the identical local linker input with and without `-g`.
