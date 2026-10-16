# Connection QR acceptance — 2026-10-16

Target: the signed-in hosted MoonDesk at
`https://suanli.kechuangfuwu.com:8443/moondesk/`, as guojiaan.
No local/demo browser was used.

- Complete native suite: **1289/1289 passed**.
- Scanner, provider handoff, i18n and bundle tests: **18/18 passed**.
- A QR matrix from the MaaS MoonBit encoder decodes into the same generic
  settings using the pinned `jsqr` decoder. The fixture has a synthetic key.
- A synthetic QR image captured from live MaaS was read by live MoonDesk.
  The review showed the correct HTTPS URL, model `glm-5.3.flash`, output
  recommendation `16384`, and masked key. Invalid discovery was rejected
  before writing any provider configuration.
- The owner-approved real-key request returned HTTP 200, assistant output
  `OK`, and `finish_reason=stop` from the documented public GLM API.
- The approved real-key import completed model discovery, provider
  configuration, activation and the published `moondesk` binding. The dialog
  closed and opened Code with `glm-5.3.flash` selected. A small request through
  MoonDesk completed with assistant output `OK`, without tool use or file edits.
- All three reviewed workspace deployment templates and the future-workspace
  runtime template use the final hosted image
  `sha256:b12179ba49e488ea8bc7882dcbcc2d2c002cc91cb1012f8d7c4a0ee644fa2db0`.
  A supplemental egress policy permits only the approved GLM destination and
  TCP port for those workspaces; controller-owned isolation remains in place.
- The private settings textarea is cleared after review; cancellation stops
  camera tracks and clears the candidate. Generation guards discard late
  camera/image reads. The camera capture implementation was not exercised
  with a physical camera; QR-image scanning was exercised in the live UI.
- The hosted package includes dynamic OpenSSL and trusted CA files while
  retaining certificate verification. Existing gateway/runtime binaries,
  workspace volumes and credential references stay in the reviewed OCI base.
- Control bootstrap tests require the exact local Origin and same-origin
  header and reject remote bootstrap. Control tokens never reach the browser.

Private keys, credential-bearing QR images, raw control responses and private
deployment snapshots are excluded from this evidence and the repository.
