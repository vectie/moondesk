#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
moondesk_root="$(cd "${script_dir}/.." && pwd)"
moonclaw_root="${MOONCLAW_ROOT:-$(cd "${moondesk_root}/../moonclaw" && pwd)}"

moondesk_core="${moondesk_root}/mooncode/core"
moonclaw_core="${moonclaw_root}/mooncode/core"

if [[ ! -d "${moonclaw_core}" ]]; then
  echo "MoonClaw mooncode/core package not found: ${moonclaw_core}" >&2
  echo "Set MOONCLAW_ROOT to the MoonClaw checkout when it is not ../moonclaw." >&2
  exit 2
fi

compare_file() {
  local relative="$1"
  diff -u "${moondesk_core}/${relative}" "${moonclaw_core}/${relative}"
}

compare_file "moon.pkg"
compare_file "protocol.mbt"
compare_file "protocol_wbtest.mbt"

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/mooncode-core-sync.XXXXXX")"
trap 'rm -rf "${tmp_dir}"' EXIT

sed 's#^package ".*"$#package "<mooncode/core>"#' \
  "${moondesk_core}/pkg.generated.mbti" > "${tmp_dir}/moondesk.mbti"
sed 's#^package ".*"$#package "<mooncode/core>"#' \
  "${moonclaw_core}/pkg.generated.mbti" > "${tmp_dir}/moonclaw.mbti"
diff -u "${tmp_dir}/moondesk.mbti" "${tmp_dir}/moonclaw.mbti"

echo "MoonCode core contract is synchronized."
