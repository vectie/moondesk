import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

export const maturityStages = [
  "declared",
  "implemented",
  "component_tested",
  "integrated",
  "journey_proved",
  "packaged",
  "release_qualified",
];

const availabilityStages = {
  hidden: "declared",
  internal: "implemented",
  preview: "packaged",
  available: "release_qualified",
};

const evidenceStages = {
  component_tested: "test",
  integrated: "integration",
  journey_proved: "journey",
  packaged: "package",
  release_qualified: "release",
};

function requireValue(condition, message, errors) {
  if (!condition) errors.push(message);
}

function rank(stage) {
  return maturityStages.indexOf(stage);
}

export function validateCapabilityManifest(manifest) {
  const errors = [];
  requireValue(
    manifest?.contract === "moonsuite-capability-maturity.v1",
    "capability manifest contract must be moonsuite-capability-maturity.v1",
    errors,
  );
  requireValue(
    JSON.stringify(manifest?.stages) === JSON.stringify(maturityStages),
    "capability stages must use the canonical ordered maturity ladder",
    errors,
  );
  requireValue(
    Array.isArray(manifest?.capabilities) && manifest.capabilities.length > 0,
    "capability manifest must contain capabilities",
    errors,
  );

  const ids = new Set();
  for (const capability of manifest?.capabilities ?? []) {
    const prefix = `capability ${capability?.id ?? "<missing>"}`;
    requireValue(
      typeof capability?.id === "string" &&
        /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(capability.id),
      `${prefix} must have a kebab-case id`,
      errors,
    );
    requireValue(!ids.has(capability?.id), `${prefix} is duplicated`, errors);
    ids.add(capability?.id);
    requireValue(
      typeof capability?.owner === "string" && capability.owner.length > 0,
      `${prefix} must name an owner`,
      errors,
    );
    requireValue(rank(capability?.stage) >= 0, `${prefix} has an unknown stage`, errors);
    requireValue(
      Object.hasOwn(availabilityStages, capability?.availability),
      `${prefix} has an unknown availability`,
      errors,
    );
    requireValue(Array.isArray(capability?.evidence), `${prefix} evidence must be an array`, errors);
    requireValue(Array.isArray(capability?.blockers), `${prefix} blockers must be an array`, errors);

    const minimumStage = availabilityStages[capability?.availability];
    if (minimumStage) {
      requireValue(
        rank(capability.stage) >= rank(minimumStage),
        `${prefix} cannot be ${capability.availability} at stage ${capability.stage}`,
        errors,
      );
    }

    const evidenceKinds = new Set(
      (capability?.evidence ?? []).map((entry) => entry?.kind),
    );
    for (const [stage, evidenceKind] of Object.entries(evidenceStages)) {
      if (rank(capability?.stage) >= rank(stage)) {
        requireValue(
          evidenceKinds.has(evidenceKind),
          `${prefix} at stage ${capability.stage} requires ${evidenceKind} evidence`,
          errors,
        );
      }
    }
    for (const entry of capability?.evidence ?? []) {
      requireValue(
        typeof entry?.command === "string" && entry.command.length > 0,
        `${prefix} contains evidence without a command`,
        errors,
      );
    }
  }
  return errors;
}

export function validateIntegrationManifest(manifest, workflowText) {
  const errors = [];
  requireValue(
    manifest?.contract === "moonsuite-integration.v1",
    "integration manifest contract must be moonsuite-integration.v1",
    errors,
  );
  requireValue(
    manifest?.release_ref_policy === "full-commit-sha",
    "release integration refs must require full commit SHAs",
    errors,
  );
  requireValue(
    Array.isArray(manifest?.repositories) && manifest.repositories.length > 0,
    "integration manifest must contain repositories",
    errors,
  );

  const ids = new Set();
  const roots = new Set();
  const paths = new Set();
  for (const repository of manifest?.repositories ?? []) {
    const prefix = `integration repository ${repository?.id ?? "<missing>"}`;
    requireValue(!ids.has(repository?.id), `${prefix} is duplicated`, errors);
    requireValue(!roots.has(repository?.root_env), `${prefix} reuses a root variable`, errors);
    requireValue(!paths.has(repository?.checkout_path), `${prefix} reuses a checkout path`, errors);
    ids.add(repository?.id);
    roots.add(repository?.root_env);
    paths.add(repository?.checkout_path);
    for (const key of ["repository", "ref", "checkout_path", "root_env", "module"]) {
      requireValue(
        typeof repository?.[key] === "string" && repository[key].length > 0,
        `${prefix} must define ${key}`,
        errors,
      );
    }
    if (workflowText !== undefined) {
      requireValue(
        workflowText.includes(`repository: ${repository.repository}`),
        `${prefix} is missing from CI checkout steps`,
        errors,
      );
      requireValue(
        workflowText.includes(`ref: ${repository.ref}`),
        `${prefix} CI ref differs from the manifest`,
        errors,
      );
      requireValue(
        workflowText.includes(`path: ${repository.checkout_path}`),
        `${prefix} CI checkout path differs from the manifest`,
        errors,
      );
      requireValue(
        workflowText.includes(`${repository.root_env}:`),
        `${prefix} root variable is not supplied to CI validation`,
        errors,
      );
    }
  }
  for (const required of ["moonclaw", "moonbook", "moontown"]) {
    requireValue(ids.has(required), `integration manifest is missing ${required}`, errors);
  }
  return errors;
}

export function loadJson(filename) {
  return JSON.parse(fs.readFileSync(filename, "utf8"));
}

export function verifyRepositoryManifests(repositoryRoot) {
  const capabilityPath = path.join(repositoryRoot, "config/capability-maturity.json");
  const integrationPath = path.join(repositoryRoot, "config/moonsuite-integration.json");
  const workflowPath = path.join(repositoryRoot, ".github/workflows/ci.yml");
  const errors = [
    ...validateCapabilityManifest(loadJson(capabilityPath)),
    ...validateIntegrationManifest(
      loadJson(integrationPath),
      fs.readFileSync(workflowPath, "utf8"),
    ),
  ];
  if (errors.length > 0) {
    throw new Error(errors.map((error) => `- ${error}`).join("\n"));
  }
}

const currentFile = fileURLToPath(import.meta.url);
const invokedFile = process.argv[1] ? path.resolve(process.argv[1]) : "";
if (pathToFileURL(invokedFile).href === pathToFileURL(currentFile).href) {
  const repositoryRoot = path.resolve(path.dirname(currentFile), "..");
  verifyRepositoryManifests(repositoryRoot);
  console.log("MoonSuite maturity and integration manifests passed.");
}
