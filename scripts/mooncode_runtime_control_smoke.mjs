import fs from "node:fs";
import path from "node:path";
import {
  acceptedCommandId,
  assert,
  cleanupProcesses,
  requestJson,
  startMoondesk,
  suiteRoot,
} from "./mooncode_live_runtime_smoke_lib.mjs";

function decisionByCommand(control, commandId) {
  return (control?.decisions || []).find(item => item.command_id === commandId);
}

async function postCommand(base, sessionId, action, message, clientTurnId) {
  const result = await requestJson(
    `${base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/commands`,
    {
      method: "POST",
      body: JSON.stringify({
        action,
        message,
        client_turn_id: clientTurnId,
        model: "codex/gpt-5.4",
        web_search: false,
      }),
    },
  );
  const commandId = acceptedCommandId(result);
  assert(commandId, `Command response missing canonical command identity: ${JSON.stringify(result)}`);
  return commandId;
}

async function runSmoke() {
  const moondesk = await startMoondesk();
  const created = await requestJson(
    `${moondesk.base}/api/mooncode/sessions`,
    {
      method: "POST",
      body: JSON.stringify({
        title: "MoonCode - Runtime Control Smoke",
        message: "Start a pending control smoke turn.",
        client_turn_id: "runtime-control-client-turn-1",
        model: "codex/gpt-5.4",
        web_search: false,
      }),
    },
  );
  const sessionId = created.id;
  const promptCommandId = acceptedCommandId(created);
  assert(sessionId && promptCommandId, `Created session did not return ids: ${JSON.stringify(created)}`);
  assert(created.status === "queued", `Create response should stay queued before explicit runtime start: ${JSON.stringify(created)}`);

  const steerCommandId = await postCommand(
    moondesk.base,
    sessionId,
    "steer",
    "Keep this turn focused on the append-only control contract.",
    "runtime-control-client-steer-1",
  );
  const cancelCommandId = await postCommand(
    moondesk.base,
    sessionId,
    "cancel",
    "Withdraw the pending turn before MoonClaw starts.",
    "runtime-control-client-cancel-1",
  );

  const commandQueue = await requestJson(
    `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/commands`,
  );
  const actions = (commandQueue.commands || []).map(item => item.action);
  assert(
    JSON.stringify(actions) === JSON.stringify(["prompt", "steer", "cancel"]),
    `Command queue order mismatch: ${JSON.stringify(commandQueue.commands)}`,
  );

  const runtimeFeed = await requestJson(
    `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-commands`,
  );
  assert(runtimeFeed.runtime_command_count === 3, `Runtime command count mismatch: ${JSON.stringify(runtimeFeed)}`);
  assert(
    JSON.stringify((runtimeFeed.commands || []).map(item => item.command_id)) ===
      JSON.stringify([promptCommandId, steerCommandId, cancelCommandId]),
    `Runtime command id order mismatch: ${JSON.stringify(runtimeFeed.commands)}`,
  );

  const control = await requestJson(
    `${moondesk.base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-control`,
  );
  const promptDecision = decisionByCommand(control, promptCommandId);
  const steerDecision = decisionByCommand(control, steerCommandId);
  const cancelDecision = decisionByCommand(control, cancelCommandId);
  assert(promptDecision?.effect === "start-turn", `Prompt decision mismatch: ${JSON.stringify(control)}`);
  assert(steerDecision?.effect === "queue-steer", `Steer decision mismatch: ${JSON.stringify(control)}`);
  assert(steerDecision?.target_command_id === promptCommandId, `Steer target mismatch: ${JSON.stringify(control)}`);
  assert(cancelDecision?.effect === "withdraw-pending", `Cancel decision mismatch: ${JSON.stringify(control)}`);
  assert(cancelDecision?.target_command_id === promptCommandId, `Cancel target mismatch: ${JSON.stringify(control)}`);

  assert(
    !fs.existsSync(path.join(suiteRoot, ".moonclaw")),
    "Runtime control smoke created legacy .moonclaw root",
  );
  console.log(JSON.stringify({
    ok: true,
    suite_root: suiteRoot,
    moondesk: moondesk.base,
    session_id: sessionId,
    command_ids: [promptCommandId, steerCommandId, cancelCommandId],
    effects: [promptDecision.effect, steerDecision.effect, cancelDecision.effect],
  }, null, 2));
}

try {
  await runSmoke();
} finally {
  cleanupProcesses();
}
