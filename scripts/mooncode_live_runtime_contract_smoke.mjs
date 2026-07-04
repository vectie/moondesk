import fs from "node:fs";
import path from "node:path";
import {
  assert,
  cleanupProcesses,
  requestJson,
  startMoonClaw,
  startMoondesk,
  suiteRoot,
  waitFor,
} from "./mooncode_live_runtime_smoke_lib.mjs";

async function runSmoke() {
  const moonclaw = await startMoonClaw();
  const moondesk = await startMoondesk();
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
      }),
    },
  );
  const sessionId = created.id;
  const commandId = created.command_id;
  assert(sessionId && commandId, `Created session did not return ids: ${JSON.stringify(created)}`);

  const reply = "Live MoonClaw runtime contract smoke reply.";
  const nativePost = await requestJson(
    `${moonclaw.base}/v1/code/sessions/${encodeURIComponent(sessionId)}/runtime-events?book_root=${encodeURIComponent(suiteRoot)}`,
    {
      method: "POST",
      body: JSON.stringify({
        events: [
          {
            event: "assistant_message",
            id: "live-native-assistant-1",
            created_at: "2026-07-04T00:00:00Z",
            content: reply,
            command_id: commandId,
            action: "prompt",
            session_id: sessionId,
          },
        ],
      }),
    },
    [202],
  );
  assert(nativePost.owner === "moonclaw", `Native event owner mismatch: ${JSON.stringify(nativePost)}`);
  assert(nativePost.event_count === 1, `Native event count mismatch: ${JSON.stringify(nativePost)}`);

  const runtimeState = await waitFor("Moondesk native runtime contract import", async () => {
    const state = await requestJson(
      `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-events`,
    );
    const safe = state.native_runtime_contract_projection_safe === true &&
      state.native_runtime_contract_status === "projection-safe" &&
      state.native_runtime_contract_unscoped_projection_event_count === 0 &&
      state.native_event_count >= 1;
    return safe ? state : null;
  }, 20000);

  const sessions = await requestJson(`${moondesk.base}/api/mooncode/sessions`);
  const session = sessions.find(item => item.id === sessionId);
  assert(session, `Moondesk session missing after native import: ${JSON.stringify(sessions)}`);
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
