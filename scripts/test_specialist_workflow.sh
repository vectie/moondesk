#!/usr/bin/env bash
# Bounded Node qualification of the creator/controller and existing bridge runtime.
# Uses only built-in Node modules. No dependency restoration, browser, or provider.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root/ui/rabbita-desk"
node --check specialist-builder.js
node --check specialist-portable.js
node --check specialist-composition.js
node --check specialist-task-form.js
node --check specialist-task-csv.js
node --check specialist-task-files.js
node --check workspace-features-runtime.js
node --test specialist-stage-replacement.test.mjs specialist-task-files.test.mjs specialist-portable.test.mjs specialist-task-csv.test.mjs specialist-variants.test.mjs specialist-task-form.test.mjs specialist-composition.test.mjs specialist-builder.test.mjs specialist-builder-dom.test.mjs specialist-history.test.mjs workspace-features-runtime.test.mjs
