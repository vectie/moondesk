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
moonleaf_root="${MOONLEAF_ROOT:-${moondesk_root}/../moonleaf}"
moonlib_root="${MOONLIB_ROOT:-${moondesk_root}/../moonlib}"

# Match MoonDesk's supported local workspace dependencies without changing any
# module version requirements or fetching an older registry substitute.
for local_root in "${moonleaf_root}" "${moonlib_root}"; do
  if [[ ! -f "${local_root}/moon.mod" ]]; then
    echo "Local workspace dependency not found: ${local_root}/moon.mod" >&2
    echo "Set MOONLEAF_ROOT and MOONLIB_ROOT to the accepted local checkouts." >&2
    exit 2
  fi
done

if [[ ! -d "${moonclaw_root}/mooncode/core" ]]; then
  echo "MoonClaw mooncode/core package not found: ${moonclaw_root}/mooncode/core" >&2
  exit 2
fi

probe_root="${moondesk_root}/integration/mooncode_contract_probe"
workspace="$(mktemp -d "${TMPDIR:-/tmp}/mooncode-contract-work.XXXXXX")"
trap 'rm -rf "${workspace}"' EXIT HUP INT TERM

ln -s "${moondesk_root}" "${workspace}/moondesk"
ln -s "${moonclaw_root}" "${workspace}/moonclaw"
ln -s "${moonleaf_root}" "${workspace}/moonleaf"
ln -s "${moonlib_root}" "${workspace}/moonlib"
# Keep the executable package physically inside the workspace. A symlinked
# package is canonicalized to its source checkout before workspace discovery.
mkdir "${workspace}/probe"
cp "${probe_root}/moon.mod" "${probe_root}/moon.pkg" \
  "${probe_root}/main.mbt" "${workspace}/probe/"
cp "${probe_root}/moon.work.template" "${workspace}/moon.work"

echo "+ execute MoonClaw producer -> MoonDesk consumer contract probe"
(
  # Start at the workspace root. Entering the probe symlink can canonicalize
  # back to its source checkout and lose the isolated workspace membership.
  cd "${workspace}"
  "${moon_bin}" run --target native --strip -j 2 probe
)

echo "MoonCode producer/consumer compatibility passed."
