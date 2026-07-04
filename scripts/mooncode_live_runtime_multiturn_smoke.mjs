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

function sessionTurn(session, commandId) {
  const turns = session?.mooncode_conversation?.turns || [];
  return turns.find(item => item.command_id === commandId);
}

async function waitForReply(base, sessionId, commandId, answer) {
  return await waitFor(`canonical reply for ${commandId}`, async () => {
    await requestJson(
      `${base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-events`,
    );
    const sessions = await requestJson(`${base}/api/mooncode/sessions`);
    const session = sessions.find(item => item.id === sessionId);
    const turn = sessionTurn(session, commandId);
    return turn?.assistant?.content === answer && turn?.status === "done"
      ? { session, turn }
      : null;
  }, 60000);
}

function assertAppendOnlyTurns(session, expected) {
  const turns = session?.mooncode_conversation?.turns || [];
  assert(turns.length === expected.length, `Unexpected turn count: ${JSON.stringify(turns)}`);
  const seen = new Set();
  for (const [index, item] of expected.entries()) {
    const turn = turns[index];
    assert(turn.command_id === item.commandId, `Turn ${index} command id mismatch: ${JSON.stringify(turns)}`);
    assert(turn.user?.content === item.message, `Turn ${index} user mismatch: ${JSON.stringify(turn)}`);
    assert(turn.assistant?.content === item.answer, `Turn ${index} assistant mismatch: ${JSON.stringify(turn)}`);
    assert(turn.status === "done", `Turn ${index} did not finish: ${JSON.stringify(turn)}`);
    assert(!seen.has(turn.command_id), `Duplicate command id in turns: ${JSON.stringify(turns)}`);
    seen.add(turn.command_id);
  }
}

async function runRuntimeService(base, sessionId) {
  await requestJson(
    `${base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/runtime-service`,
    {
      method: "POST",
      body: JSON.stringify({
        consumer_id: "mooncode-live-runtime-multiturn-smoke",
        max_turns: 2,
        live_wait_ms: 0,
        poll_ms: 25,
      }),
    },
  );
}

async function postPrompt(base, sessionId, message, answer, clientTurnId) {
  const result = await requestJson(
    `${base}/api/mooncode/sessions/${encodeURIComponent(sessionId)}/commands`,
    {
      method: "POST",
      body: JSON.stringify({
        action: "prompt",
        message,
        client_turn_id: clientTurnId,
        model: "codex/gpt-5.4",
        web_search: false,
        max_turns: 2,
        live_wait_ms: 0,
        poll_ms: 25,
        runtime_tool_calls: finishCall(answer),
      }),
    },
  );
  assert(result.command_id, `Command response did not include command_id: ${JSON.stringify(result)}`);
  assert(
    (result.command_packet?.runtime_tool_calls || []).length === 1,
    `Command packet did not expose runtime_tool_calls: ${JSON.stringify(result.command_packet)}`,
  );
  return result.command_id;
}

async function runSmoke() {
  await startMoonClaw();
  const moondesk = await startMoondesk();
  const expected = [];

  const first = {
    message: "First deterministic native runtime turn.",
    answer: "First native runtime reply.",
  };
  const created = await requestJson(
    `${moondesk.base}/api/mooncode/sessions`,
    {
      method: "POST",
      body: JSON.stringify({
        title: "MoonCode - Live Runtime Multiturn Smoke",
        message: first.message,
        client_turn_id: "live-runtime-multiturn-client-turn-1",
        model: "codex/gpt-5.4",
        web_search: false,
        max_turns: 2,
        live_wait_ms: 0,
        poll_ms: 25,
        runtime_tool_calls: finishCall(first.answer),
      }),
    },
  );
  const sessionId = created.id;
  const firstCommandId = created.command_id;
  assert(sessionId && firstCommandId, `Created session did not return ids: ${JSON.stringify(created)}`);
  expected.push({ ...first, commandId: firstCommandId });
  await runRuntimeService(moondesk.base, sessionId);
  let state = await waitForReply(moondesk.base, sessionId, firstCommandId, first.answer);
  assertAppendOnlyTurns(state.session, expected);

  const second = {
    message: "Second deterministic native runtime turn.",
    answer: "Second native runtime reply.",
  };
  const secondCommandId = await postPrompt(
    moondesk.base,
    sessionId,
    second.message,
    second.answer,
    "live-runtime-multiturn-client-turn-2",
  );
  expected.push({ ...second, commandId: secondCommandId });
  await runRuntimeService(moondesk.base, sessionId);
  state = await waitForReply(moondesk.base, sessionId, secondCommandId, second.answer);
  assertAppendOnlyTurns(state.session, expected);

  const third = {
    message: "Third deterministic native runtime turn.",
    answer: "Third native runtime reply.",
  };
  const thirdCommandId = await postPrompt(
    moondesk.base,
    sessionId,
    third.message,
    third.answer,
    "live-runtime-multiturn-client-turn-3",
  );
  expected.push({ ...third, commandId: thirdCommandId });
  await runRuntimeService(moondesk.base, sessionId);
  state = await waitForReply(moondesk.base, sessionId, thirdCommandId, third.answer);
  assertAppendOnlyTurns(state.session, expected);

  assert(
    !fs.existsSync(path.join(suiteRoot, ".moonclaw")),
    "Live runtime multiturn smoke created legacy .moonclaw root",
  );
  console.log(JSON.stringify({
    ok: true,
    suite_root: suiteRoot,
    moondesk: moondesk.base,
    session_id: sessionId,
    command_ids: expected.map(item => item.commandId),
    turn_count: expected.length,
  }, null, 2));
}

try {
  await runSmoke();
} finally {
  cleanupProcesses();
}
