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
  await startMoonClaw();
  const moondesk = await startMoondesk();
  const proofPath = "tools/live-runtime-loop/proof.txt";
  const proofText = "phase18 native runtime loop proof";
  const reply = "Live MoonClaw runtime loop completed.";

  const created = await requestJson(
    `${moondesk.base}/api/mooncode/sessions`,
    {
      method: "POST",
      body: JSON.stringify({
        title: "MoonCode - Live Runtime Loop Smoke",
        message: "Create a deterministic runtime-loop proof.",
        client_turn_id: "live-runtime-loop-client-turn",
        model: "codex/gpt-5.4",
        web_search: false,
        max_turns: 2,
        live_wait_ms: 0,
        poll_ms: 25,
        runtime_tool_calls: [
          {
            tool: "write",
            arguments: {
              path: proofPath,
              content: proofText,
            },
          },
          {
            tool: "finish",
            arguments: {
              answer: reply,
            },
          },
        ],
      }),
    },
  );
  const sessionId = created.id;
  const commandId = created.command_id;
  assert(sessionId && commandId, `Created session did not return ids: ${JSON.stringify(created)}`);
  assert(
    (created.command_packet?.runtime_tool_calls || []).length === 2,
    `Created command packet did not expose runtime_tool_calls: ${JSON.stringify(created.command_packet)}`,
  );
  await requestJson(
    `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-service`,
    {
      method: "POST",
      body: JSON.stringify({
        consumer_id: "mooncode-live-runtime-loop-smoke",
        max_turns: 2,
        live_wait_ms: 0,
        poll_ms: 25,
      }),
    },
  );

  const proofFile = path.join(suiteRoot, proofPath);
  const finalState = await waitFor("MoonClaw loop proof and canonical reply", async () => {
    await requestJson(
      `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-events`,
    );
    const sessions = await requestJson(`${moondesk.base}/api/mooncode/sessions`);
    const session = sessions.find(item => item.id === sessionId);
    const turns = session?.mooncode_conversation?.turns || [];
    const turn = turns.find(item => item.command_id === commandId);
    const proofReady = fs.existsSync(proofFile) &&
      fs.readFileSync(proofFile, "utf8") === proofText;
    return proofReady && turn?.assistant?.content === reply
      ? { session, turn }
      : null;
  }, 60000);

  assert(
    !fs.existsSync(path.join(suiteRoot, ".moonclaw")),
    "Live runtime loop smoke created legacy .moonclaw root",
  );
  const restarted = await requestJson(
    `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-service`,
    {
      method: "POST",
      body: JSON.stringify({
        consumer_id: "mooncode-live-runtime-loop-smoke-restart",
        max_turns: 1,
        live_wait_ms: 0,
        poll_ms: 25,
      }),
    },
  );
  const restartEvent = (restarted.mooncode_events || []).find(
    item => item.kind === "runtime.service_started" &&
      item.consumer_id === "mooncode-live-runtime-loop-smoke-restart",
  );
  assert(
    restartEvent?.status === "running",
    `Terminal native service events should release the Moondesk runtime-service lease: ${JSON.stringify(restarted)}`,
  );
  console.log(JSON.stringify({
    ok: true,
    suite_root: suiteRoot,
    moondesk: moondesk.base,
    session_id: sessionId,
    command_id: commandId,
    status: finalState.turn.status,
    proof_path: proofFile,
    restart_service_id: restartEvent.service_id,
  }, null, 2));
}

try {
  await runSmoke();
} finally {
  cleanupProcesses();
}
