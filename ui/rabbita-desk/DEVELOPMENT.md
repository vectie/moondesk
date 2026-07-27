# Development log

## Source-pane foundation recovery

Command 001 exhausted MoonClaw’s 8-step planner window after creating `main/source_pane.mbt`. It also invoked `moon ide` with the duplicated path `ui/rabbita-desk/ui/rabbita-desk/...`, and its shell probe failed. Recovery: use paths relative to `ui/rabbita-desk` for IDE operations, replace the invented `DeskPreviewPayload` with the repository’s actual `@desk.DeskPreview`, integrate feature state and one wrapped root message, and validate with focused formatting, checking, and tests.

## Source-pane completion recovery

Command 001 duplicated the `moon ide` path, ran a failed shell probe, and exhausted the planner window. Exact recovery: run semantic operations with paths relative to `ui/rabbita-desk`, avoid the failed probe, and continue in a fresh bounded planner window with direct source edits and focused validation.

Command 002 used a wrong formatter target, inserted an invalid initializer, used the wrong no-op API, constructed an inaccessible preview record literal, called the wrong `initial_model` name, used Show-based assertions for Debug/Eq-only source-pane types, and exhausted the planner window. Exact recovery: run targetless `moon fmt`; use the existing valid model initialization and `init_model()`; return `@rabbita.none`; construct previews as `@desk.preview(@desk.file_entry(workspace_id="book-demo", path~), body~)`; replace `assert_eq`/`inspect` on `SourcePaneState` and `SourcePaneContent` with `assert_true` equality or pattern matching plus primitive-field assertions; then run JS check with warning 73 enabled and the focused source-pane tests.

Command 003 used a wrong root-relative read, its regex did not match record/test constructs, it accidentally called `@rabbita.none()`, and its `/tmp` operation was rejected by safety policy. Recovery: use a full-file write and book-relative direct validation with no redirects or `/tmp`.

Command 004 attempted to read `DEVELOPMENT.md` from the wrong root and repeatedly supplied a formatter target even though this package requires targetless formatting. Recovery: use the book-root path `ui/rabbita-desk/DEVELOPMENT.md` and run `moon fmt` without a target before the requested JS checks and tests.
## Command 005 recovery

Command 005 used the wrong `app_url_helpers` path and the wrong base for `moon ide`, then exhausted the planner window before verification. Recovery converts the trimmed `RequestSource` path from `StringView` to an owned `String` with the toolchain-recommended `.to_owned()`. Verification requires targetless formatting, JS checking with warning 73 enabled, the focused source-pane test, and the full JS test suite.

Command 006 twice misused the fmt target and exhausted its planner window after check but before tests. Recovery uses direct targetless shell `moon fmt`, then continuation tests: the focused JS source-pane test followed by the full JS test suite.


## Command 007 success and authoritative context-sync recovery

Command 007 completed successfully. Its historical baseline was **8/8 focused source-pane tests** and **300/300 full JS tests**; after adding this recovery's regression coverage, the exact rerun is **11/11 focused** and **303/303 full JS**. This recovery makes the root model authoritative for source-pane fetch identity: initialization reuses the browser-restored workspace/session values; a pure central post-update synchronization step preserves every matched action command; unchanged context is a complete no-op; changed context invalidates content while preserving open/collapsed preferences; and nonempty requests without workspace authority fail locally. Prompt context remains isolated from source-pane selection. Targetless `moon fmt` succeeded, and `moon check --target js --warn-list '+73'` succeeded with only pre-existing unrelated warnings (no warning 73).
