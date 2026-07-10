import fs from "node:fs";
import path from "node:path";
import {
  acceptedCommandId,
  assert,
  cleanupProcesses,
  fetchCanonicalSession,
  requestJson,
  startMoondesk,
  suiteRoot,
  waitFor,
} from "./mooncode_live_runtime_smoke_lib.mjs";

function turnByCommand(session, commandId) {
  return (session?.mooncode_conversation?.turns || []).find(
    item => item.command_id === commandId,
  );
}

async function runSmoke() {
  const moondesk = await startMoondesk();
  const created = await requestJson(
    `${moondesk.base}/api/mooncode/sessions`,
    {
      method: "POST",
      body: JSON.stringify({
        title: "MoonCode - Runtime Failure Smoke",
        message: "Prove runtime-service failure becomes a visible reply.",
        client_turn_id: "runtime-service-failure-client-turn-1",
        model: "codex/gpt-5.4",
        web_search: false,
      }),
    },
  );
  const sessionId = created.id;
  const commandId = acceptedCommandId(created);
  assert(sessionId && commandId, `Created session did not return ids: ${JSON.stringify(created)}`);
  assert(created.status === "queued", `Create response should stay queued: ${JSON.stringify(created)}`);
  const initialTurn = turnByCommand(created, commandId);
  assert(initialTurn?.status === "queued", `Initial turn should be queued: ${JSON.stringify(created)}`);
  assert(!initialTurn?.assistant?.content, `Submit path should not fabricate an assistant reply: ${JSON.stringify(initialTurn)}`);

  const runtimeFailure = await requestJson(
    `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-service`,
    {
      method: "POST",
      body: JSON.stringify({
        consumer_id: "mooncode-runtime-service-failure-smoke",
        max_turns: 1,
        live_wait_ms: 0,
        poll_ms: 25,
      }),
    },
    [409, 502],
  );
  assert(runtimeFailure.ok === false, `Runtime-service failure should be an API error: ${JSON.stringify(runtimeFailure)}`);

  const projected = await waitFor("durable runtime failure projection", async () => {
    const session = await fetchCanonicalSession(moondesk.base, sessionId);
    const turn = turnByCommand(session, commandId);
    return turn?.status === "failed" && turn?.assistant?.status === "failed"
      ? { session, turn }
      : null;
  }, 10000);
  assert(
    projected.turn.assistant.content.includes("MoonClaw"),
    `Failed assistant content should explain the MoonClaw runtime failure: ${JSON.stringify(projected.turn)}`,
  );
  assert(
    projected.session.mooncode_summary?.append_log_count === 2,
    `Expected prompt plus one runtime failure event: ${JSON.stringify(projected.session)}`,
  );
  assert(
    !fs.existsSync(path.join(suiteRoot, ".moonclaw")),
    "Runtime-service failure smoke created legacy .moonclaw root",
  );
  console.log(JSON.stringify({
    ok: true,
    suite_root: suiteRoot,
    moondesk: moondesk.base,
    session_id: sessionId,
    command_id: commandId,
    turn_status: projected.turn.status,
    assistant_status: projected.turn.assistant.status,
  }, null, 2));
}

try {
  await runSmoke();
} finally {
  cleanupProcesses();
}
