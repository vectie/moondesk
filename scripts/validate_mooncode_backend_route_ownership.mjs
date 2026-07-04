import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const routeContractsPath = path.join(repoRoot, "internal/mooncode/route_contracts.mbt");
const routerPath = path.join(repoRoot, "internal/moonwiki/api_mooncode_router.mbt");
const backendRouteTestPath = path.join(
  repoRoot,
  "internal/moonwiki/mooncode_backend_route_contract_wbtest.mbt",
);

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function read(file) {
  return fs.readFileSync(file, "utf8");
}

function collectUnique(label, text, regex) {
  const values = [...text.matchAll(regex)].map(match => match[1]);
  const unique = [...new Set(values)].sort();
  const duplicates = values.filter((value, index) => values.indexOf(value) !== index);
  assert(unique.length > 20, `${label} exposed too few route helpers: ${unique.length}`);
  assert(duplicates.length === 0, `${label} has duplicate route helpers: ${duplicates.join(", ")}`);
  return unique;
}

function assertSameSet(leftLabel, left, rightLabel, right) {
  const missing = left.filter(value => !right.includes(value));
  const extra = right.filter(value => !left.includes(value));
  assert(
    missing.length === 0 && extra.length === 0,
    [
      `${leftLabel} and ${rightLabel} route helpers differ`,
      missing.length ? `missing from ${rightLabel}: ${missing.join(", ")}` : "",
      extra.length ? `extra in ${rightLabel}: ${extra.join(", ")}` : "",
    ].filter(Boolean).join("\n"),
  );
}

const routeContracts = read(routeContractsPath);
const router = read(routerPath);
const backendRouteTest = read(backendRouteTestPath);

const contractHelpers = collectUnique(
  "desktop_projection_route_contracts",
  routeContracts,
  /desktop_route_contract\(\s*(desktop_[A-Za-z0-9_]+_endpoint)\(\)/g,
);
const routerHelpers = collectUnique(
  "api_mooncode_router",
  router,
  /let\s+endpoint\s*=\s*@mooncode\.(desktop_[A-Za-z0-9_]+_endpoint)\(\)/g,
);

assertSameSet("desktop_projection_route_contracts", contractHelpers, "api_mooncode_router", routerHelpers);

assert(
  !backendRouteTest.includes("mooncode_backend_router_route_contracts") &&
    !backendRouteTest.includes("mooncode_backend_route_contract(") &&
    !backendRouteTest.includes("\"/api/mooncode"),
  "MoonCode backend route contract test must not reintroduce a static route mirror",
);

assert(
  !router.includes("\"/api/mooncode"),
  "MoonCode router must route by segments and endpoint helpers, not raw /api/mooncode strings",
);

console.log(JSON.stringify({
  ok: true,
  contract_route_count: contractHelpers.length,
  router_route_count: routerHelpers.length,
}, null, 2));
