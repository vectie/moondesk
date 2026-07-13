import fs from "node:fs";
import path from "node:path";

const [baseUrl, cdpPort, fixtureRoot, scenario = "full"] = process.argv.slice(2);

if (!baseUrl || !cdpPort || !fixtureRoot) {
  throw new Error("usage: desk_mode_browser_smoke.mjs <base-url> <cdp-port> <fixture-root> [full|empty]");
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

class CdpSession {
  constructor(ws) {
    this.ws = ws;
    this.nextId = 1;
    this.pending = new Map();
    this.pageProblems = [];
    ws.addEventListener("message", event => {
      const message = JSON.parse(event.data);
      if (!message.id || !this.pending.has(message.id)) {
        this.recordPageProblem(message);
        return;
      }
      const { resolve, reject } = this.pending.get(message.id);
      this.pending.delete(message.id);
      if (message.error) {
        reject(new Error(JSON.stringify(message.error)));
      } else {
        resolve(message.result ?? {});
      }
    });
  }

  recordPageProblem(message) {
    if (message.method === "Runtime.exceptionThrown") {
      const details = message.params?.exceptionDetails ?? {};
      this.pageProblems.push({
        kind: "exception",
        text: details.text || details.exception?.description || "runtime exception",
        url: details.url || "",
        line: details.lineNumber ?? 0,
        column: details.columnNumber ?? 0,
      });
    } else if (message.method === "Runtime.consoleAPICalled") {
      const params = message.params ?? {};
      if (params.type === "error" || params.type === "assert") {
        this.pageProblems.push({
          kind: `console.${params.type}`,
          text: (params.args ?? []).map(arg => remoteObjectText(arg)).join(" "),
          url: params.stackTrace?.callFrames?.[0]?.url || "",
          line: params.stackTrace?.callFrames?.[0]?.lineNumber ?? 0,
          column: params.stackTrace?.callFrames?.[0]?.columnNumber ?? 0,
        });
      }
    } else if (message.method === "Log.entryAdded") {
      const entry = message.params?.entry ?? {};
      if (entry.level === "error") {
        this.pageProblems.push({
          kind: "log.error",
          text: entry.text || "",
          url: entry.url || "",
          line: entry.lineNumber ?? 0,
          column: 0,
        });
      }
    }
  }

  clearPageProblems() {
    this.pageProblems = [];
  }

  assertNoPageProblems(label) {
    assert(
      this.pageProblems.length === 0,
      `${label} browser console/runtime errors: ${JSON.stringify(this.pageProblems)}`,
    );
  }

  send(method, params = {}) {
    const id = this.nextId++;
    const payload = JSON.stringify({ id, method, params });
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
      this.ws.send(payload);
    });
  }

  async evaluate(expression) {
    const result = await this.send("Runtime.evaluate", {
      expression,
      awaitPromise: true,
      returnByValue: true,
    });
    if (result.exceptionDetails) {
      throw new Error(
        result.exceptionDetails.text ||
          result.exceptionDetails.exception?.description ||
          "browser evaluation failed",
      );
    }
    return result.result?.value;
  }

  close() {
    this.ws.close();
  }
}

function remoteObjectText(value) {
  if (!value || typeof value !== "object") {
    return "";
  }
  if (value.unserializableValue != null) {
    return String(value.unserializableValue);
  }
  if (value.value != null) {
    return typeof value.value === "string" ? value.value : JSON.stringify(value.value);
  }
  return value.description || value.className || value.type || "";
}

async function connect(cdpPort) {
  const targets = await fetch(`http://127.0.0.1:${cdpPort}/json/list`).then(r => r.json());
  const target = targets.find(item => item.type === "page") ?? targets[0];
  assert(target?.webSocketDebuggerUrl, "No Chrome page target available");
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    ws.addEventListener("open", resolve, { once: true });
    ws.addEventListener("error", reject, { once: true });
  });
  return new CdpSession(ws);
}

async function enablePageProblemCapture(session) {
  await session.send("Runtime.enable");
  await session.send("Log.enable");
  session.clearPageProblems();
}

async function waitFor(session, expression, label, timeoutMs = 12000) {
  const deadline = Date.now() + timeoutMs;
  let lastValue;
  while (Date.now() < deadline) {
    lastValue = await session.evaluate(expression);
    if (lastValue) {
      return lastValue;
    }
    await sleep(100);
  }
  throw new Error(`Timed out waiting for ${label}; last value: ${JSON.stringify(lastValue)}`);
}

async function waitForStatePass(session, expression, label, timeoutMs = 12000) {
  const deadline = Date.now() + timeoutMs;
  let lastValue;
  while (Date.now() < deadline) {
    lastValue = await session.evaluate(expression);
    if (lastValue === true || lastValue?.pass === true) {
      return lastValue;
    }
    await sleep(100);
  }
  throw new Error(`Timed out waiting for ${label}; last value: ${JSON.stringify(lastValue)}`);
}

async function waitForFile(filePath, label, timeoutMs = 12000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (fs.existsSync(filePath)) {
      return;
    }
    await sleep(100);
  }
  throw new Error(`Timed out waiting for ${label}: ${filePath}`);
}

async function waitForMissingFile(filePath, label, timeoutMs = 12000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (!fs.existsSync(filePath)) {
      return;
    }
    await sleep(100);
  }
  throw new Error(`Timed out waiting for ${label} to disappear: ${filePath}`);
}

async function setViewport(session, width, height) {
  await session.send("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile: width <= 760,
  });
}

async function captureDeskScreenshot(session, name, width, height) {
  const result = await session.send("Page.captureScreenshot", {
    format: "png",
    captureBeyondViewport: false,
    fromSurface: true,
  });
  assert(typeof result.data === "string" && result.data.length > 0, `${name} screenshot returned no PNG data`);

  const buffer = Buffer.from(result.data, "base64");
  const signature = buffer.subarray(0, 8).toString("hex");
  assert(signature === "89504e470d0a1a0a", `${name} screenshot is not a PNG`);
  assert(buffer.length > 1024, `${name} screenshot is unexpectedly small: ${buffer.length} bytes`);
  assert(buffer.readUInt32BE(16) === width, `${name} screenshot width mismatch`);
  assert(buffer.readUInt32BE(20) === height, `${name} screenshot height mismatch`);

  const screenshotDir = path.join(fixtureRoot, "screenshots");
  fs.mkdirSync(screenshotDir, { recursive: true });
  const screenshotPath = path.join(screenshotDir, `${name}.png`);
  fs.writeFileSync(screenshotPath, buffer);
  assert(fs.statSync(screenshotPath).size === buffer.length, `${name} screenshot was not written completely`);
  return screenshotPath;
}

async function captureDeskViewport(session, label, width, height) {
  await setViewport(session, width, height);
  await waitFor(
    session,
    `document.querySelector('[data-testid="desk-mode"]')?.clientWidth <= ${width}`,
    `${label} viewport`,
  );
  await verifyDeskVisualLayout(session, label);
  return await captureDeskScreenshot(session, `desk-${label}-${width}x${height}`, width, height);
}

function jsString(value) {
  return JSON.stringify(value);
}

function readRepoFile(relativePath) {
  return fs.readFileSync(path.join(process.cwd(), relativePath), "utf8");
}

function verifyDeskStyleImports() {
  const runtimeFiles = [
    "ui/rabbita-desk/bootstrap.js",
    "ui/rabbita-desk/index.html",
    "ui/rabbita-desk/dist/index.html",
    "ui/rabbita-desk/styles.css",
    "ui/rabbita-desk/styles/product-shell.css",
    "ui/rabbita-desk/styles/mooncode.css",
  ];
  const violations = [];
  for (const file of runtimeFiles) {
    const text = readRepoFile(file);
    if (text.includes("moonsuite-theme.css")) {
      violations.push(`${file} imports moonsuite-theme.css`);
    }
    if (text.includes("--ms-")) {
      violations.push(`${file} contains MoonSuite warm theme tokens`);
    }
  }
  assert(
    violations.length === 0,
    `Desk runtime CSS must stay neutral and avoid broad MoonSuite warm tokens: ${violations.join("; ")}`,
  );
}

async function clickTestId(session, testId) {
  const ok = await session.evaluate(`(() => {
    const el = document.querySelector('[data-testid=${JSON.stringify(testId)}]');
    if (!el) return false;
    el.click();
    return true;
  })()`);
  assert(ok, `Missing clickable test id ${testId}`);
}

async function pointerClickTestId(session, testId) {
  const point = await session.evaluate(`(() => {
    const el = document.querySelector('[data-testid=${JSON.stringify(testId)}]');
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
  })()`);
  assert(point && Number.isFinite(point.x) && Number.isFinite(point.y), `Missing pointer target ${testId}`);
  await session.send("Input.dispatchMouseEvent", {
    type: "mouseMoved",
    x: point.x,
    y: point.y,
  });
  await session.send("Input.dispatchMouseEvent", {
    type: "mousePressed",
    x: point.x,
    y: point.y,
    button: "left",
    clickCount: 1,
  });
  await session.send("Input.dispatchMouseEvent", {
    type: "mouseReleased",
    x: point.x,
    y: point.y,
    button: "left",
    clickCount: 1,
  });
}

async function openDetailsTestId(session, testId) {
  const opened = await session.evaluate(`(() => {
    const el = document.querySelector('[data-testid=${JSON.stringify(testId)}]');
    if (!(el instanceof HTMLDetailsElement)) return false;
    if (!el.open) {
      el.querySelector(':scope > summary')?.click();
    }
    return el.open;
  })()`);
  assert(opened, `Missing or closed details test id ${testId}`);
}

async function closeDetailsTestId(session, testId) {
  const closed = await session.evaluate(`(() => {
    const el = document.querySelector('[data-testid=${JSON.stringify(testId)}]');
    if (!(el instanceof HTMLDetailsElement)) return false;
    if (el.open) {
      el.querySelector(':scope > summary')?.click();
    }
    return !el.open;
  })()`);
  assert(closed, `Missing or open details test id ${testId}`);
}

async function keyDownFileList(session, key, options = {}) {
  const ok = await session.evaluate(`(() => {
    const el = document.querySelector('[data-testid="desk-file-list"]');
    if (!el) return false;
    el.focus();
    el.dispatchEvent(new KeyboardEvent('keydown', {
      bubbles: true,
      cancelable: true,
      key: ${jsString(key)},
      ctrlKey: ${options.ctrlKey ? "true" : "false"},
      metaKey: ${options.metaKey ? "true" : "false"},
      shiftKey: ${options.shiftKey ? "true" : "false"}
    }));
    return true;
  })()`);
  assert(ok, `Missing Desk file list for key ${key}`);
}

async function setInputByTestId(session, testId, value) {
  const ok = await session.evaluate(`(() => {
    const el = document.querySelector('[data-testid=${JSON.stringify(testId)}]');
    if (!el) return false;
    el.focus();
    el.value = ${jsString(value)};
    el.dispatchEvent(new InputEvent('input', {
      bubbles: true,
      inputType: 'insertText',
      data: ${jsString(value)}
    }));
    return true;
  })()`);
  assert(ok, `Missing input test id ${testId}`);
}

async function keyDownInputByTestId(session, testId, key) {
  const ok = await session.evaluate(`(() => {
    const el = document.querySelector('[data-testid=${JSON.stringify(testId)}]');
    if (!el) return false;
    el.focus();
    el.dispatchEvent(new KeyboardEvent('keydown', {
      bubbles: true,
      cancelable: true,
      key: ${jsString(key)}
    }));
    return true;
  })()`);
  assert(ok, `Missing input test id ${testId} for key ${key}`);
}

async function setInlineRename(session, targetPath, value) {
  const ok = await session.evaluate(`(() => {
    const el = [...document.querySelectorAll('[data-testid="desk-inline-rename"]')]
      .find(input => input.dataset.path === ${jsString(targetPath)});
    if (!el) return false;
    el.focus();
    el.value = ${jsString(value)};
    el.dispatchEvent(new InputEvent('input', {
      bubbles: true,
      inputType: 'insertText',
      data: ${jsString(value)}
    }));
    return true;
  })()`);
  assert(ok, `Missing inline rename input for ${targetPath}`);
}

async function keyDownInlineRename(session, targetPath, key) {
  const ok = await session.evaluate(`(() => {
    const el = [...document.querySelectorAll('[data-testid="desk-inline-rename"]')]
      .find(input => input.dataset.path === ${jsString(targetPath)});
    if (!el) return false;
    el.focus();
    el.dispatchEvent(new KeyboardEvent('keydown', {
      bubbles: true,
      cancelable: true,
      key: ${jsString(key)}
    }));
    return true;
  })()`);
  assert(ok, `Missing inline rename input for key ${key} on ${targetPath}`);
}

async function clickWorkspace(session, workspaceId) {
  const ok = await session.evaluate(`(() => {
    const el = [...document.querySelectorAll('[data-testid="desk-workspace-row"]')]
      .find(row => row.dataset.workspaceId === ${jsString(workspaceId)});
    if (!el) return false;
    el.click();
    return true;
  })()`);
  assert(ok, `Missing workspace row ${workspaceId}`);
}

async function mouseDownPath(session, targetPath) {
  const ok = await session.evaluate(`(() => {
    const el = [...document.querySelectorAll('[data-testid="desk-file-row"]')]
      .find(row => row.dataset.path === ${jsString(targetPath)});
    if (!el) return false;
    el.dispatchEvent(new MouseEvent('mousedown', {
      bubbles: true,
      button: 0,
      detail: 1,
      view: window
    }));
    return true;
  })()`);
  assert(ok, `Missing file row ${targetPath}`);
}

async function doubleClickPath(session, targetPath) {
  const ok = await session.evaluate(`(() => {
    const el = [...document.querySelectorAll('[data-testid="desk-file-row"]')]
      .find(row => row.dataset.path === ${jsString(targetPath)});
    if (!el) return false;
    el.dispatchEvent(new MouseEvent('mousedown', {
      bubbles: true,
      button: 0,
      detail: 1,
      view: window
    }));
    el.dispatchEvent(new MouseEvent('dblclick', {
      bubbles: true,
      button: 0,
      detail: 2,
      view: window
    }));
    return true;
  })()`);
  assert(ok, `Missing file row ${targetPath}`);
}

async function clickDetailsButton(session, text) {
  const ok = await session.evaluate(`(() => {
    const details = document.querySelector('[data-testid="desk-details"]');
    if (!details) return false;
    const button = [...details.querySelectorAll('button')]
      .find(item => item.textContent.trim() === ${jsString(text)});
    if (!button) return false;
    button.click();
    return true;
  })()`);
  assert(ok, `Missing details button ${text}`);
}

async function clickTrashRow(session, originalPath) {
  const ok = await session.evaluate(`(() => {
    const row = [...document.querySelectorAll('[data-testid="desk-trash-row"]')]
      .find(item => item.dataset.originalPath === ${jsString(originalPath)});
    if (!row) return false;
    row.click();
    return true;
  })()`);
  assert(ok, `Missing trash row for ${originalPath}`);
}

async function importTextFileThroughDeskBrowser(
  session,
  name,
  content,
  relativePath = "",
) {
  const result = await session.evaluate(`(async () => {
    const workspace = document.querySelector('[data-testid="desk-workspace-row"].active');
    const directory = document.querySelector('[data-testid="desk-location-input"]')?.value ?? '';
    const workspaceId = workspace?.dataset.workspaceId ?? '';
    if (!workspaceId) return { ok: false, error: 'No active MoonBook' };
    const response = await fetch(
      '/api/workspaces/' + encodeURIComponent(workspaceId) + '/entries/import',
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          directory,
          files: [{
            filename: ${jsString(name)},
            relative_path: ${jsString(relativePath)},
            content: ${jsString(content)},
            content_type: 'text/plain',
            source: 'browser-smoke'
          }]
        })
      }
    );
    const body = await response.text();
    if (response.ok) {
      document.querySelector('[data-testid="desk-refresh"]')?.click();
    }
    return { ok: response.ok, status: response.status, body };
  })()`);
  assert(
    result?.ok === true,
    `Browser Desk import failed for ${relativePath || name}: ${JSON.stringify(result)}`,
  );
}

function trashRowExpression(originalPath) {
  return `[...document.querySelectorAll('[data-testid="desk-trash-row"]')]` +
    `.some(row => row.dataset.originalPath === ${jsString(originalPath)})`;
}

function rowExistsExpression(targetPath) {
  return `[...document.querySelectorAll('[data-testid="desk-file-row"]')]` +
    `.some(row => row.dataset.path === ${jsString(targetPath)})`;
}

function visibleRowsExpression() {
  return `[...document.querySelectorAll('[data-testid="desk-file-row"]')]` +
    `.map(row => row.dataset.path)`;
}

function mooncodeTranscriptItemsExpression() {
  return `(() => [...document.querySelectorAll('[data-testid="mooncode-message"], [data-testid="mooncode-activity"]')]
    .map((row, index) => ({
      index,
      kind: row.dataset.testid === "mooncode-message" ? "message" : "activity",
      role: row.dataset.role || "",
      status: row.dataset.status || "",
      folded: row.dataset.folded || "",
      commandId: row.dataset.commandId || "",
      clientTurnId: row.dataset.clientTurnId || "",
      text: row.textContent.trim()
    })))()`;
}

function mooncodeTranscriptStateExpression(expectedPrompts, requireInputCleared = true) {
  return `(() => {
    const expected = ${jsString(expectedPrompts)};
    const items = ${mooncodeTranscriptItemsExpression()};
    const input = document.querySelector('[data-testid="mooncode-input"]');
    const userTexts = items
      .filter(item => item.kind === "message" && item.role === "user")
      .map(item => item.text);
    const firstUserIndex = items.findIndex(item => item.kind === "message" && item.role === "user");
    const firstActivityIndex = items.findIndex(item => item.kind === "activity");
    const bodyText = document.body.textContent || "";
    const state = {
      inputValue: input?.value ?? "",
      itemCount: items.length,
      items,
      userTexts,
      hasLocalAgentCopy: bodyText.includes("Local agent is not reachable yet"),
      hasNativeRecordedCopy: bodyText.includes("Native MoonCode runtime recorded this prompt"),
      hasInternalRuntimeCopy: bodyText.includes("MoonClaw native runtime turn executed"),
      hasPromptOrder:
        userTexts.length === expected.length &&
        expected.every((prompt, index) => userTexts[index] === prompt),
      firstUserIndex,
      firstActivityIndex,
      centerText: document.querySelector('[data-testid="mooncode-center"]')?.textContent.trim().slice(0, 600) || ""
    };
    state.pass =
      state.hasPromptOrder &&
      (!${requireInputCleared ? "true" : "false"} || state.inputValue === "") &&
      firstUserIndex >= 0 &&
      (firstActivityIndex < 0 || firstActivityIndex > firstUserIndex) &&
      !state.hasLocalAgentCopy &&
      !state.hasNativeRecordedCopy &&
      !state.hasInternalRuntimeCopy;
    return state.pass ? true : state;
  })()`;
}

function mooncodeTranscriptReplyStateExpression(expectedPrompts, expectedReplies) {
  return `(() => {
    const expectedPrompts = ${jsString(expectedPrompts)};
    const expectedReplies = ${jsString(expectedReplies)};
    const items = ${mooncodeTranscriptItemsExpression()};
    const chatText = document.querySelector('[data-testid="mooncode-chat-surface"]')?.textContent || "";
    const userTexts = items
      .filter(item => item.kind === "message" && item.role === "user")
      .map(item => item.text);
    const assistantTexts = items
      .filter(item => item.kind === "message" && item.role === "assistant")
      .map(item => item.text);
    const orderedPairs = expectedPrompts.map((prompt, index) => {
      const userIndex = items.findIndex(item =>
        item.kind === "message" &&
        item.role === "user" &&
        item.text === prompt
      );
      const assistantIndex = items.findIndex(item =>
        item.kind === "message" &&
        item.role === "assistant" &&
        item.text === expectedReplies[index]
      );
      const nextUserIndex = index + 1 < expectedPrompts.length
        ? items.findIndex(item =>
            item.kind === "message" &&
            item.role === "user" &&
            item.text === expectedPrompts[index + 1]
          )
        : items.length;
      return {
        prompt,
        reply: expectedReplies[index],
        userIndex,
        assistantIndex,
        nextUserIndex,
        pass: userIndex >= 0 &&
          assistantIndex > userIndex &&
          assistantIndex < nextUserIndex
      };
    });
    const state = {
      items,
      userTexts,
      assistantTexts,
      orderedPairs,
      hasPromptOrder:
        userTexts.length === expectedPrompts.length &&
        expectedPrompts.every((prompt, index) => userTexts[index] === prompt),
      hasReplyOrder:
        assistantTexts.length === expectedReplies.length &&
        expectedReplies.every((reply, index) => assistantTexts[index] === reply),
      hasLocalAgentCopy: chatText.includes("Local agent is not reachable yet"),
      hasNativeRecordedCopy: chatText.includes("Native MoonCode runtime recorded this prompt"),
      hasRuntimeUnavailableCopy: chatText.includes("MoonClaw daemon"),
      hasInternalRuntimeCopy: chatText.includes("MoonClaw native runtime turn executed")
    };
    state.pass =
      state.hasPromptOrder &&
      state.hasReplyOrder &&
      orderedPairs.every(pair => pair.pass) &&
      !state.hasLocalAgentCopy &&
      !state.hasNativeRecordedCopy &&
      !state.hasRuntimeUnavailableCopy &&
      !state.hasInternalRuntimeCopy;
    return state.pass ? true : state;
  })()`;
}

function mooncodeStableTranscriptStateExpression(expectedPrompts, expectedReplies = []) {
  return `(() => {
    const expectedPrompts = ${jsString(expectedPrompts)};
    const expectedReplies = ${jsString(expectedReplies)};
    const center = document.querySelector('[data-testid="mooncode-center"]');
    const chat = document.querySelector('[data-testid="mooncode-chat-surface"]');
    const items = ${mooncodeTranscriptItemsExpression()};
    const bodyText = document.body.textContent || "";
    const userRows = items.filter(item => item.kind === "message" && item.role === "user");
    const assistantRows = items.filter(item => item.kind === "message" && item.role === "assistant");
    const userTexts = userRows.map(item => item.text);
    const assistantTexts = assistantRows.map(item => item.text);
    const duplicateUserTexts = userTexts.filter((text, index) => userTexts.indexOf(text) !== index);
    const missingPromptRows = expectedPrompts.filter(prompt => !userRows.some(row => row.text === prompt));
    const missingReplyRows = expectedReplies.filter(reply => !assistantRows.some(row => row.text === reply));
    const badPromptOrder =
      userTexts.length !== expectedPrompts.length ||
      !expectedPrompts.every((prompt, index) => userTexts[index] === prompt);
    const badReplyOrder = expectedReplies.length > 0 &&
      (
        assistantTexts.length !== expectedReplies.length ||
        !expectedReplies.every((reply, index) => assistantTexts[index] === reply)
      );
    const promptOwnerChecks = expectedPrompts.map((prompt, index) => {
      const userIndex = items.findIndex(item =>
        item.kind === "message" &&
        item.role === "user" &&
        item.text === prompt
      );
      const user = userIndex >= 0 ? items[userIndex] : {};
      const reply = expectedReplies[index] || "";
      const assistantIndex = reply === "" ? -1 : items.findIndex(item =>
        item.kind === "message" &&
        item.role === "assistant" &&
        item.text === reply
      );
      const nextUserIndex = index + 1 < expectedPrompts.length
        ? items.findIndex(item =>
            item.kind === "message" &&
            item.role === "user" &&
            item.text === expectedPrompts[index + 1]
          )
        : items.length;
      const ownedActivities = items
        .map((item, itemIndex) => ({ ...item, itemIndex }))
        .filter(item =>
          item.kind === "activity" &&
          (
            (user.commandId && item.commandId === user.commandId) ||
            (user.clientTurnId && item.clientTurnId === user.clientTurnId)
          )
        );
      const ownedActivityIndexes = ownedActivities.map(item => item.itemIndex);
      const activityPlacementOk = ownedActivityIndexes.every(itemIndex =>
        itemIndex > userIndex &&
        (
          assistantIndex < 0 ||
          itemIndex < assistantIndex
        ) &&
        itemIndex < nextUserIndex
      );
      return {
        prompt,
        userIndex,
        assistantIndex,
        nextUserIndex,
        commandId: user.commandId || "",
        clientTurnId: user.clientTurnId || "",
        ownedActivityIndexes,
        hasOwner: !!(user.commandId || user.clientTurnId),
        activityPlacementOk,
      };
    });
    const frontPageFlash = expectedPrompts.length > 0 &&
      (!center || !chat || items.length === 0 || userRows.length === 0);
    const activityBeforeFirstUser = items.some((item, index) =>
      item.kind === "activity" &&
      index < items.findIndex(other => other.kind === "message" && other.role === "user")
    );
    const misplacedOwners = promptOwnerChecks.filter(check =>
      !check.hasOwner || !check.activityPlacementOk
    );
    const unfoldedCompletedActivity = expectedReplies.length > 0
      ? items.filter(item =>
          item.kind === "activity" &&
          item.status !== "running" &&
          item.folded !== "true"
        )
      : [];
    const internalLeaks = [
      "Local agent is not reachable yet",
      "Native MoonCode runtime recorded this prompt",
      "MoonClaw native runtime turn executed",
      "command_id",
      "client_turn_id",
      "model-tool-calls",
      "assistant_delta"
    ].filter(text => bodyText.includes(text));
    const state = {
      itemCount: items.length,
      userTexts,
      assistantTexts,
      duplicateUserTexts,
      missingPromptRows,
      missingReplyRows,
      badPromptOrder,
      badReplyOrder,
      frontPageFlash,
      activityBeforeFirstUser,
      misplacedOwners,
      unfoldedCompletedActivity,
      internalLeaks,
      centerText: center?.textContent?.trim().slice(0, 500) || "",
      items,
    };
    state.pass =
      !frontPageFlash &&
      !badPromptOrder &&
      !badReplyOrder &&
      duplicateUserTexts.length === 0 &&
      missingPromptRows.length === 0 &&
      missingReplyRows.length === 0 &&
      !activityBeforeFirstUser &&
      misplacedOwners.length === 0 &&
      unfoldedCompletedActivity.length === 0 &&
      internalLeaks.length === 0;
    return state.pass ? true : state;
  })()`;
}

async function sampleMoonCodeStableTranscript(
  session,
  expectedPrompts,
  label,
  expectedReplies = [],
  durationMs = 900,
) {
  const deadline = Date.now() + durationMs;
  const failures = [];
  let samples = 0;
  while (Date.now() < deadline) {
    const state = await session.evaluate(
      mooncodeStableTranscriptStateExpression(expectedPrompts, expectedReplies),
    );
    samples += 1;
    if (state !== true && state?.pass !== true) {
      failures.push(state);
    }
    await sleep(50);
  }
  assert(
    failures.length === 0,
    `${label} saw unstable MoonCode transcript state: ${JSON.stringify(failures.slice(0, 5))}`,
  );
  return samples;
}

function mooncodeBackendTurnsStateExpression(expectedPrompts, expectedReplies = [], returnState = false) {
  return `(async () => {
    const expected = ${jsString(expectedPrompts)};
    const expectedReplies = ${jsString(expectedReplies)};
    let sessions;
    try {
      const response = await fetch("/api/mooncode/sessions");
      sessions = await response.json();
    } catch (error) {
      return { pass: false, error: String(error) };
    }
    if (!Array.isArray(sessions)) {
      return { pass: false, sessions };
    }
    const summaries = sessions.map(session => {
      const conversation = session?.mooncode_conversation || {};
      const turns = Array.isArray(conversation.turns) ? conversation.turns : [];
      const userTexts = turns.map(turn => turn?.user?.content || "").filter(Boolean);
      const assistantTexts = turns.map(turn => turn?.assistant?.content || "").filter(Boolean);
      const statuses = turns.map(turn => turn?.status || "");
      const commandIds = turns.map(turn => turn?.command_id || "");
      const clientTurnIds = turns.map(turn => turn?.client_turn_id || "");
      return {
        id: session?.id || "",
        status: session?.status || "",
        turnCount: turns.length,
        userTexts,
        assistantTexts,
        statuses,
        commandIds,
        clientTurnIds,
        raw: JSON.stringify(conversation)
      };
    });
    const matching = summaries.filter(summary =>
      summary.userTexts.length === expected.length &&
      expected.every((prompt, index) => summary.userTexts[index] === prompt) &&
      summary.commandIds.every(id => id !== "") &&
      summary.clientTurnIds.every(id => id !== "") &&
      (
        expectedReplies.length === 0 ||
        (
          summary.assistantTexts.length === expectedReplies.length &&
          expectedReplies.every((reply, index) => summary.assistantTexts[index] === reply) &&
          summary.statuses.every(status => status === "done")
        )
      )
    );
    const rawLeak = summaries.some(summary =>
      summary.raw.includes("Local agent is not reachable yet") ||
      summary.raw.includes("Native MoonCode runtime recorded this prompt") ||
      (
        expectedReplies.length > 0 &&
        summary.raw.includes("MoonClaw daemon")
      )
    );
    const state = { sessionCount: sessions.length, summaries, rawLeak };
    state.pass = sessions.length === 1 && matching.length === 1 && !rawLeak;
    return ${returnState ? "state" : "state.pass ? true : state"};
  })()`;
}

async function mooncodeBackendSessionForPrompts(session, expectedPrompts) {
  const state = await waitForStatePass(
    session,
    mooncodeBackendTurnsStateExpression(expectedPrompts, [], true),
    "MoonCode backend session for runtime event injection",
    12000,
  );
  const matching = state.summaries.filter(summary =>
    summary.userTexts.length === expectedPrompts.length &&
    expectedPrompts.every((prompt, index) => summary.userTexts[index] === prompt)
  );
  assert(matching.length === 1, `Expected one MoonCode backend session: ${JSON.stringify(state)}`);
  return matching[0];
}

async function postMoonCodeRuntimeReplyEvents(session, sessionSummary, replies) {
  assert(sessionSummary.commandIds.length === replies.length, "Native reply count must match command count");
  const events = replies.map((reply, index) => ({
    event: "assistant_message",
    id: `browser-native-assistant-${index + 1}`,
    created_at: `2026-06-30T04:0${index}:00Z`,
    content: reply,
    command_id: sessionSummary.commandIds[index],
    action: "prompt",
    session_id: sessionSummary.id,
  }));
  const response = await session.evaluate(`(async () => {
    const response = await fetch("/api/mooncode/sessions/${sessionSummary.id}/runtime-events", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: ${jsString(JSON.stringify({ events }))},
    });
    const body = await response.json();
    return { ok: response.ok, status: response.status, body };
  })()`);
  assert(
    response?.ok && response.body?.accepted_event_count === replies.length,
    `MoonCode runtime-event ingest failed: ${JSON.stringify(response)}`,
  );
}

function mooncodeUiSessionReadyStateExpression(expectedPrompts) {
  return `(() => {
    const transcriptState = ${mooncodeTranscriptStateExpression(expectedPrompts, false)};
    if (transcriptState !== true) {
      return transcriptState;
    }
    const rows = [...document.querySelectorAll('[data-testid="mooncode-session"]')];
    const activeRows = rows.filter(row => row.classList.contains("active"));
    const state = {
      sessionCount: rows.length,
      activeSessionCount: activeRows.length,
      rows: rows.map(row => ({
        id: row.dataset.sessionId || "",
        status: row.dataset.status || "",
        text: row.textContent.trim()
      }))
    };
    state.pass = rows.length === 1 && activeRows.length === 1;
    return state.pass ? true : state;
  })()`;
}

async function sendMoonCodePromptAndAssert(session, prompt, expectedPrompts) {
  await setInputByTestId(session, "mooncode-input", prompt);
  await waitFor(
    session,
    `document.querySelector('[data-testid="mooncode-input"]')?.value === ${jsString(prompt)}`,
    "MoonCode prompt typed",
  );
  await keyDownInputByTestId(session, "mooncode-input", "Enter");
  await waitForStatePass(
    session,
    mooncodeTranscriptStateExpression(expectedPrompts, false),
    `MoonCode immediate append for ${prompt}`,
    1600,
  );
  await waitForStatePass(
    session,
    mooncodeBackendTurnsStateExpression(expectedPrompts),
    `MoonCode backend canonical turns for ${prompt}`,
    12000,
  );
  await waitForStatePass(
    session,
    mooncodeUiSessionReadyStateExpression(expectedPrompts),
    `MoonCode UI session acknowledged for ${prompt}`,
    12000,
  );
  await sampleMoonCodeStableTranscript(
    session,
    expectedPrompts,
    `MoonCode stable append for ${prompt}`,
  );
}

async function runMoonCodePromptSmoke(session) {
  const prompts = [
    "Browser smoke prompt append order",
    "Browser smoke second prompt order",
    "Browser smoke third prompt persistence",
  ];
  await setViewport(session, 1440, 900);
  await session.send("Page.navigate", { url: `${baseUrl}/?activity=code&mooncodeRuntime=manual` });
  await waitFor(
    session,
    `document.readyState === 'complete' && !!document.querySelector('[data-testid="mooncode-center"]')`,
    "MoonCode mode",
  );
  await waitFor(
    session,
    `document.querySelector('[data-testid="mooncode-chat-surface"]')?.textContent.includes('Ask MoonCode')`,
    "empty MoonCode first-chat surface",
  );
  for (let index = 0; index < prompts.length; index += 1) {
    await sendMoonCodePromptAndAssert(session, prompts[index], prompts.slice(0, index + 1));
  }
  await sleep(1200);
  const items = await session.evaluate(mooncodeTranscriptItemsExpression());
  const messageItems = items.filter(item => item.kind === "message");
  const userTexts = messageItems.filter(item => item.role === "user").map(item => item.text);
  assert(
    userTexts.length === prompts.length && prompts.every((prompt, index) => userTexts[index] === prompt),
    `MoonCode user messages should stay append-only after three sends: ${JSON.stringify(items)}`,
  );
  const userIndex = items.findIndex(item => item.kind === "message" && item.role === "user" && item.text === prompts[0]);
  const firstAssistantIndex = items.findIndex(item => item.kind === "message" && item.role === "assistant");
  const firstActivityIndex = items.findIndex(item => item.kind === "activity");
  assert(userIndex === 0, `MoonCode user prompt should remain at the top of the new chat: ${JSON.stringify(items)}`);
  if (firstActivityIndex >= 0) {
    assert(
      firstActivityIndex > userIndex && (firstAssistantIndex < 0 || firstActivityIndex < firstAssistantIndex),
      `MoonCode activity should sit between the user prompt and assistant reply: ${JSON.stringify(items)}`,
    );
  }
  if (firstAssistantIndex >= 0) {
    assert(
      firstAssistantIndex > userIndex,
      `MoonCode assistant reply should append after the user prompt: ${JSON.stringify(items)}`,
    );
  }
  const nativeReplies = [
    "Browser native reply for prompt append order.",
    "Browser native reply for second prompt order.",
    "Browser native reply for third prompt persistence.",
  ];
  const sessionSummary = await mooncodeBackendSessionForPrompts(session, prompts);
  await postMoonCodeRuntimeReplyEvents(session, sessionSummary, nativeReplies);
  await waitForStatePass(
    session,
    mooncodeBackendTurnsStateExpression(prompts, nativeReplies),
    "MoonCode backend imports native assistant replies",
    12000,
  );
  await waitForStatePass(
    session,
    mooncodeTranscriptReplyStateExpression(prompts, nativeReplies),
    "MoonCode UI renders event-backed native replies",
    16000,
  );
  await sampleMoonCodeStableTranscript(
    session,
    prompts,
    "MoonCode stable native reply order",
    nativeReplies,
    1200,
  );
  await session.send("Page.reload", { ignoreCache: true });
  await waitFor(
    session,
    `document.readyState === 'complete' && !!document.querySelector('[data-testid="mooncode-center"]')`,
    "MoonCode mode after hard refresh",
  );
  await waitForStatePass(
    session,
    mooncodeTranscriptReplyStateExpression(prompts, nativeReplies),
    "MoonCode hard refresh preserves native reply order",
    12000,
  );
  await waitForStatePass(
    session,
    mooncodeBackendTurnsStateExpression(prompts, nativeReplies),
    "MoonCode hard refresh preserves backend native reply order",
    12000,
  );
  await sampleMoonCodeStableTranscript(
    session,
    prompts,
    "MoonCode stable hard-refresh reply order",
    nativeReplies,
    1200,
  );
  const bodyText = await session.evaluate(`document.body.textContent || ""`);
  assert(
    !bodyText.includes("Local agent is not reachable yet"),
    "MoonCode chat leaked the old local-agent fallback text",
  );
  assert(
    !bodyText.includes("Native MoonCode runtime recorded this prompt"),
    "MoonCode chat leaked native runtime bookkeeping as assistant copy",
  );
}

function isLargeBrown(rgb) {
  const match = /^rgba?\((\d+),\s*(\d+),\s*(\d+)/.exec(rgb);
  if (!match) {
    return false;
  }
  const [, rText, gText, bText] = match;
  const r = Number(rText);
  const g = Number(gText);
  const b = Number(bText);
  const warmDominant = r > g && g >= b;
  const mutedBrown = r - b > 24 && g - b > 12 && r < 190;
  return warmDominant && mutedBrown;
}

async function verifyDeskVisualLayout(session, label) {
  const layout = await session.evaluate(`(() => {
    const visibleRect = selector => {
      const el = document.querySelector(selector);
      if (!el) return null;
      const rect = el.getBoundingClientRect();
      if (rect.width <= 0 || rect.height <= 0) return null;
      return {
        selector,
        left: rect.left,
        right: rect.right,
        top: rect.top,
        bottom: rect.bottom,
        width: rect.width,
        height: rect.height,
        background: getComputedStyle(el).backgroundColor
      };
    };
    const rects = [
      visibleRect('.desk-sidebar'),
      visibleRect('.desk-browser'),
      visibleRect('[data-testid="desk-details"]')
    ].filter(Boolean);
    const overlaps = [];
    for (let i = 0; i < rects.length; i += 1) {
      for (let j = i + 1; j < rects.length; j += 1) {
        const a = rects[i];
        const b = rects[j];
        const width = Math.max(0, Math.min(a.right, b.right) - Math.max(a.left, b.left));
        const height = Math.max(0, Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top));
        if (width * height > 4) {
          overlaps.push([a.selector, b.selector, width, height]);
        }
      }
    }
    const surfaces = [
      visibleRect('[data-testid="desk-mode"]'),
      ...rects,
      visibleRect('.title-bar')
    ].filter(Boolean);
    const libraryRoot = document.querySelector('[data-testid="desk-library-root"]');
    const libraryOverflow = [];
    if (libraryRoot) {
      const rootRect = libraryRoot.getBoundingClientRect();
      for (const el of libraryRoot.querySelectorAll('strong, code')) {
        const rect = el.getBoundingClientRect();
        if (
          Math.ceil(el.scrollWidth) > Math.ceil(el.clientWidth) + 1 ||
          rect.left < rootRect.left - 1 ||
          rect.right > rootRect.right + 1
        ) {
          libraryOverflow.push({
            tag: el.tagName.toLowerCase(),
            text: el.textContent,
            clientWidth: el.clientWidth,
            scrollWidth: el.scrollWidth,
            left: rect.left,
            right: rect.right,
            rootLeft: rootRect.left,
            rootRight: rootRect.right
          });
        }
      }
    }
    return {
      viewportWidth: document.documentElement.clientWidth,
      documentWidth: document.documentElement.scrollWidth,
      viewportHeight: document.documentElement.clientHeight,
      documentHeight: document.documentElement.scrollHeight,
      warmThemeToken: getComputedStyle(document.documentElement).getPropertyValue('--ms-espresso').trim(),
      surfaces,
      overlaps,
      libraryOverflow,
      sidebar: visibleRect('.desk-sidebar'),
      browser: visibleRect('.desk-browser'),
      details: visibleRect('[data-testid="desk-details"]'),
      fileTableOverflow: (() => {
        const table = document.querySelector('.desk-file-table');
        if (!table) return null;
        return {
          clientWidth: table.clientWidth,
          scrollWidth: table.scrollWidth
        };
      })()
    };
  })()`);
  assert(
    layout.warmThemeToken === "",
    `${label} Desk should not load warm MoonSuite color tokens: ${layout.warmThemeToken}`,
  );
  assert(
    layout.documentWidth <= layout.viewportWidth + 1,
    `${label} Desk layout overflows horizontally: ${JSON.stringify(layout)}`,
  );
  assert(
    layout.overlaps.length === 0,
    `${label} Desk panes overlap: ${JSON.stringify(layout.overlaps)}`,
  );
  assert(
    layout.libraryOverflow.length === 0,
    `${label} Desk library root path overflows its card: ${JSON.stringify(layout.libraryOverflow)}`,
  );
  if (layout.viewportWidth <= 760) {
    assert(
      layout.browser &&
        layout.details &&
        layout.sidebar &&
        layout.browser.top < layout.viewportHeight &&
        layout.browser.top < layout.details.top &&
        layout.details.top < layout.sidebar.top &&
        layout.fileTableOverflow &&
        layout.fileTableOverflow.scrollWidth <= layout.fileTableOverflow.clientWidth + 1,
      `${label} Desk should order browser, details, then library on phones: ${JSON.stringify(layout)}`,
    );
  } else if (layout.viewportWidth <= 1120) {
    assert(
      layout.browser &&
        layout.details &&
        layout.sidebar &&
        layout.browser.left === layout.details.left &&
        layout.browser.bottom <= layout.details.top + 1,
      `${label} Desk should retain selection details below the browser on tablets: ${JSON.stringify(layout)}`,
    );
  }
  const largeBrown = layout.surfaces
    .map(surface => `${surface.selector}=${surface.background}`)
    .filter(item => isLargeBrown(item.split("=").pop()));
  assert(
    largeBrown.length === 0,
    `${label} Desk large surfaces should not use brown/chocolate fills: ${largeBrown.join(", ")}`,
  );
}

async function run() {
  verifyDeskStyleImports();
  const session = await connect(cdpPort);
  const screenshots = [];
  try {
    await session.send("Page.enable");
    await enablePageProblemCapture(session);
    await setViewport(session, 1440, 900);
    await session.send("Page.navigate", { url: baseUrl });
    await waitFor(
      session,
      `document.readyState === 'complete' && !!document.querySelector('[data-testid="desk-mode"]')`,
      "Desk mode",
    );
    await waitFor(
      session,
      `document.querySelectorAll('[data-testid="desk-workspace-row"]').length >= 3`,
      "multiple MoonBook rows",
    );

    const workspaceRows = await session.evaluate(
      `[...document.querySelectorAll('[data-testid="desk-workspace-row"]')]` +
        `.map(row => ({ id: row.dataset.workspaceId, status: row.dataset.status, text: row.textContent, title: row.title }))`,
    );
    const workspaceIds = workspaceRows.map(row => row.id);
    assert(workspaceIds.includes("book-research-alpha"), "Research Alpha MoonBook is not listed");
    assert(workspaceIds.includes("book-research-beta"), "Research Beta MoonBook is not listed");
    assert(workspaceIds.includes("book-research-gamma"), "Research Gamma MoonBook is not listed");
    assert(workspaceIds.includes("book-research-recovered"), "Incomplete recovered MoonBook folder is not listed");
    assert(
      workspaceRows.some(row => row.id === "book-research-alpha" && row.text.includes("Research Alpha")),
      "Research Alpha MoonBook row should show the manifest name",
    );
    assert(
      workspaceRows.some(row => row.id === "book-research-beta" && row.text.includes("Research Beta")),
      "Research Beta MoonBook row should show the manifest name",
    );
    assert(
      workspaceRows.some(row => row.id === "book-research-gamma" && row.text.includes("Research Gamma")),
      "Research Gamma MoonBook row should show the manifest name",
    );
    assert(
      workspaceRows.some(
        row =>
          row.id === "book-research-recovered" &&
          row.status === "needs-attention" &&
          row.text.includes("research-recovered") &&
          row.text.includes("Needs setup"),
      ),
      "Manifest-less MoonBook folder should remain visible with Needs setup status",
    );
    assert(
      workspaceRows.every(
        row =>
          row.title.includes("books/") &&
          !row.text.includes("books/") &&
          !row.title.includes(fixtureRoot),
      ),
      `Workspace rows should keep storage labels out of visible text: ${JSON.stringify(workspaceRows)}`,
    );
    const libraryState = await session.evaluate(`(() => {
      const root = document.querySelector('[data-testid="desk-library-root"]');
      const summary = root?.querySelector(':scope > .desk-library-summary');
      const diagnostics = root?.querySelector('[data-testid="desk-library-storage-details"]');
      return {
        primaryText: summary?.textContent ?? '',
        visibleText: root?.innerText ?? '',
        diagnosticText: diagnostics?.textContent ?? '',
        diagnosticsOpen: diagnostics?.open === true,
        addBookOpen: document.querySelector('[data-testid="desk-add-moonbook"]')?.open === true,
        fileHeaderText: document.querySelector('.desk-file-header')?.textContent ?? '',
      };
    })()`);
    assert(
      libraryState.primaryText.includes("My MoonBooks") &&
        libraryState.primaryText.includes("4 MoonBooks") &&
        !libraryState.primaryText.includes("books/") &&
        !libraryState.visibleText.includes("MoonClaw") &&
        !libraryState.visibleText.includes(fixtureRoot) &&
        libraryState.diagnosticText.includes(path.join(fixtureRoot, "books")) &&
        !libraryState.diagnosticsOpen &&
        !libraryState.addBookOpen &&
        !libraryState.fileHeaderText.includes("Layer"),
      `Desk should hide implementation details by default: ${JSON.stringify(libraryState)}`,
    );
    const archivePickerText = await session.evaluate(
      `document.querySelector('[data-testid="desk-import-book-archive"]')?.textContent ?? ''`,
    );
    assert(
      archivePickerText.includes("Choose Archive"),
      `Desk library should expose picked archive import: ${archivePickerText}`,
    );
    const folderPickerText = await session.evaluate(
      `document.querySelector('[data-testid="desk-import-book-folder"]')?.textContent ?? ''`,
    );
    assert(
      folderPickerText.includes("Choose Folder"),
      `Desk library should expose picked folder import: ${folderPickerText}`,
    );
    await waitFor(
      session,
      `!document.querySelector('[data-testid="desk-create-book"]')?.disabled && ` +
        `document.querySelector('[data-testid="desk-import-book"]')?.disabled`,
      "initial library action disabled states",
    );
    await openDetailsTestId(session, "desk-add-moonbook");
    await setInputByTestId(session, "desk-new-book-name", "Browser Created MoonBook");
    await setInputByTestId(session, "desk-new-book-id", "browser-created-moonbook");
    await waitFor(
      session,
      `!document.querySelector('[data-testid="desk-create-book"]')?.disabled`,
      "create MoonBook enabled with draft values",
    );
    await clickTestId(session, "desk-create-book");
    await waitFor(
      session,
      `[...document.querySelectorAll('[data-testid="desk-workspace-row"]')]` +
        `.some(row => row.dataset.workspaceId === 'book-browser-created-moonbook' && row.title.includes('books/browser-created-moonbook'))`,
      "browser-created MoonBook row in dedicated library",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-library-root"]')?.textContent.includes('5 MoonBooks')`,
      "MoonBook library count after browser create",
    );
    await waitFor(
      session,
      `document.querySelector('.desk-browser-head h2')?.textContent.includes('wiki') && ${rowExistsExpression("wiki/index.md")}`,
      "browser-created MoonBook opens starter wiki",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-new-book-name"]')?.value === '' && ` +
        `document.querySelector('[data-testid="desk-new-book-id"]')?.value === '' && ` +
        `document.querySelector('[data-testid="desk-create-book"]')?.disabled && ` +
        `document.querySelector('.desk-new-book-panel')?.textContent.includes('created browser-created-moonbook')`,
      "MoonBook create form cleared after success",
    );
    const createdBookRoot = path.join(fixtureRoot, "books/browser-created-moonbook");
    await waitForFile(path.join(createdBookRoot, "book.json"), "browser-created book.json");
    await waitForFile(path.join(createdBookRoot, "wiki/index.md"), "browser-created starter wiki");
    assert(
      !fs.existsSync(path.join(fixtureRoot, "browser-created-moonbook")),
      "Browser-created MoonBook should not be written at the workspace root",
    );
    const importSourceRoot = path.join(
      path.dirname(fixtureRoot),
      `${path.basename(fixtureRoot)}-sidebar-import-source`,
    );
    fs.mkdirSync(path.join(importSourceRoot, "wiki"), { recursive: true });
    fs.mkdirSync(path.join(importSourceRoot, "raw"), { recursive: true });
    fs.mkdirSync(path.join(importSourceRoot, ".git"), { recursive: true });
    fs.writeFileSync(
      path.join(importSourceRoot, "book.json"),
      '{"id":"sidebar-imported-moonbook","name":"Sidebar Imported MoonBook"}\n',
    );
    fs.writeFileSync(
      path.join(importSourceRoot, "wiki/index.md"),
      "# Sidebar Imported MoonBook\n\nimported through Desk sidebar\n",
    );
    fs.writeFileSync(path.join(importSourceRoot, "raw/evidence.txt"), "sidebar import evidence\n");
    fs.writeFileSync(path.join(importSourceRoot, ".git/config"), "skip me\n");
    await openDetailsTestId(session, "desk-add-moonbook");
    await openDetailsTestId(session, "desk-import-from-path");
    await setInputByTestId(session, "desk-import-book-path", importSourceRoot);
    await waitFor(
      session,
      `!document.querySelector('[data-testid="desk-import-book"]')?.disabled`,
      "Import MoonBook enabled with source path",
    );
    await clickTestId(session, "desk-import-book");
    await waitFor(
      session,
      `[...document.querySelectorAll('[data-testid="desk-workspace-row"]')]` +
        `.some(row => row.dataset.workspaceId === 'book-sidebar-imported-moonbook' && row.title.includes('books/sidebar-imported-moonbook'))`,
      "sidebar-imported MoonBook row in dedicated library",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-library-root"]')?.textContent.includes('6 MoonBooks')`,
      "MoonBook library count after browser import",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-import-book-path"]')?.value === '' && ` +
        `document.querySelector('[data-testid="desk-import-book"]')?.disabled && ` +
        `document.querySelector('.desk-new-book-panel')?.textContent.includes('imported sidebar-imported-moonbook') && ` +
        `document.querySelector('.desk-browser-head h2')?.textContent.includes('wiki') && ` +
        `${rowExistsExpression("wiki/index.md")}`,
      "sidebar import opens starter wiki and clears import path",
    );
    const importedBookRoot = path.join(fixtureRoot, "books/sidebar-imported-moonbook");
    await waitForFile(path.join(importedBookRoot, "book.json"), "sidebar-imported book.json");
    await waitForFile(path.join(importedBookRoot, "wiki/index.md"), "sidebar-imported starter wiki");
    await waitForFile(path.join(importedBookRoot, "raw/evidence.txt"), "sidebar-imported raw evidence");
    assert(
      fs.existsSync(path.join(importSourceRoot, "wiki/index.md")),
      "Sidebar import source was moved instead of copied",
    );
    assert(
      !fs.existsSync(path.join(importedBookRoot, ".git/config")),
      "Sidebar import copied host VCS metadata",
    );
    assert(
      !fs.existsSync(path.join(fixtureRoot, "sidebar-imported-moonbook")),
      "Sidebar-imported MoonBook should not be written at the workspace root",
    );
    await closeDetailsTestId(session, "desk-add-moonbook");

    const largeBackgrounds = await session.evaluate(`[
      getComputedStyle(document.querySelector('[data-testid="desk-mode"]')).backgroundColor,
      getComputedStyle(document.querySelector('.desk-sidebar')).backgroundColor,
      getComputedStyle(document.querySelector('.desk-browser')).backgroundColor,
      getComputedStyle(document.querySelector('[data-testid="desk-details"]')).backgroundColor
    ]`);
    assert(
      !largeBackgrounds.some(isLargeBrown),
      `Desk large surfaces should not use brown/chocolate fills: ${largeBackgrounds.join(", ")}`,
    );
    screenshots.push(await captureDeskViewport(session, "desktop", 1440, 900));
    screenshots.push(await captureDeskViewport(session, "small-desktop", 1280, 720));
    screenshots.push(await captureDeskViewport(session, "tablet", 1024, 768));
    await setViewport(session, 1440, 900);

    await clickWorkspace(session, "book-research-alpha");
    await waitFor(session, rowExistsExpression("wiki"), "alpha root wiki row");
    await waitFor(session, rowExistsExpression("raw"), "alpha root raw row");
    await waitFor(
      session,
      rowExistsExpression("book/site/generated"),
      "alpha root generated-site virtual row",
    );
    await waitFor(
      session,
      `!${rowExistsExpression("book")}`,
      "alpha root hides raw book directory while exposing generated site",
    );
    const rootRows = await session.evaluate(visibleRowsExpression());
    assert(!rootRows.some(item => item.includes(".git") || item.includes(".DS_Store")), "Hidden host noise is visible in Desk");
    assert(
      fs.existsSync(path.join(fixtureRoot, "books/research-alpha/book/moonbook-ui-state.json")),
      "Rabbita projection state was not placed under the fresh books root",
    );
    assert(
      !fs.existsSync(path.join(fixtureRoot, ".moontown/books/research-alpha/book/moonbook-ui-state.json")),
      "Browser smoke fixture should not create legacy .moontown book projections",
    );
    await doubleClickPath(session, "book/site/generated");
    await waitFor(
      session,
      rowExistsExpression("book/site/generated/index.html"),
      "generated-site index row",
    );
    await mouseDownPath(session, "book/site/generated/index.html");
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-preview"]')?.textContent.includes('index.html')`,
      "generated-site inline preview title",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-preview"] a')?.href.includes('/api/workspaces/book-research-alpha/file/book/site/generated/index.html')`,
      "generated-site preview link uses fresh MoonBook file route",
    );
    await clickTestId(session, "desk-root");
    await waitFor(session, rowExistsExpression("wiki"), "generated-site smoke returned to root");
    await waitFor(
      session,
      `document.querySelector('.desk-file-table')?.classList.contains('density-comfortable')`,
      "default comfortable Desk density",
    );
    const comfortableRowHeight = await session.evaluate(
      `document.querySelector('[data-testid="desk-file-row"]')?.getBoundingClientRect().height || 0`,
    );
    await openDetailsTestId(session, "desk-view-options");
    await clickTestId(session, "desk-density-compact");
    await waitFor(
      session,
      `document.querySelector('.desk-file-table')?.classList.contains('density-compact')`,
      "compact Desk density class",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-density-compact"]')?.classList.contains('active')`,
      "compact Desk density active button",
    );
    const compactRowHeight = await session.evaluate(
      `document.querySelector('[data-testid="desk-file-row"]')?.getBoundingClientRect().height || 0`,
    );
    assert(
      compactRowHeight > 0 && comfortableRowHeight > 0 && compactRowHeight <= comfortableRowHeight,
      `Compact Desk density should not make rows taller: comfortable=${comfortableRowHeight}, compact=${compactRowHeight}`,
    );
    await openDetailsTestId(session, "desk-view-options");
    await clickTestId(session, "desk-density-comfortable");
    await waitFor(
      session,
      `document.querySelector('.desk-file-table')?.classList.contains('density-comfortable')`,
      "comfortable Desk density restored",
    );
    await closeDetailsTestId(session, "desk-view-options");
    await keyDownFileList(session, "a", { ctrlKey: true });
    await waitFor(
      session,
      `document.querySelector('.desk-location-meta')?.textContent.includes(${jsString(`${rootRows.length} selected`)})`,
      "keyboard select all row count",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-details"]')?.textContent.includes('Selection') && document.querySelector('[data-testid="desk-details"]')?.textContent.includes('folders') && document.querySelector('[data-testid="desk-details"]')?.textContent.includes('Total Size')`,
      "multi-selection aggregate details",
    );

    await doubleClickPath(session, "wiki");
    await waitFor(session, rowExistsExpression("wiki/index.md"), "wiki index row");
    await mouseDownPath(session, "wiki/index.md");
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-preview"]')?.textContent.includes('Alpha Desk')`,
      "markdown preview",
    );
    await waitFor(
      session,
      `!!document.querySelector('[data-testid="desk-reveal-selection"]')`,
      "single selection reveal control",
    );
    const technicalDetailsState = await session.evaluate(`(() => {
      const details = document.querySelector('[data-testid="desk-selection-technical-details"]');
      return {
        open: details?.open === true,
        visibleText: details?.innerText ?? '',
        allText: details?.textContent ?? '',
      };
    })()`);
    assert(
      !technicalDetailsState.open &&
        !technicalDetailsState.visibleText.includes("Source area") &&
        technicalDetailsState.allText.includes("Source area") &&
        technicalDetailsState.allText.includes("wiki/index.md"),
      `Selection internals should be available but closed by default: ${JSON.stringify(technicalDetailsState)}`,
    );
    await openDetailsTestId(session, "desk-selection-technical-details");
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-selection-technical-details"]')?.innerText.includes('Source area')`,
      "selection technical details disclosure",
    );
    await closeDetailsTestId(session, "desk-selection-technical-details");
    await openDetailsTestId(session, "desk-selection-more-actions");
    await clickTestId(session, "desk-copy-path");
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-details"]')?.textContent.includes('copied path wiki/index.md')`,
      "single selection copy path status",
    );
    await clickTestId(session, "desk-toggle-favorite");
    await waitFor(
      session,
      `[...document.querySelectorAll('[data-testid="desk-favorite-row"]')].some(row => row.dataset.path === 'wiki/index.md')`,
      "Desk favorite quick access row",
    );
    await waitFor(
      session,
      `!document.querySelector('[data-testid="desk-up"]')?.disabled && !document.querySelector('[data-testid="desk-root"]')?.disabled`,
      "non-root toolbar navigation enabled",
    );
    await clickTestId(session, "desk-back");
    await waitFor(
      session,
      rowExistsExpression("wiki"),
      "history back to root",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-up"]')?.disabled && document.querySelector('[data-testid="desk-root"]')?.disabled`,
      "root toolbar navigation disabled",
    );
    await clickTestId(session, "desk-forward");
    await waitFor(
      session,
      rowExistsExpression("wiki/index.md"),
      "history forward to wiki",
    );
    await openDetailsTestId(session, "desk-go-to-folder");
    await setInputByTestId(session, "desk-location-input", "raw");
    await clickTestId(session, "desk-location-go");
    await waitFor(session, rowExistsExpression("raw/evidence.txt"), "location bar opened raw");
    await setInputByTestId(session, "desk-location-input", "wiki/../raw");
    await keyDownInputByTestId(session, "desk-location-input", "Enter");
    await waitFor(
      session,
      rowExistsExpression("raw/evidence.txt"),
      "location bar canonicalized parent segment to raw",
    );
    await waitFor(
      session,
      `!document.querySelector('[data-testid="desk-up"]')?.disabled && !document.querySelector('[data-testid="desk-root"]')?.disabled`,
      "raw toolbar navigation enabled",
    );
    await clickTestId(session, "desk-root");
    await waitFor(session, rowExistsExpression("wiki"), "Root toolbar returned to root");
    await setInputByTestId(session, "desk-location-input", "/wiki/");
    await keyDownInputByTestId(session, "desk-location-input", "Enter");
    await waitFor(session, rowExistsExpression("wiki/index.md"), "location bar Enter returned to wiki");
    await clickTestId(session, "desk-up");
    await waitFor(session, rowExistsExpression("wiki"), "Up toolbar returned to parent root");
    await setInputByTestId(session, "desk-location-input", "/wiki/");
    await keyDownInputByTestId(session, "desk-location-input", "Enter");
    await waitFor(session, rowExistsExpression("wiki/index.md"), "location bar Enter reopened wiki after Up");
    await closeDetailsTestId(session, "desk-go-to-folder");
    await setInputByTestId(session, "desk-new-item-name", "Shortcut Folder");
    await keyDownFileList(session, "N", { ctrlKey: true, shiftKey: true });
    await waitFor(
      session,
      rowExistsExpression("wiki/Shortcut Folder"),
      "Ctrl+Shift+N created a folder in the current directory",
    );
    await waitForFile(
      path.join(fixtureRoot, "books/research-alpha/wiki/Shortcut Folder"),
      "shortcut-created folder",
    );
    const deskStatusSemantics = await session.evaluate(`(() => {
      const status = document.querySelector('.desk-create-status');
      return {
        role: status?.getAttribute('role') ?? '',
        live: status?.getAttribute('aria-live') ?? ''
      };
    })()`);
    assert(
      deskStatusSemantics.role === "status" && deskStatusSemantics.live === "polite",
      `Desk operation feedback should be announced: ${JSON.stringify(deskStatusSemantics)}`,
    );
    await setInputByTestId(session, "desk-filter-query", "notes");
    await waitFor(session, rowExistsExpression("wiki/notes"), "filter shows notes directory");
    await waitFor(
      session,
      `!${rowExistsExpression("wiki/index.md")}`,
      "filter hides nonmatching wiki index row",
    );
    await waitFor(
      session,
      `document.querySelector('.desk-location-meta')?.textContent.includes('No selection')`,
      "filter clears selection hidden by current folder filter",
    );
    await waitFor(
      session,
      `!(document.querySelector('[data-testid="desk-preview"]')?.textContent || '').includes('Alpha Desk')`,
      "filter does not leave hidden file preview visible",
    );
    await waitFor(
      session,
      `!(document.querySelector('[data-testid="desk-details"]')?.textContent || '').includes('index.md')`,
      "filter does not leave hidden file details visible",
    );
    await waitFor(
      session,
      `!!document.querySelector('[data-testid="desk-reveal-current-directory"]')`,
      "current directory reveal control after hidden selection",
    );
    await clickTestId(session, "desk-clear-filter");
    await waitFor(session, rowExistsExpression("wiki/index.md"), "clearing filter restores wiki index row");

    await setInputByTestId(session, "desk-new-item-name", "browser-created");
    await clickTestId(session, "desk-new-folder");
    await waitFor(session, rowExistsExpression("wiki/browser-created"), "created folder row");
    assert(
      fs.existsSync(path.join(fixtureRoot, "books/research-alpha/wiki/browser-created")),
      "Browser-created folder was not written inside the MoonBook",
    );

    await doubleClickPath(session, "wiki/browser-created");
    await waitFor(
      session,
      `document.querySelector('.desk-browser-head h2')?.textContent.includes('wiki/browser-created')`,
      "created folder directory",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-empty-folder"]')?.textContent.includes('This folder is empty')`,
      "empty folder state",
    );
    await waitFor(
      session,
      `!(document.querySelector('[data-testid="desk-empty-folder"]')?.textContent || '').includes('No virtual files loaded')`,
      "empty folder avoids developer loading copy",
    );
    await setInputByTestId(session, "desk-new-item-name", "daily-browser");
    await clickTestId(session, "desk-new-note");
    await waitFor(session, rowExistsExpression("wiki/browser-created/daily-browser.md"), "created note row");
    const notePath = path.join(
      fixtureRoot,
      "books/research-alpha/wiki/browser-created/daily-browser.md",
    );
    assert(fs.existsSync(notePath), "Browser-created note was not written inside the MoonBook");

    const refreshedPath = path.join(
      fixtureRoot,
      "books/research-alpha/wiki/browser-created/external-refresh.md",
    );
    fs.writeFileSync(refreshedPath, "# External Refresh\n\nCreated outside the UI.\n", "utf8");
    const externalVisibleBeforeRefresh = await session.evaluate(
      rowExistsExpression("wiki/browser-created/external-refresh.md"),
    );
    assert(!externalVisibleBeforeRefresh, "Out-of-band file appeared before Desk refresh");
    await clickTestId(session, "desk-refresh");
    await waitFor(
      session,
      rowExistsExpression("wiki/browser-created/external-refresh.md"),
      "refreshed external file row",
    );
    await importTextFileThroughDeskBrowser(
      session,
      "desk-dropped.txt",
      "dropped into desk\n",
    );
    const droppedPath = path.join(
      fixtureRoot,
      "books/research-alpha/wiki/browser-created/desk-dropped.txt",
    );
    try {
      await waitForFile(droppedPath, "dropped Desk import file", 15000);
    } catch (error) {
      const dropState = await session.evaluate(`(() => ({
        deskStatus: document.querySelector('.desk-create-status')?.textContent ?? '',
        inboxStatus: document.querySelector('.inbox-status')?.textContent ?? '',
        visibleMode: document.querySelector('[data-testid="desk-mode"]') ? 'desk' : 'other',
        queued: window.__moondeskImportState?.queue?.length ?? -1
      }))()`);
      throw new Error(`${error.message}; Desk state: ${JSON.stringify(dropState)}`);
    }
    await waitFor(
      session,
      rowExistsExpression("wiki/browser-created/desk-dropped.txt"),
      "dropped Desk import row",
      15000,
    );
    await importTextFileThroughDeskBrowser(
      session,
      "folder-evidence.txt",
      "folder drop into desk\n",
      "desk-folder/nested/folder-evidence.txt",
    );
    const droppedFolderPath = path.join(
      fixtureRoot,
      "books/research-alpha/wiki/browser-created/desk-folder/nested/folder-evidence.txt",
    );
    await waitForFile(droppedFolderPath, "dropped Desk folder import file", 15000);
    await waitFor(
      session,
      rowExistsExpression("wiki/browser-created/desk-folder"),
      "dropped Desk folder row",
      15000,
    );

    await setInputByTestId(session, "desk-new-item-name", "rename-browser");
    await clickTestId(session, "desk-new-note");
    await waitFor(session, rowExistsExpression("wiki/browser-created/rename-browser.md"), "rename source note row");
    const renameSourcePath = path.join(
      fixtureRoot,
      "books/research-alpha/wiki/browser-created/rename-browser.md",
    );
    const renameTargetPath = path.join(
      fixtureRoot,
      "books/research-alpha/wiki/browser-created/renamed-browser.md",
    );
    assert(fs.existsSync(renameSourcePath), "Inline rename source note was not created");
    await mouseDownPath(session, "wiki/browser-created/rename-browser.md");
    await keyDownFileList(session, "F2");
    await waitFor(
      session,
      `!![...document.querySelectorAll('[data-testid="desk-inline-rename"]')]
        .find(input => input.dataset.path === 'wiki/browser-created/rename-browser.md')`,
      "inline rename input",
    );
    await setInlineRename(session, "wiki/browser-created/rename-browser.md", "renamed-browser");
    await keyDownInlineRename(session, "wiki/browser-created/rename-browser.md", "Enter");
    await waitForFile(renameTargetPath, "inline renamed note file");
    await waitForMissingFile(renameSourcePath, "inline rename source note file");
    await waitFor(session, rowExistsExpression("wiki/browser-created/renamed-browser.md"), "inline renamed note row");

    await mouseDownPath(session, "wiki/browser-created/daily-browser.md");
    const copiedNotePath = path.join(
      fixtureRoot,
      "books/research-alpha/wiki/browser-created/daily-browser copy.md",
    );
    await clickDetailsButton(session, "Duplicate");
    await waitForFile(copiedNotePath, "duplicated note file");
    const copiedRowVisible = await waitFor(
      session,
      rowExistsExpression("wiki/browser-created/daily-browser copy.md"),
      "duplicated note row",
    ).catch(async error => {
      const rows = await session.evaluate(visibleRowsExpression());
      const details = await session.evaluate(
        `document.querySelector('[data-testid="desk-details"]')?.textContent ?? ''`,
      );
      throw new Error(
        `${error.message}; visible rows=${JSON.stringify(rows)}; details=${JSON.stringify(details)}`,
      );
    });
    assert(
      copiedRowVisible,
      "Duplicated note was not visible beside the source",
    );

    await mouseDownPath(session, "wiki/browser-created/daily-browser.md");
    await keyDownFileList(session, "c", { ctrlKey: true });
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-details"]')?.textContent.includes('copied wiki/browser-created/daily-browser.md')`,
      "keyboard copied note clipboard status",
    );
    await setInputByTestId(session, "desk-new-item-name", "browser-target");
    await clickTestId(session, "desk-new-folder");
    await waitFor(session, rowExistsExpression("wiki/browser-created/browser-target"), "paste target folder row");
    await doubleClickPath(session, "wiki/browser-created/browser-target");
    await waitFor(
      session,
      `document.querySelector('.desk-browser-head h2')?.textContent.includes('wiki/browser-created/browser-target')`,
      "paste target directory",
    );
    await keyDownFileList(session, "v", { ctrlKey: true });
    const pastedNotePath = path.join(
      fixtureRoot,
      "books/research-alpha/wiki/browser-created/browser-target/daily-browser.md",
    );
    await waitForFile(pastedNotePath, "pasted note file");
    await waitFor(
      session,
      rowExistsExpression("wiki/browser-created/browser-target/daily-browser.md"),
      "pasted note row",
    );
    assert(fs.existsSync(notePath), "Pasting note removed the source file");

    await setInputByTestId(session, "desk-new-item-name", "cut-target");
    await clickTestId(session, "desk-new-folder");
    await waitFor(session, rowExistsExpression("wiki/browser-created/browser-target/cut-target"), "cut target folder row");
    await setInputByTestId(session, "desk-new-item-name", "cut-source");
    await clickTestId(session, "desk-new-note");
    await waitFor(session, rowExistsExpression("wiki/browser-created/browser-target/cut-source.md"), "cut source note row");
    const cutSourcePath = path.join(
      fixtureRoot,
      "books/research-alpha/wiki/browser-created/browser-target/cut-source.md",
    );
    const cutMovedPath = path.join(
      fixtureRoot,
      "books/research-alpha/wiki/browser-created/browser-target/cut-target/cut-source.md",
    );
    assert(fs.existsSync(cutSourcePath), "Cut source note was not created before moving");
    await mouseDownPath(session, "wiki/browser-created/browser-target/cut-source.md");
    await keyDownFileList(session, "x", { ctrlKey: true });
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-details"]')?.textContent.includes('cut wiki/browser-created/browser-target/cut-source.md')`,
      "keyboard cut note clipboard status",
    );
    await doubleClickPath(session, "wiki/browser-created/browser-target/cut-target");
    await waitFor(
      session,
      `document.querySelector('.desk-browser-head h2')?.textContent.includes('wiki/browser-created/browser-target/cut-target')`,
      "cut target directory",
    );
    await keyDownFileList(session, "v", { ctrlKey: true });
    await waitForFile(cutMovedPath, "cut-pasted note file");
    await waitForMissingFile(cutSourcePath, "cut source note file");
    await waitFor(
      session,
      rowExistsExpression("wiki/browser-created/browser-target/cut-target/cut-source.md"),
      "cut-pasted note row",
    );
    await mouseDownPath(session, "wiki/browser-created/browser-target/cut-target/cut-source.md");
    await clickDetailsButton(session, "Move to Trash");
    await waitForMissingFile(cutMovedPath, "trashed UI note file");
    await waitFor(
      session,
      `![...document.querySelectorAll('[data-testid="desk-file-row"]')]
        .some(row => row.dataset.path === 'wiki/browser-created/browser-target/cut-target/cut-source.md')`,
      "trashed note hidden from current directory",
    );
    assert(
      fs.existsSync(path.join(fixtureRoot, ".moonsuite/products/moondesk/trash/files")),
      "Desk trash directory was not created in the MoonDesk product home",
    );
    assert(
      !fs.existsSync(path.join(fixtureRoot, "books/research-alpha/.moontown/trash")),
      "Desk trash should not recreate legacy book-local .moontown trash",
    );
    assert(
      !fs.existsSync(path.join(fixtureRoot, "books/research-alpha/.moonsuite/products/moondesk/trash")),
      "Desk trash should not create nested book-local MoonDesk product trash",
    );
    await waitFor(
      session,
      trashRowExpression("wiki/browser-created/browser-target/cut-target/cut-source.md"),
      "trash listing row for moved note",
    );
    await clickTrashRow(session, "wiki/browser-created/browser-target/cut-target/cut-source.md");
    await waitForFile(cutMovedPath, "restored UI note file");
    await waitFor(
      session,
      rowExistsExpression("wiki/browser-created/browser-target/cut-target/cut-source.md"),
      "restored note row",
    );
    await waitFor(
      session,
      `!${trashRowExpression("wiki/browser-created/browser-target/cut-target/cut-source.md")}`,
      "restored note removed from trash listing",
    );

    await clickWorkspace(session, "book-research-beta");
    await waitFor(session, rowExistsExpression("wiki"), "beta root wiki row");
    await doubleClickPath(session, "wiki");
    await waitFor(session, rowExistsExpression("wiki/index.md"), "beta wiki index row");
    await mouseDownPath(session, "wiki/index.md");
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-preview"]')?.textContent.includes('Beta Desk')`,
      "workspace switch preview",
    );
    screenshots.push(await captureDeskViewport(session, "mobile", 390, 844));
    console.log(`Desk screenshots: ${screenshots.join(", ")}`);
    session.assertNoPageProblems("Desk full smoke");
  } finally {
    session.close();
  }
}

async function runEmptyLibrary() {
  const session = await connect(cdpPort);
  const screenshots = [];
  try {
    await session.send("Page.enable");
    await enablePageProblemCapture(session);
    await setViewport(session, 1440, 900);
    await session.send("Page.navigate", { url: baseUrl });
    await waitFor(
      session,
      `document.readyState === 'complete' && !!document.querySelector('[data-testid="desk-mode"]')`,
      "empty Desk mode",
    );
    await waitFor(
      session,
      `document.querySelectorAll('[data-testid="desk-workspace-row"]').length === 0`,
      "empty MoonBook library rows",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-workspace-list"]')?.textContent.includes('No MoonBooks in this workspace')`,
      "empty MoonBook library message",
    );
    const libraryState = await session.evaluate(`(() => {
      const root = document.querySelector('[data-testid="desk-library-root"]');
      const summary = root?.querySelector(':scope > .desk-library-summary');
      const diagnostics = root?.querySelector('[data-testid="desk-library-storage-details"]');
      return {
        primaryText: summary?.textContent ?? '',
        visibleText: root?.innerText ?? '',
        diagnosticText: diagnostics?.textContent ?? '',
        diagnosticsOpen: diagnostics?.open === true,
        addBookOpen: document.querySelector('[data-testid="desk-add-moonbook"]')?.open === true,
      };
    })()`);
    assert(
      libraryState.primaryText.includes("My MoonBooks") &&
        libraryState.primaryText.includes("0 MoonBooks") &&
        !libraryState.primaryText.includes("books/") &&
        !libraryState.visibleText.includes("MoonClaw") &&
        libraryState.diagnosticText.includes(path.join(fixtureRoot, "books")) &&
        !libraryState.diagnosticsOpen &&
        !libraryState.addBookOpen,
      `Empty Desk should hide implementation details by default: ${JSON.stringify(libraryState)}`,
    );
    const disabledEmptyActions = await session.evaluate(`(() => {
      const ids = [
        "desk-new-item-name",
        "desk-new-folder",
        "desk-new-note",
        "desk-filter-query",
        "desk-clear-filter",
        "desk-import-files",
        "desk-import-folder",
        "desk-location-input",
        "desk-location-go",
        "desk-paste-clipboard",
        "desk-copy-path",
        "desk-reveal-current-directory"
      ];
      return ids
        .map(id => {
          const el = document.querySelector('[data-testid="' + id + '"]');
          return [id, !el || el.disabled === true];
        })
        .filter(([, disabled]) => !disabled)
        .map(([id]) => id);
    })()`);
    assert(
      disabledEmptyActions.length === 0,
      `Empty Desk library should disable scoped file actions: ${disabledEmptyActions.join(", ")}`,
    );
    screenshots.push(await captureDeskViewport(session, "empty-library", 1440, 900));

    await openDetailsTestId(session, "desk-add-moonbook");
    await setInputByTestId(session, "desk-new-book-name", "Empty Library Created MoonBook");
    await setInputByTestId(session, "desk-new-book-id", "empty-library-created");
    await clickTestId(session, "desk-create-book");
    await waitFor(
      session,
      `[...document.querySelectorAll('[data-testid="desk-workspace-row"]')]` +
        `.some(row => row.dataset.workspaceId === 'book-empty-library-created' && row.title.includes('books/empty-library-created'))`,
      "created MoonBook row from empty library",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="desk-library-root"]')?.textContent.includes('1 MoonBook')`,
      "MoonBook library count after empty create",
    );
    await waitFor(
      session,
      `document.querySelector('.desk-browser-head h2')?.textContent.includes('wiki') && ${rowExistsExpression("wiki/index.md")}`,
      "empty-created MoonBook opens starter wiki",
    );
    const enabledCreatedActions = await session.evaluate(`(() => {
      const ids = [
        "desk-new-item-name",
        "desk-new-folder",
        "desk-new-note",
        "desk-filter-query",
        "desk-import-files",
        "desk-import-folder",
        "desk-location-input",
        "desk-location-go"
      ];
      return ids
        .map(id => [id, document.querySelector('[data-testid="' + id + '"]')?.disabled === false])
        .filter(([, enabled]) => !enabled)
        .map(([id]) => id);
    })()`);
    assert(
      enabledCreatedActions.length === 0,
      `Created MoonBook should enable scoped file actions: ${enabledCreatedActions.join(", ")}`,
    );
    const createdBookRoot = path.join(fixtureRoot, "books/empty-library-created");
    await waitForFile(path.join(createdBookRoot, "book.json"), "empty-created book.json");
    await waitForFile(path.join(createdBookRoot, "wiki/index.md"), "empty-created starter wiki");
    assert(
      !fs.existsSync(path.join(fixtureRoot, "empty-library-created")),
      "Empty-created MoonBook should not be written at the workspace root",
    );
    await closeDetailsTestId(session, "desk-add-moonbook");
    screenshots.push(await captureDeskViewport(session, "empty-created", 1440, 900));
    await session.send("Page.navigate", {
      url: `${baseUrl}/?activity=desk&workspace=book-empty-library-created`,
    });
    await waitFor(
      session,
      `document.readyState === 'complete' && ` +
        `document.querySelector('[data-testid="mode-desk"]')?.getAttribute('aria-pressed') === 'true' && ` +
        `document.querySelectorAll('[data-testid="desk-workspace-row"]').length === 1`,
      "loaded Desk before MoonGate recovery",
    );
    await clickTestId(session, "mode-code");
    await waitFor(
      session,
      `document.readyState === 'complete' && !!document.querySelector('[data-testid="mooncode-open-moongate"]')`,
      "MoonGate recovery control",
    );
    const moonGateControlDebug = await session.evaluate(`(() => {
      const el = document.querySelector('[data-testid="mooncode-open-moongate"]');
      const rect = el?.getBoundingClientRect();
      const hit = rect ? document.elementFromPoint(rect.left + rect.width / 2, rect.top + rect.height / 2) : null;
      return {
        html: el?.outerHTML ?? '',
        rect: rect ? { x: rect.x, y: rect.y, width: rect.width, height: rect.height } : null,
        hit: hit?.outerHTML ?? '',
        disabled: el?.disabled === true,
      };
    })()`);
    assert(
      moonGateControlDebug.rect &&
        moonGateControlDebug.rect.width > 0 &&
        moonGateControlDebug.rect.height > 0 &&
        moonGateControlDebug.hit.includes('mooncode-open-moongate') &&
        !moonGateControlDebug.disabled,
      `MoonGate recovery control is not a visible pointer target: ${JSON.stringify(moonGateControlDebug)}`,
    );
    console.log(`MoonGate recovery pointer target: ${JSON.stringify(moonGateControlDebug)}`);
    await pointerClickTestId(session, "mooncode-open-moongate");
    await waitFor(
      session,
      `location.search.includes('activity=desk') && ` +
        `location.search.includes('workspace=book-empty-library-created') && ` +
        `document.querySelector('[data-testid="mode-desk"]')?.getAttribute('aria-pressed') === 'true'`,
      "MoonGate recovery Desk action",
    );
    console.log(`Desk empty-library screenshots: ${screenshots.join(", ")}`);
    session.assertNoPageProblems("Desk empty-library smoke");
  } finally {
    session.close();
  }
}

const runner = scenario === "empty" ? runEmptyLibrary : run;
runner().catch(error => {
  console.error(error.stack || error.message);
  process.exit(1);
});
