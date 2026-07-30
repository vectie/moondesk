# Phase 9 install, update, rollback, and removal checklist

Use immutable release identities and record before/after user-data hashes with `schemas/phase9-evidence.schema.json`.

- [ ] Mount signed DMG and copy MoonDesk.app to Applications
- [ ] First launch passes ordinary Gatekeeper evaluation
- [ ] Install from stable and preview metadata without changing channels implicitly
- [ ] In-place update preserves user libraries and settings
- [ ] Interrupt update at download, verification, staging, and replacement boundaries
- [ ] Roll back to the preceding compatible immutable release or fail safely
- [ ] Remove application and support executables without deleting user data
- [ ] Confirm update metadata signature and every artifact checksum before execution
