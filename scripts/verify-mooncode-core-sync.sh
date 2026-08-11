#!/usr/bin/env bash
set -euo pipefail

# Backward-compatible entry point. The two repositories intentionally have
# different package responsibilities: MoonClaw produces the native protocol;
# MoonDesk decodes it for presentation. Compatibility is therefore proved by
# executing the producer and consumer, not by requiring copied source trees.

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
moondesk_root="$(cd "${script_dir}/.." && pwd)"
moon_bin="${MOON:-moon}"

if [[ -z "${MOONCLAW_ROOT:-}" ]]; then
  echo "MOONCLAW_ROOT is required for MoonCode protocol compatibility validation." >&2
  echo "Set MOONCLAW_ROOT to the MoonClaw checkout path explicitly." >&2
  exit 2
fi

if [[ ! -d "${MOONCLAW_ROOT}" ]]; then
  echo "MOONCLAW_ROOT does not exist: ${MOONCLAW_ROOT}" >&2
  exit 2
fi

if ! command -v "${moon_bin}" >/dev/null 2>&1; then
  echo "MoonBit CLI not found: ${moon_bin}" >&2
  exit 2
fi

moonclaw_root="$(cd "${MOONCLAW_ROOT}" && pwd)"

if [[ ! -d "${moonclaw_root}/mooncode/core" ]]; then
  echo "MoonClaw mooncode/core package not found: ${moonclaw_root}/mooncode/core" >&2
  exit 2
fi

probe_root="${moondesk_root}/integration/mooncode_contract_probe"
workspace="$(mktemp -d "${TMPDIR:-/tmp}/mooncode-contract-work.XXXXXX")"
trap 'rm -rf "${workspace}"' EXIT HUP INT TERM

ln -s "${moondesk_root}" "${workspace}/moondesk"
ln -s "${moonclaw_root}" "${workspace}/moonclaw"
ln -s "${probe_root}" "${workspace}/probe"
cp "${probe_root}/moon.work.template" "${workspace}/moon.work"

echo "+ execute MoonClaw producer -> MoonDesk consumer contract probe"
(
  cd "${workspace}/probe"
  "${moon_bin}" run --target native .
)

echo "MoonCode producer/consumer compatibility passed."
