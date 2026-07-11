import fs from "node:fs";
import path from "node:path";
import {
  acceptedCommandId,
  assert,
  cleanupProcesses,
  fetchCanonicalSession,
  requestJson,
  startMoonClaw,
  startMoondesk,
  suiteRoot,
  waitFor,
} from "./mooncode_live_runtime_smoke_lib.mjs";

async function runSmoke() {
  const moonclaw = await startMoonClaw();
  const moondesk = await startMoondesk();
  const reply = "Live MoonClaw runtime contract smoke reply.";
  const created = await requestJson(
    `${moondesk.base}/api/mooncode/sessions`,
    {
      method: "POST",
      body: JSON.stringify({
        title: "MoonCode - Live Runtime Contract Smoke",
        message: "Live runtime contract smoke",
        client_turn_id: "live-runtime-contract-client-turn",
        model: "codex/gpt-5.4",
        web_search: false,
        max_turns: 1,
        live_wait_ms: 0,
        poll_ms: 25,
        runtime_tool_calls: [
          {
            tool: "finish",
            arguments: { answer: reply },
          },
        ],
      }),
    },
  );
  const sessionId = created.id;
  const commandId = acceptedCommandId(created);
  assert(sessionId && commandId, `Created session did not return ids: ${JSON.stringify(created)}`);

  const runtimeState = await waitFor("MoonDesk native runtime contract import", async () => {
    const state = await requestJson(
      `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-events`,
    );
    const safe = state.native_runtime_contract_projection_safe === true &&
      state.native_runtime_contract_status === "projection-safe" &&
      state.native_runtime_contract_unscoped_projection_event_count === 0 &&
      state.native_event_count >= 1;
    return safe ? state : null;
  }, 20000);

  const session = await fetchCanonicalSession(moondesk.base, sessionId);
  assert(session?.id === sessionId, `MoonDesk session missing after native import: ${JSON.stringify(session)}`);
  const turns = session.mooncode_conversation?.turns || [];
  const turn = turns.find(item => item.command_id === commandId);
  assert(turn?.assistant?.content === reply, `Native reply was not canonical conversation output: ${JSON.stringify(turns)}`);
  assert(
    !fs.existsSync(path.join(suiteRoot, ".moonclaw")),
    "Live runtime smoke created legacy .moonclaw root",
  );
  console.log(JSON.stringify({
    ok: true,
    suite_root: suiteRoot,
    moondesk: moondesk.base,
    moonclaw: moonclaw.base,
    session_id: sessionId,
    command_id: commandId,
    native_runtime_contract_status: runtimeState.native_runtime_contract_status,
  }, null, 2));
}

try {
  await runSmoke();
} finally {
  cleanupProcesses();
}
