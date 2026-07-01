# Moondesk Roadmap

Moondesk is the native desktop shell for executable books. It should stay small
enough to reason about: discover books, edit/read them through MoonWiki, code on
them through MoonCode, hand scheduled work to Moontown, hand bounded execution
to MoonClaw, consume shared MoonSuite filesystem contracts from MoonLib, and
package generated app-tools.

See [Status](STATUS.md) for the current implementation state and
[Architecture](ARCHITECTURE.md) for the cross-project boundary.

## Product Shape

The target product is:

```text
Moondesk
  native shell
  scoped file/workspace API
  MoonWiki workspace
  MoonCode workspace
  Moontown controls
  MoonClaw controls
  portable app-tool export
```

It is not:

- a market-specific workflow host
- a source-discovery engine
- an agent runtime
- a durable knowledge store
- a second implementation of MoonBook, Moontown, or MoonClaw

## Current Tracks

### 1. Native Desktop Shell

Goal: a self-contained macOS app that uses Lepusa as the native host, starts the
Moondesk MoonBit server as a supervised localhost sidecar, and opens the Rabbita
desktop in the system WebView.

Done:

- local MoonBit host
- scoped workspace APIs
- Lepusa bundle generation for the default native app
- supervised localhost sidecar manifest for the existing Moondesk server
- bundled Lepusa runtime
- signing, DMG, update metadata, and LaunchAgent commands

Still needed:

- clean-machine install/update validation
- credentialed signing/notarization in a real release pipeline
- long-running host lifecycle testing

### 2. MoonWiki Workspace

Goal: make durable book knowledge easy to browse, edit, review, and publish
without making Moondesk own the book.

Done:

- MoonBook discovery under `books`
- file tree, search, previews, raw file serving
- inbox notes and scoped imports
- scoped Markdown editing for `wiki/` and `inbox/` files with live preview
- review queues and diffs
- generated site/app-tool preview links

Still needed:

- richer Markdown editing ergonomics for history and shortcuts
- richer review queue filters
- cleaner generated-site publish receipts

### 3. MoonCode Workspace

Goal: a Codex-like coding/chat workspace for executable books, with MoonClaw as
the runtime and MoonBook as the durable artifact owner.

Done:

- book-scoped session surfaces
- contextual prompt composer
- MoonClaw daemon/model inspection
- command queues, runtime events, tool approvals, tests, package views
- desktop projection records for UI state

Still needed:

- stronger live diff review and patch staging
- clearer commit/package handoff
- model-backed eval coverage for real coding tasks
- longer resume/cancel reliability testing

### 4. Moontown Control Surface

Goal: let humans create requests and standing watches while Moontown owns
scheduling, coordination, notifications, and book-to-book communication.

Done:

- request composer and ledger
- standing-goal creation and cadence views
- daemon tick controls
- town message, progress, event, review, and analytics surfaces

Still needed:

- richer notification policy
- clearer multi-book communication views
- stronger daemon lifecycle UX for unattended operation

### 5. Reusable Book Patterns

Goal: make workflows reusable as book patterns and domain packs, not permanent
Moondesk features.

Done:

- PDF Evidence Watch creator as a reusable `research-book` pattern
- source website config, method page, skills, schemas, generated placeholders
- standing-watch registration
- portable app-tool export for explicit toolbooks and detected `app/index.html`

Still needed:

- move real domain examples into standalone packs
- improve template discovery/install UX
- package app-tools with clearer static-host/native-shell guidance

### 6. MoonSuite Contract Extraction

Goal: after the product-home migration stabilizes, move the shared filesystem
contract into MoonLib and make every product consume the same typed path and
registry helpers.

Done:

- MoonSuite v2 plan identifies `moonlib` as contract owner and `moonstat` as
  validator/reporter.
- Product-home migration has already moved major Moondesk, MoonClaw, Moontown,
  MoonFish, MoonMoon, Lepusa, and MoonRobo state paths toward
  `.moonsuite/products/<product>`.

Still needed:

- add a MoonLib package for suite root, product registry, product ids,
  product-home paths, suite temp paths, and book path constructors
- replace product-local string helpers with MoonLib contract calls
- make MoonStat validate live workspaces against MoonLib and report
  legacy-path drift without owning the contract
- add cross-product integration tests from a fresh MoonSuite root

## Engineering Bar

Every track should converge toward:

- no obsolete routes or stale product stories
- no domain-specific source lists in Moondesk
- no hidden dependency on a browser-only shell for production use
- no product-local reinvention of MoonSuite filesystem path contracts
- warning-clean MoonBit checks
- focused tests around changed behavior
- generated interfaces updated with `moon info`
- Rabbita build green after UI changes
