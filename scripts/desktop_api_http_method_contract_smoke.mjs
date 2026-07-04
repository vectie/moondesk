import {
  assert,
  cleanupProcesses,
  requestJson,
  startMoondesk,
  suiteRoot,
} from "./mooncode_live_runtime_smoke_lib.mjs";

function findAllowedMethods(value) {
  if (!value || typeof value !== "object") {
    return null;
  }
  if (Array.isArray(value.allowed_methods)) {
    return value.allowed_methods;
  }
  for (const nested of Object.values(value)) {
    const found = findAllowedMethods(nested);
    if (found) {
      return found;
    }
  }
  return null;
}

function routeMethods(contract) {
  assert(
    Array.isArray(contract.methods) && contract.methods.length > 0,
    `Route contract has no methods: ${JSON.stringify(contract)}`,
  );
  return contract.methods.map(method => String(method).trim()).filter(Boolean);
}

function instantiateDesktopRoutePath(path) {
  return path
    .replaceAll("<workspace-id>", encodeURIComponent("book-contract-smoke"))
    .replaceAll("<run-id>", encodeURIComponent("run-contract-smoke"))
    .replaceAll("<path>", "docs/contract-smoke.md");
}

function unsupportedMethod(methods) {
  if (!methods.includes("GET")) {
    return "GET";
  }
  if (!methods.includes("POST")) {
    return "POST";
  }
  return "PUT";
}

function capabilityStringArray(capabilities, field) {
  const value = capabilities[field];
  assert(
    Array.isArray(value),
    `Desktop capabilities did not publish ${field}: ${JSON.stringify(capabilities)}`,
  );
  return value.map(item => String(item));
}

function assertIncludesAll(haystack, needles, label) {
  for (const needle of needles) {
    assert(
      haystack.includes(needle),
      `${label} is missing ${needle}: ${JSON.stringify(haystack)}`,
    );
  }
}

async function requestMethodContract405(url, method, expectedMethods) {
  const response = await fetch(url, { method });
  const text = await response.text();
  let body = {};
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    throw new Error(`Expected JSON 405 body for ${method} ${url}: ${text}`);
  }
  const expectedAllow = expectedMethods.join(", ");
  assert(
    response.status === 405,
    `Expected HTTP 405 for ${method} ${url}, got ${response.status}: ${text}`,
  );
  assert(
    response.headers.get("allow") === expectedAllow,
    `Allow header mismatch for ${method} ${url}: ${
      response.headers.get("allow")
    }`,
  );
  const allowedMethods = findAllowedMethods(body);
  assert(
    JSON.stringify(allowedMethods) === JSON.stringify(expectedMethods),
    `allowed_methods mismatch for ${method} ${url}: ${JSON.stringify(body)}`,
  );
  assert(
    body.ok === false &&
      body.status === "error" &&
      body.api_contract === "moonsuite.phase6.v1" &&
      body.next_action === "inspect_request",
    `405 body lost API contract fields for ${method} ${url}: ${JSON.stringify(body)}`,
  );
}

async function runSmoke() {
  const moondesk = await startMoondesk();
  const capabilities = await requestJson(
    `${moondesk.base}/api/desktop/capabilities`,
  );
  assert(
    capabilities.component === "moondesk-desktop-api" &&
      capabilities.kind === "moondesk-desktop-api-capabilities.v1" &&
      capabilities.api_contract === "moonsuite.phase6.v1",
    `Desktop capabilities payload lost contract fields: ${JSON.stringify(capabilities)}`,
  );
  const routeContracts = capabilities.desktop_route_contracts;
  assert(
    Array.isArray(routeContracts) && routeContracts.length > 40,
    `Capabilities did not publish desktop route contracts: ${JSON.stringify(capabilities)}`,
  );
  const endpoints = routeContracts.map(contract => String(contract.path || ""));
  assert(
    endpoints.includes("/api/desktop/capabilities"),
    "Capabilities route must publish itself",
  );
  assert(
    endpoints.includes("/api/town/dispatch"),
    "Active town dispatch route is missing from desktop route contracts",
  );
  assert(
    !endpoints.includes("/api/town/control"),
    "Retired town control route must not be published",
  );

  const portableSnapshotRoutes = capabilityStringArray(
    capabilities,
    "portable_api_snapshot_routes",
  );
  const portableWorkspaceContentRoutes = capabilityStringArray(
    capabilities,
    "portable_api_workspace_content_routes",
  );
  const portableSupportedPatterns = capabilityStringArray(
    capabilities,
    "portable_api_supported_route_patterns",
  );
  assertIncludesAll(portableSnapshotRoutes, [
    "/api/workspaces",
    "/api/books/patterns",
    "/api/books/base-types",
    "/api/books/template-registry",
  ], "portable_api_snapshot_routes");
  assertIncludesAll(portableWorkspaceContentRoutes, [
    "/api/workspaces/<workspace-id>/entries",
    "/api/workspaces/<workspace-id>/preview",
    "/api/workspaces/<workspace-id>/raw",
    "/api/workspaces/<workspace-id>/file/<path>",
    "/api/workspaces/<workspace-id>/site/<path>",
  ], "portable_api_workspace_content_routes");
  assertIncludesAll(portableSupportedPatterns, [
    ...portableSnapshotRoutes,
    ...portableWorkspaceContentRoutes,
  ], "portable_api_supported_route_patterns");
  assert(
    !portableSupportedPatterns.includes("/api/town/progress") &&
      !portableSupportedPatterns.includes("/api/town/dispatch"),
    `portable_api_supported_route_patterns must stay offline-only: ${
      JSON.stringify(portableSupportedPatterns)
    }`,
  );

  const headCapabilities = await fetch(
    `${moondesk.base}/api/desktop/capabilities`,
    { method: "HEAD" },
  );
  assert(
    headCapabilities.status === 200,
    `HEAD /api/desktop/capabilities should be accepted, got ${headCapabilities.status}`,
  );

  const retiredControl = await fetch(`${moondesk.base}/api/town/control`, {
    method: "POST",
  });
  assert(
    retiredControl.status === 404,
    `POST /api/town/control should stay retired, got ${retiredControl.status}`,
  );

  const checkedRoutes = [];
  for (const contract of routeContracts) {
    const path = String(contract.path || "");
    assert(path.startsWith("/api/"), `Unexpected desktop route path: ${path}`);
    const methods = routeMethods(contract);
    const method = unsupportedMethod(methods);
    await requestMethodContract405(
      `${moondesk.base}${instantiateDesktopRoutePath(path)}`,
      method,
      methods,
    );
    checkedRoutes.push(`${method} ${path} -> 405`);
  }

  console.log(JSON.stringify({
    ok: true,
    suite_root: suiteRoot,
    moondesk: moondesk.base,
    checked_route_count: checkedRoutes.length,
    checked: [
      "HEAD /api/desktop/capabilities",
      "portable API route contract publication",
      "POST /api/town/control -> 404",
      ...checkedRoutes,
    ],
  }, null, 2));
}

try {
  await runSmoke();
} finally {
  cleanupProcesses();
}
