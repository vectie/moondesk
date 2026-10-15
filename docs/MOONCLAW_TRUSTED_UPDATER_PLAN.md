# MoonClaw managed updater: trust boundary plan

Status: design and dependency audit, 2026-10-05. The installer guard in
`internal/moonwiki/moonclaw_installer.mbt` remains enabled. No managed binary,
service descriptor, active desktop configuration, or credential was changed.

## Why the existing components cannot be wired together yet

| Component | Reusable part | Missing for a trusted MoonClaw install |
| --- | --- | --- |
| `internal/moonwiki/execution_sandbox_client.mbt` | Typed, fail-closed request shape | Its availability is always false; it has no updater operation or backend transport. |
| MoonFort | Approved one-shot execution, bounded resources, scratch inspection and promotion | The local backend denies network, is reported as degraded, and promotes workspace scratch rather than a MoonDesk managed runtime. Its stricter AEN backend has no configured deployment here. |
| Lepusa `plugins/updater` | Update command names and policy metadata | The handlers return `status: delegated`; they set state flags but perform no authenticated fetch, extraction or installation. |
| MoonDesk workspace ZIP import | Confined paths and entry limits | It rejects deflated entries and caps one expanded file at 8 MiB. A built MoonClaw executable is about 25 MiB. It is not a managed-runtime installer. |
| MoonClaw release packaging | `moonclaw-release-manifest.v1`, archive SHA-256, platform and architecture | Current archive is `tar.gz`; the manifest and checksum file have no publisher signature or pinned key. The manifest URL can be overridden at packaging time. |
| `internal/trusted_host_process/managed_daemon.mbt` | Fixed versioned runtime binding and canonical executable checks | It launches an already installed runtime. It does not authenticate, stage, initialize or promote one. |

The MoonDesk handler `POST /api/moonclaw/daemon/install` calls
`install_moonclaw_release`. On supported macOS arm64 and Linux arm64/x86_64,
that function correctly returns `updater_sandbox_unavailable` with
`execution-sandbox-updater.v1`, `fallback: deny` and
`host_process_fallback: false`. The existing refusal tests should remain until
an end-to-end implementation proves all steps below.

## Required interfaces

1. **Trusted release identity.** Publish a signed, canonical manifest for a
   fixed MoonClaw channel and version. It must bind product ID, version,
   platform, architecture, exact archive URL, compressed byte limit and
   SHA-256, installed executable path and SHA-256, and signature key ID. Pin
   the public verification key and canonical HTTPS feed origin in MoonDesk's
   application resources, not the workspace or an HTTP request. The current
   `moonclaw-release-manifest.v1` can supply the archive hash but cannot by
   itself authenticate the publisher. This needs a vetted signature verifier
   (preferably MoonBit Ed25519) and a signed-manifest publisher step in
   MoonClaw's release pipeline.
2. **Bounded transport.** Add a host-owned updater transport with an exact
   release origin allowlist, TLS certificate validation, restricted redirects,
   request deadlines, and streamed byte ceilings for manifest and archive.
   It must reject alternate hosts, insecure schemes, oversized bodies,
   malformed versions and platform mismatch. The MoonDesk API must accept no
   caller-supplied URL, command, executable, working directory or arguments.
3. **Private staging and archive validation.** Stage downloads beneath a
   canonical, owner-private MoonDesk runtime root. Validate the archive hash
   before opening it. Use a dedicated streaming `tar.gz` extractor with hard
   expanded-size, entry-count and path limits, or change the MoonClaw release
   format to a bounded stored ZIP. Reject symlinks, hardlinks, devices,
   absolute or parent paths, duplicate normalized names, unexpected entries
   and permission changes. The existing workspace ZIP importer is not
   suitable as-is. Verify the staged executable hash and its expected format
   and platform before making it runnable.
4. **Isolated initialization.** Add one typed updater operation to a real
   ExecutionSandbox backend. It may run only the verified staged MoonClaw
   executable with fixed self-check arguments, no network, no workspace
   access, bounded time/memory/output, and an attested receipt bound to the
   manifest and binary digests. A MoonFort AEN deployment, or an equivalently
   reviewed isolated backend, must be configured and behaviorally probed.
   A degraded local sandbox or a host process is not an automatic fallback.
5. **Atomic promotion.** After a successful sandbox receipt, a narrow trusted
   host capability may atomically rename the verified stage into
   `<managed-runtime-root>/moonclaw/<version>/bin/moonclaw`, refusing
   symlinks and existing mismatched versions. Only then write a minimal
   `{kind: "moondesk-moonclaw-service.v1", version}` descriptor atomically.
   Preserve separate model, MoonGate and authentication settings. Keep the
   previous installed version for rollback; failed fetch, validation,
   initialization or promotion must leave the active descriptor unchanged.
6. **Receipt and API.** `execution-sandbox-updater.v1` should return a bounded
   receipt with version, target, manifest/archive/binary digests,
   initialization result, promotion result, and a reason code. Expose only
   sanitized status to `/api/moonclaw/daemon/install`; never return private
   paths, tokens or subprocess output. On success, use the existing managed
   daemon binding and verify `/api/moonclaw/daemon` and
   `/api/mooncode/status` report a running, ready service.

Suggested MoonBit boundary: `install_moonclaw_release` submits an opaque
`MoonClawInstall(channel)` request to a new trusted updater client. The client
must resolve release URLs, keys, paths, sandbox policy and process arguments
from host-owned configuration. The handler should not receive or construct
those fields from workspace JSON. The updater owns the transaction and returns
one digest-bound receipt; MoonDesk does not interpret a success flag without
re-reading and verifying the managed install.

## Verification gate

Use hermetic fixture transport and a fake sandbox only for unit tests. Cover
signature and TLS-origin refusal, redirect to a different host, truncated and
oversized responses, mismatched hashes, wrong target/version, archive bombs,
all path/link/collision types, forged sandbox receipts, promotion races,
rollback and idempotent retry. Integration tests must exercise a real sandbox
probe and a signed release fixture on macOS arm64 and Linux targets. Keep the
current `updater_sandbox_unavailable` refusal until those tests and a
configured deployment pass; a mock backend must never set `available: true`
in production.
