import {
  assert,
  cleanupProcesses,
  requestJson,
  startMoonClaw,
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

function instantiateRoutePath(path, sessionId) {
  return path.replaceAll("<session-id>", encodeURIComponent(sessionId));
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
  await startMoonClaw();
  const moondesk = await startMoondesk();
  const capabilities = await requestJson(
    `${moondesk.base}/api/mooncode/capabilities`,
  );
  const routeContracts = capabilities.desktop_route_contracts;
  assert(
    Array.isArray(routeContracts) && routeContracts.length > 20,
    `Capabilities did not publish desktop route contracts: ${JSON.stringify(capabilities)}`,
  );
  const created = await requestJson(
    `${moondesk.base}/api/mooncode/sessions`,
    {
      method: "POST",
      body: JSON.stringify({
        title: "MoonCode - HTTP Method Contract Smoke",
        message: "Create a session before probing method contracts.",
        client_turn_id: "http-method-contract-client-turn-1",
        model: "codex/gpt-5.4",
        web_search: false,
        runtime_tool_calls: [
          {
            tool: "finish",
            arguments: { answer: "HTTP method contract session ready." },
          },
        ],
      }),
    },
  );
  const sessionId = created.id;
  assert(sessionId, `Created session did not return id: ${JSON.stringify(created)}`);

  const headStatus = await fetch(`${moondesk.base}/api/mooncode/status`, {
    method: "HEAD",
  });
  assert(
    headStatus.status === 200,
    `HEAD /api/mooncode/status should be accepted, got ${headStatus.status}`,
  );

  const checkedRoutes = [];
  for (const contract of routeContracts) {
    const path = String(contract.path || "");
    assert(
      path.startsWith("/api/mooncode/"),
      `Unexpected desktop route path: ${JSON.stringify(contract)}`,
    );
    const methods = routeMethods(contract);
    const method = unsupportedMethod(methods);
    await requestMethodContract405(
      `${moondesk.base}${instantiateRoutePath(path, sessionId)}`,
      method,
      methods,
    );
    checkedRoutes.push(`${method} ${path} -> 405`);
  }

  console.log(JSON.stringify({
    ok: true,
    suite_root: suiteRoot,
    moondesk: moondesk.base,
    session_id: sessionId,
    checked_route_count: checkedRoutes.length,
    checked: ["HEAD /api/mooncode/status", ...checkedRoutes],
  }, null, 2));
}

try {
  await runSmoke();
} finally {
  cleanupProcesses();
}
