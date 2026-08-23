#!/usr/bin/env bash
# Fail closed when a first-party MoonBit runtime package gains direct host
# process authority outside the single reviewed TrustedHostProcess package.

set -u

usage() {
  printf 'usage: %s MOONDESK_ROOT\n' "$0" >&2
}

if [ "$#" -ne 1 ]; then
  usage
  exit 64
fi

root=$1
if [ ! -d "$root" ]; then
  printf 'execution-boundary audit: not a directory: %s\n' "$root" >&2
  exit 66
fi

root=$(cd "$root" 2>/dev/null && pwd -P) || {
  printf 'execution-boundary audit: cannot resolve root: %s\n' "$1" >&2
  exit 66
}

if [ ! -f "$root/moon.mod" ] && [ ! -f "$root/moon.mod.json" ]; then
  printf 'execution-boundary audit: %s is not a MoonDesk source root (moon.mod missing)\n' "$root" >&2
  exit 66
fi

audit_tmp=$(mktemp -d "${TMPDIR:-/tmp}/moondesk-boundary-audit.XXXXXX") || exit 70
trap 'rm -rf "$audit_tmp"' EXIT HUP INT TERM
violations=$audit_tmp/violations.tsv
: >"$violations"

# This is deliberately a closed, path-exact package allowlist. Files may not
# be added elsewhere to obtain process authority. The package is reserved for
# fixed, reviewed host infrastructure operations; agent execution belongs
# behind ExecutionSandbox and is not allowed here.
is_trusted_host_process_path() {
  case "$1" in
    internal/trusted_host_process/*)
      trusted_relative=${1#internal/trusted_host_process/}
      case "$trusted_relative" in
        */*) return 1 ;;
        *) return 0 ;;
      esac
      ;;
    *) return 1 ;;
  esac
}

is_first_party_runtime_source() {
  case "$1" in
    .git/*|.moonagent/*|.mooncakes/*|.repos/*|_build/*|build/*|dist/*|node_modules/*) return 1 ;;
    */.git/*|*/.moonagent/*|*/.mooncakes/*|*/.repos/*|*/_build/*|*/build/*|*/dist/*|*/node_modules/*) return 1 ;;
    third_party/*|vendor/*|integration/*|tests/*|test/*|*/tests/*|*/test/*) return 1 ;;
    */third_party/*|*/vendor/*|*/integration/*) return 1 ;;
    *_test.mbt|*_wbtest.mbt|*/test_*.mbt) return 1 ;;
    *.mbt|*/moon.pkg|moon.pkg|*/moon.pkg.json|moon.pkg.json) return 0 ;;
    *) return 1 ;;
  esac
}

category_for_path() {
  case "$1" in
    internal/moonwiki/process_helpers.mbt) printf '%s' 'generic-process-authority' ;;
    internal/moonwiki/moonflow_*|internal/moonwiki/supervisor_bridge.mbt) printf '%s' 'moonflow-host-execution' ;;
    internal/moonwiki/moonclaw_installer.mbt) printf '%s' 'moonclaw-updater-host-execution' ;;
    internal/moonwiki/workspace_creation_handlers.mbt) printf '%s' 'workspace-import-host-execution' ;;
    internal/moonwiki/daemon_*|internal/moonwiki/moonclaw_daemon_api.mbt) printf '%s' 'daemon-host-process' ;;
    internal/moonwiki/launch_agent_lifecycle.mbt|internal/moonwiki/service_configuration_integrity.mbt) printf '%s' 'service-admin-host-process' ;;
    internal/moonwiki/workspace_reveal_handlers.mbt) printf '%s' 'desktop-shell-host-process' ;;
    internal/moonwiki/moon.pkg) printf '%s' 'moonwiki-package-process-authority' ;;
    cmd/main/*) printf '%s' 'cli-host-process' ;;
    *) printf '%s' 'unclassified-host-process' ;;
  esac
}

record() {
  category=$1
  relative=$2
  line=$3
  detail=$4
  detail=$(printf '%s' "$detail" | tr '\t\r\n' '   ')
  printf '%s\t%s\t%s\t%s\n' "$category" "$relative" "$line" "$detail" >>"$violations"
}

scan_moonbit_source() {
  relative=$1
  absolute=$root/$relative
  category=$(category_for_path "$relative")
  awk '
    /@process[.](run|spawn|spawn_orphan|collect_output|collect_stdout|collect_stderr|read_from_process|redirect_to_file|wait_pid)[[:space:]]*[(]/ ||
    /@process[.]Process/ ||
    /@spawn[.](run|spawn)[[:space:]]*[(]/ {
      text=$0
      sub(/^[[:space:]]+/, "", text)
      print "raw-process-api\t" NR "\t" text
    }
    /(^|[^[:alnum:]_])(run_process_(quiet|capture|capture_in)|run_command|execute_command|spawn_command|spawn_process|collect_command_output)[[:space:]]*[(]/ {
      text=$0
      sub(/^[[:space:]]+/, "", text)
      print "generic-process-helper\t" NR "\t" text
    }
  ' "$absolute" | while IFS=$'\t' read -r kind line detail; do
    record "$category" "$relative" "$line" "$kind: $detail"
  done
}

# TrustedHostProcess may contain reviewed raw calls, but it must never grow a
# generic command/args wrapper that recreates arbitrary process authority.
scan_trusted_host_source() {
  relative=$1
  absolute=$root/$relative
  awk '
    /(^|[^[:alnum:]_])(run_process_(quiet|capture|capture_in)|run_command|execute_command|spawn_command|spawn_process|collect_command_output)[[:space:]]*[(]/ {
      text=$0
      sub(/^[[:space:]]+/, "", text)
      print NR "\t" text
    }
  ' "$absolute" | while IFS=$'\t' read -r line detail; do
    record 'trusted-host-generic-authority' "$relative" "$line" \
      "generic-process-helper: $detail"
  done
}

# A package import grants authority to every production source in that package.
# Buffer import blocks so test-only and white-box-test-only imports stay exempt.
scan_package_file() {
  relative=$1
  absolute=$root/$relative
  category=$(category_for_path "$relative")
  awk '
    function raw(line) {
      return line ~ /"moonbitlang\/async\/process"/ ||
        line ~ /"vectie\/moonlib\/spawn"/ ||
        line ~ /"vectie\/moondesk\/internal\/process"/
    }
    function flush(    i) {
      for (i = 1; i <= count; i++) print lines[i] "\t" texts[i]
      delete lines
      delete texts
      count = 0
    }
    /^[[:space:]]*import[[:space:]]*\{/ {
      in_import = 1
      count = 0
    }
    in_import && raw($0) {
      count++
      lines[count] = NR
      text = $0
      sub(/^[[:space:]]+/, "", text)
      texts[count] = text
    }
    in_import && /}[[:space:]]*for[[:space:]]*"(test|wbtest)"/ {
      delete lines
      delete texts
      count = 0
      in_import = 0
      next
    }
    in_import && /}/ {
      flush()
      in_import = 0
    }
    END { if (in_import) flush() }
  ' "$absolute" | while IFS=$'\t' read -r line detail; do
    record "$category" "$relative" "$line" "package-process-authority: $detail"
  done
}

# JSON package manifests separate production `import` from `test-import` and
# `wbtest-import`. Scan only the production list.
scan_json_package_file() {
  relative=$1
  absolute=$root/$relative
  category=$(category_for_path "$relative")
  awk '
    function raw(line) {
      return line ~ /"moonbitlang\/async\/process"/ ||
        line ~ /"vectie\/moonlib\/spawn"/ ||
        line ~ /"vectie\/moondesk\/internal\/process"/
    }
    /^[[:space:]]*"import"[[:space:]]*:/ { in_import = 1 }
    /^[[:space:]]*"[^\"]+"[[:space:]]*:/ &&
      $0 !~ /^[[:space:]]*"import"[[:space:]]*:/ { in_import = 0 }
    in_import && raw($0) {
      text=$0
      sub(/^[[:space:]]+/, "", text)
      print NR "\t" text
    }
    in_import && /]/ { in_import = 0 }
  ' "$absolute" | while IFS=$'\t' read -r line detail; do
    record "$category" "$relative" "$line" "package-process-authority: $detail"
  done
}

while IFS= read -r -d '' absolute; do
  relative=${absolute#"$root"/}
  is_first_party_runtime_source "$relative" || continue
  if is_trusted_host_process_path "$relative"; then
    case "$relative" in
      *.mbt) scan_trusted_host_source "$relative" ;;
    esac
    continue
  fi
  case "$relative" in
    */moon.pkg.json|moon.pkg.json) scan_json_package_file "$relative" ;;
    */moon.pkg|moon.pkg) scan_package_file "$relative" ;;
    *) scan_moonbit_source "$relative" ;;
  esac
done < <(
  find "$root" \
    -type d \( \
      -name .git -o -name .moonagent -o -name .mooncakes -o -name .repos -o -name _build -o \
      -name build -o -name dist -o -name node_modules -o -name vendor -o \
      -name third_party -o -name integration -o -name tests -o -name test \
    \) -prune -o \
    -type f \( -name '*.mbt' -o -name 'moon.pkg' -o -name 'moon.pkg.json' \) -print0
)

if [ ! -s "$violations" ]; then
  printf 'MoonDesk execution-boundary audit: PASS\n'
  printf 'No production process authority exists outside internal/trusted_host_process/.\n'
  exit 0
fi

printf 'MoonDesk execution-boundary audit: FAIL\n'
printf 'MoonDesk root: %s\n' "$root"
printf 'Raw and generic process authority is permitted only under internal/trusted_host_process/.\n'
printf '\nViolations by category:\n'
cut -f1 "$violations" | sort | uniq -c | awk '{ printf "  %-40s %s\n", $2, $1 }'
printf '\nAll violations:\n'
sort -t $'\t' -k1,1 -k2,2 -k3,3n "$violations" |
  awk -F '\t' '{ printf "  [%s] %s:%s\n      %s\n", $1, $2, $3, $4 }'
printf '\nRequired boundary: route untrusted execution through ExecutionSandbox. Keep\n'
printf 'TrustedHostProcess limited to fixed, reviewed host infrastructure commands.\n'
exit 1
