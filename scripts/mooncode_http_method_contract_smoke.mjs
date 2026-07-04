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

  await requestMethodContract405(
    `${moondesk.base}/api/mooncode/status`,
    "POST",
    ["GET", "HEAD"],
  );
  await requestMethodContract405(
    `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-service`,
    "GET",
    ["POST"],
  );
  await requestMethodContract405(
    `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/commands`,
    "PUT",
    ["GET", "HEAD", "POST"],
  );

  console.log(JSON.stringify({
    ok: true,
    suite_root: suiteRoot,
    moondesk: moondesk.base,
    session_id: sessionId,
    checked: [
      "HEAD /api/mooncode/status",
      "POST /api/mooncode/status -> 405",
      "GET /api/mooncode/sessions/:id/runtime-service -> 405",
      "PUT /api/mooncode/sessions/:id/commands -> 405",
    ],
  }, null, 2));
}

try {
  await runSmoke();
} finally {
  cleanupProcesses();
}
