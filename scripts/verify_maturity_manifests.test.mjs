import assert from "node:assert/strict";
import test from "node:test";

import {
  maturityStages,
  validateCapabilityManifest,
  validateIntegrationManifest,
} from "./verify_maturity_manifests.mjs";

function capabilityManifest(capability) {
  return {
    contract: "moonsuite-capability-maturity.v1",
    product: "fixture",
    stages: maturityStages,
    capabilities: [capability],
  };
}

test("available capabilities require release qualification", () => {
  const errors = validateCapabilityManifest(
    capabilityManifest({
      id: "paper-feature",
      owner: "fixture",
      stage: "implemented",
      availability: "available",
      evidence: [{ kind: "implementation", command: "fixture build" }],
      blockers: [],
    }),
  );
  assert.ok(errors.some((error) => error.includes("cannot be available")));
});

test("integrated capabilities require both test and integration evidence", () => {
  const errors = validateCapabilityManifest(
    capabilityManifest({
      id: "partly-integrated",
      owner: "fixture",
      stage: "integrated",
      availability: "internal",
      evidence: [{ kind: "test", command: "fixture test" }],
      blockers: [],
    }),
  );
  assert.ok(errors.some((error) => error.includes("integration evidence")));
});

test("CI checkout declarations must match the integration manifest", () => {
  const manifest = {
    contract: "moonsuite-integration.v1",
    release_ref_policy: "full-commit-sha",
    repositories: [
      {
        id: "moonclaw",
        repository: "vectie/moonclaw",
        ref: "main",
        checkout_path: "_integration/moonclaw",
        root_env: "MOONCLAW_ROOT",
        module: "vectie/moonclaw",
      },
      {
        id: "moonbook",
        repository: "vectie/moonbook",
        ref: "main",
        checkout_path: "_integration/moonbook",
        root_env: "MOONBOOK_ROOT",
        module: "vectie/moonbook",
      },
      {
        id: "moontown",
        repository: "vectie/moontown",
        ref: "main",
        checkout_path: "_integration/moontown",
        root_env: "MOONTOWN_ROOT",
        module: "vectie/moontown",
      },
    ],
  };
  const errors = validateIntegrationManifest(manifest, "repository: vectie/moonclaw");
  assert.ok(errors.some((error) => error.includes("moonbook")));
  assert.ok(errors.some((error) => error.includes("CI ref differs")));
});
