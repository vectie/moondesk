# Full Validation Proof — 2026-07-27

| Field | Value |
| --- | --- |
| Result | Pass |
| Validation command | `./scripts/validate.sh full` |
| Proof checkout commit | `30594135508fa62833bf8948b081a579ea270fa5` |
| Final checkout status | Clean |
| Remote CI evidence | Not collected |

## Method

The proof ran in an isolated clone under `/tmp`, not in the user's dirty
working tree. The clone was prepared from the repository `HEAD`, the complete
tracked working-tree diff was applied, and every relevant non-ignored untracked
product file was copied. `.moonsuite/` runtime state was deliberately excluded.

The isolated clone then ran dependency installation, the production UI build,
generated-interface updates for the supported targets, and formatting. Those
deterministic outputs were committed only inside the throwaway clone. This
produced a clean checkout containing the exact product source, documentation,
validation script, workflow, generated interfaces, and distribution under
review. No branch, commit, or file in the user's repository was changed by the
proof setup.

The full validation command passed twice. The second run below is the retained
clean-state transcript. The final `git status --porcelain
--untracked-files=all` output was empty.

The core boundary validator reported an explicit skip because
`MOONCLAW_ROOT`, `MOONBOOK_ROOT`, and `MOONTOWN_ROOT` were all absent. This
matches the validator contract: no roots means a visible skip; a partial set is
an error; all three roots enable cross-product validation. This proof therefore
closes the MoonDesk clean-checkout gate but does not claim cross-product
boundary, remote CI, signing, notarization, update, or release evidence.

## Retained transcript

```text
==> MoonBit format check
Finished. moon: no work to do

==> MoonBit check
Finished. moon: no work to do
Finished. moon: no work to do
Finished. moon: ran 9 tasks, now up to date
Finished. moon: ran 16 tasks, now up to date

==> MoonBit native tests
Total tests: 217, passed: 217, failed: 0.

==> UI check
Finished. moon: ran 10 tasks, now up to date

==> UI tests
Total tests: 305, passed: 305, failed: 0.

==> UI localization tests

> test:i18n
> node --test moonsuite-i18n.test.mjs

TAP version 13
# Subtest: text templates translate dynamic UI copy
ok 1 - text templates translate dynamic UI copy
# Subtest: accessibility attributes only use exact translations
ok 2 - accessibility attributes only use exact translations
# Subtest: system language choice uses one locale instead of a bilingual label
ok 3 - system language choice uses one locale instead of a bilingual label
1..3
# tests 3
# suites 0
# pass 3
# fail 0
# cancelled 0
# skipped 0
# todo 0

==> UI production build

> prebuild
> moon build --target js --release && node prepare-rabbita-build.mjs release

Finished. moon: no work to do

> build
> vite build

vite v7.3.2 building client environment for production...
[vite-plugin-rabbita] selected vectie/moondesk-rabbita/main/main.js
transforming...
✓ 11 modules transformed.
rendering chunks...
computing gzip size...
dist/index.html                                  0.89 kB │ gzip:   0.53 kB
dist/assets/index-1U0O4FmJ.css                 123.16 kB │ gzip:  21.73 kB
dist/assets/index-BCs6SA_9.js                    3.69 kB │ gzip:   1.77 kB
dist/assets/_rabbita_main-entry-Do1j4N0D.js  2,079.23 kB │ gzip: 259.92 kB
✓ built in 6.08s

==> Generated-interface verification
Finished. moon: ran 16 tasks, now up to date
Finished. moon: ran 9 tasks, now up to date
Finished. moon: no work to do
Finished. moon: ran 10 tasks, now up to date
Finished. moon: no work to do
Skipping core boundary validation: MOONCLAW_ROOT, MOONBOOK_ROOT, and
MOONTOWN_ROOT are not set.

==> Whitespace errors

==> Clean generated tree

==> Proof checkout
commit: 30594135508fa62833bf8948b081a579ea270fa5
status:
```

## Gate conclusion

The Phase 0 clean-checkout full-validation requirement is satisfied by this
proof. Together with the baseline, ownership map, historical labels, canonical
validation entry point, and active-document truth audit, the local Phase 0 exit
gate is complete. Phase 2 remains open until retained pull-request/push runs and
the required preview-release evidence exist.
