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

function finishCall(answer) {
  return [{ tool: "finish", arguments: { answer } }];
}

async function startService(base, sessionId, consumerId) {
  return await requestJson(
    `${base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-service`,
    {
      method: "POST",
      body: JSON.stringify({
        consumer_id: consumerId,
        max_turns: 4,
        live_wait_ms: 0,
        poll_ms: 25,
      }),
    },
  );
}

async function postCommand(base, sessionId, body) {
  const result = await requestJson(
    `${base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/commands`,
    { method: "POST", body: JSON.stringify(body) },
  );
  assert(result.command_id, `Command response missing command_id: ${JSON.stringify(result)}`);
  return result;
}

async function fetchSession(base, sessionId) {
  await requestJson(
    `${base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-events`,
  );
  const sessions = await requestJson(`${base}/api/mooncode/sessions`);
  return sessions.find(item => item.id === sessionId);
}

function sessionTurn(session, commandId) {
  return (session?.mooncode_conversation?.turns || []).find(
    item => item.command_id === commandId,
  );
}

async function waitForReply(base, sessionId, commandId, answer) {
  return await waitFor(`canonical reply for ${commandId}`, async () => {
    const session = await fetchSession(base, sessionId);
    const turn = sessionTurn(session, commandId);
    return turn?.assistant?.content === answer && turn?.status === "done"
      ? { session, turn }
      : null;
  }, 60000);
}

async function waitForEvent(base, sessionId, kind, commandId) {
  return await waitFor(`${kind} for ${commandId}`, async () => {
    const events = await requestJson(
      `${base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-events`,
    );
    const found = (events.events || []).find(
      item => item.kind === kind &&
        (item.command_id === commandId || item.command_packet?.command_id === commandId),
    );
    const session = await fetchSession(base, sessionId);
    return found ? { event: found, session } : null;
  }, 60000);
}

function assertPromptOnlyConversation(session, expected, blockedText) {
  const turns = session?.mooncode_conversation?.turns || [];
  assert(turns.length === expected.length, `Unexpected conversation turn count: ${JSON.stringify(turns)}`);
  for (const [index, item] of expected.entries()) {
    const turn = turns[index];
    assert(turn.command_id === item.commandId, `Turn ${index} command mismatch: ${JSON.stringify(turns)}`);
    assert(turn.user?.content === item.message, `Turn ${index} user mismatch: ${JSON.stringify(turn)}`);
    assert(turn.assistant?.content === item.answer, `Turn ${index} assistant mismatch: ${JSON.stringify(turn)}`);
    assert(turn.status === "done", `Turn ${index} status mismatch: ${JSON.stringify(turn)}`);
  }
  const rendered = JSON.stringify(session?.mooncode_conversation || {});
  for (const text of blockedText) {
    assert(!rendered.includes(text), `Control text leaked into conversation: ${text}\n${rendered}`);
  }
}

async function runSmoke() {
  await startMoonClaw();
  const moondesk = await startMoondesk();
  const first = {
    message: "First prompt for the control boundary smoke.",
    answer: "First boundary reply.",
  };
  const steerText = "Keep the follow-up focused on scheduler-boundary control.";
  const second = {
    message: "Second prompt after deferred steering.",
    answer: "Second boundary reply.",
  };
  const cancelText = "Cancel after the prompt turns have settled.";

  const created = await requestJson(
    `${moondesk.base}/api/mooncode/sessions`,
    {
      method: "POST",
      body: JSON.stringify({
        title: "MoonCode - Runtime Control Boundary Smoke",
        message: first.message,
        client_turn_id: "runtime-boundary-client-turn-1",
        model: "codex/gpt-5.4",
        web_search: false,
        runtime_tool_calls: finishCall(first.answer),
      }),
    },
  );
  const sessionId = created.id;
  const firstCommandId = created.command_id;
  assert(sessionId && firstCommandId, `Created session missing ids: ${JSON.stringify(created)}`);
  await startService(moondesk.base, sessionId, "mooncode-control-boundary-first");
  let state = await waitForReply(moondesk.base, sessionId, firstCommandId, first.answer);

  const steer = await postCommand(moondesk.base, sessionId, {
    action: "steer",
    message: steerText,
    client_turn_id: "runtime-boundary-client-steer",
    model: "codex/gpt-5.4",
    web_search: false,
  });
  await startService(moondesk.base, sessionId, "mooncode-control-boundary-steer");
  state = await waitForEvent(moondesk.base, sessionId, "steer_deferred", steer.command_id);
  assertPromptOnlyConversation(
    state.session,
    [{ commandId: firstCommandId, message: first.message, answer: first.answer }],
    [steerText, cancelText],
  );

  const secondCommand = await postCommand(moondesk.base, sessionId, {
    action: "prompt",
    message: second.message,
    client_turn_id: "runtime-boundary-client-turn-2",
    model: "codex/gpt-5.4",
    web_search: false,
    runtime_tool_calls: finishCall(second.answer),
  });
  await startService(moondesk.base, sessionId, "mooncode-control-boundary-second");
  state = await waitForReply(moondesk.base, sessionId, secondCommand.command_id, second.answer);
  state = await waitForEvent(moondesk.base, sessionId, "steer_applied", steer.command_id);

  const cancel = await postCommand(moondesk.base, sessionId, {
    action: "cancel",
    message: cancelText,
    client_turn_id: "runtime-boundary-client-cancel",
    model: "codex/gpt-5.4",
    web_search: false,
  });
  await startService(moondesk.base, sessionId, "mooncode-control-boundary-cancel");
  state = await waitForEvent(moondesk.base, sessionId, "cancel_dropped", cancel.command_id);
  assertPromptOnlyConversation(
    state.session,
    [
      { commandId: firstCommandId, message: first.message, answer: first.answer },
      { commandId: secondCommand.command_id, message: second.message, answer: second.answer },
    ],
    [steerText, cancelText],
  );

  const lifecycle = state.session?.mooncode_summary?.steering_lifecycle || {};
  assert(lifecycle.latest_status === "applied", `Steering lifecycle did not settle as applied: ${JSON.stringify(lifecycle)}`);
  assert(
    !fs.existsSync(path.join(suiteRoot, ".moonclaw")),
    "Runtime control boundary smoke created legacy .moonclaw root",
  );
  console.log(JSON.stringify({
    ok: true,
    suite_root: suiteRoot,
    moondesk: moondesk.base,
    session_id: sessionId,
    prompt_command_ids: [firstCommandId, secondCommand.command_id],
    steer_command_id: steer.command_id,
    cancel_command_id: cancel.command_id,
    steering_status: lifecycle.latest_status,
  }, null, 2));
}

try {
  await runSmoke();
} finally {
  cleanupProcesses();
}
