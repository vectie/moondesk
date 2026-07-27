import fs from "node:fs";
import path from "node:path";

const [baseUrl, cdpPort, fixtureRoot, scenario = "full"] = process.argv.slice(2);

if (!baseUrl || !cdpPort || !fixtureRoot) {
  throw new Error(
    "usage: desk_mode_browser_smoke.mjs <base-url> <cdp-port> <fixture-root> " +
      "[full|empty|accessibility|screen-reader|capability|capability-responsive|capability-scale|" +
      "keyboard-transients|quickstart-before-restart|quickstart-after-restart]",
  );
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// Reversible WCAG large-text simulation. This deliberately changes only inline
// font-size declarations: viewport, device scale, and pre-existing box sizing
// remain untouched. Controls are HTMLElements, so their rendered type is
// included rather than relying on inheritance alone.
async function setTextOnlyScale(session, factor = 2) {
  assert(factor > 0, "text-only scale factor must be positive");
  return session.evaluate(`(async () => {
    const key = "__deskTextOnlyFontSize";
    const elements = Array.from(document.querySelectorAll("*"))
      .filter(element => element instanceof HTMLElement);
    const snapshots = elements.map(element => ({
      element,
      inlineFontSize: element.style.fontSize,
      computedPixels: Number.parseFloat(getComputedStyle(element).fontSize)
    }));
    if (snapshots.some(({ element }) => key in element.dataset)) {
      throw new Error("text-only scale is already active");
    }
    if (snapshots.some(({ computedPixels }) => !Number.isFinite(computedPixels))) {
      throw new Error("non-pixel computed font size");
    }
    for (const { element, inlineFontSize, computedPixels } of snapshots) {
      element.dataset[key] = inlineFontSize;
      element.style.fontSize =
        String(computedPixels * ${JSON.stringify(factor)}) + "px";
    }
    await new Promise(resolve => requestAnimationFrame(() =>
      requestAnimationFrame(resolve)));
    return { factor: ${JSON.stringify(factor)}, elementCount: elements.length,
      viewport: { width: innerWidth, height: innerHeight }, devicePixelRatio };
  })()`);
}

async function restoreTextOnlyScale(session) {
  return session.evaluate(`(async () => {
    const key = "__deskTextOnlyFontSize";
    let restored = 0;
    for (const element of document.querySelectorAll("[data-__desk-text-only-font-size]")) {
      if (!(element instanceof HTMLElement)) continue;
      element.style.fontSize = element.dataset[key] || "";
      delete element.dataset[key];
      restored += 1;
    }
    await new Promise(resolve => requestAnimationFrame(() =>
      requestAnimationFrame(resolve)));
    return restored;
  })()`);
}

async function textOnlyScaleCoverage(session) {
  return session.evaluate(`(() => {
    const elements = Array.from(document.querySelectorAll("*"))
      .filter(element => element instanceof HTMLElement);
    const marked = elements.filter(element =>
      "__deskTextOnlyFontSize" in element.dataset
    );
    return {
      active: marked.length > 0,
      elementCount: elements.length,
      markedCount: marked.length,
      unmarkedCount: elements.length - marked.length
    };
  })()`);
}

async function collectTextOnlyGeometry(session, expectedWidth, expectedHeight) {
  return session.evaluate(`(() => {
    const rect = element => {
      const box = element.getBoundingClientRect();
      return { left: box.left, top: box.top, right: box.right, bottom: box.bottom,
        width: box.width, height: box.height };
    };
    const rendered = element => {
      const box = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return box.width > 0 && box.height > 0 && style.visibility !== "hidden" &&
        style.display !== "none";
    };
    const compact = innerWidth <= 760;
    const selectors = {
      headings: ".desk-browser-head h2",
      navigation: compact
        ? "[data-testid=primary-nav-summary]"
        : ".primary-nav-desktop [data-testid^=mode-]",
      selectedBook: "[data-testid=desk-workspace-row].active",
      currentPath: ".desk-browser-head h2",
      actions: "[data-testid=desk-refresh],[data-testid=desk-up],[data-testid=desk-root]",
      historyActions: "[data-testid=desk-back],[data-testid=desk-forward]"
    };
    const targets = Object.fromEntries(Object.entries(selectors).map(([name, selector]) =>
      [name, Array.from(document.querySelectorAll(selector)).filter(rendered).map(element => ({
        text: (element.innerText || element.getAttribute("aria-label") || "").trim(), rect: rect(element),
        enabled: !("disabled" in element) || !element.disabled,
        clipped: element.scrollWidth > element.clientWidth + 1 || element.scrollHeight > element.clientHeight + 1
      }))]));
    const panes = Array.from(
      document.querySelectorAll(".desk-sidebar,.desk-browser,.desk-details")
    ).filter(rendered).map(element => ({
      className: element.className,
      rect: rect(element)
    }));
    return { viewport: {
        width: document.documentElement.clientWidth,
        height: document.documentElement.clientHeight
      },
      expectedViewport: { width: ${expectedWidth}, height: ${expectedHeight} },
      devicePixelRatio, documentWidth: document.documentElement.scrollWidth,
      horizontalOverflow:
        document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
      compactPrimaryVisible: rendered(
        document.querySelector("[data-testid=primary-nav-summary]") || document.body
      ) && !!document.querySelector("[data-testid=primary-nav-summary]"),
      desktopPrimaryVisible: Array.from(
        document.querySelectorAll(".primary-nav-desktop [data-testid^=mode-]")
      ).some(rendered),
      panes, targets };
  })()`);
}

class CdpSession {
  constructor(ws) {
    this.ws = ws;
    this.nextId = 1;
    this.pending = new Map();
    this.eventListeners = new Map();
    this.pageProblems = [];
    ws.addEventListener("message", event => {
      const message = JSON.parse(event.data);
      if (!message.id || !this.pending.has(message.id)) {
        for (const listener of this.eventListeners.get(message.method) ?? []) {
          listener(message.params ?? {});
        }
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

  on(method, listener) {
    const listeners = this.eventListeners.get(method) ?? new Set();
    listeners.add(listener);
    this.eventListeners.set(method, listeners);
  }

  off(method, listener) {
    const listeners = this.eventListeners.get(method);
    listeners?.delete(listener);
    if (listeners?.size === 0) {
      this.eventListeners.delete(method);
    }
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
  await session.send("DOM.enable");
  await session.send("Accessibility.enable");
  session.clearPageProblems();
}

function accessibilityValue(value) {
  if (!value || typeof value !== "object") {
    return value ?? null;
  }
  return value.value ?? value.description ?? null;
}

async function accessibilityNodeForSelector(session, selector) {
  const evaluated = await session.send("Runtime.evaluate", {
    expression: `document.querySelector(${JSON.stringify(selector)})`,
    returnByValue: false,
  });
  const objectId = evaluated.result?.objectId;
  assert(objectId, `Accessibility selector is missing: ${selector}`);
  const described = await session.send("DOM.describeNode", { objectId });
  const backendNodeId = described.node?.backendNodeId;
  assert(backendNodeId, `Accessibility selector has no backend node: ${selector}`);
  const tree = await session.send("Accessibility.getPartialAXTree", {
    backendNodeId,
    fetchRelatives: false,
  });
  const node =
    tree.nodes?.find(item => item.backendDOMNodeId === backendNodeId && !item.ignored) ??
    tree.nodes?.find(item => !item.ignored);
  assert(node, `Accessibility tree omitted ${selector}: ${JSON.stringify(tree.nodes)}`);
  return {
    selector,
    backendNodeId,
    role: accessibilityValue(node.role),
    name: accessibilityValue(node.name),
    description: accessibilityValue(node.description),
    properties: Object.fromEntries(
      (node.properties ?? []).map(property => [
        property.name,
        accessibilityValue(property.value),
      ]),
    ),
  };
}

async function pauseNextRequest(session, urlPattern) {
  let pausedResolve;
  let pausedReject;
  const paused = new Promise((resolve, reject) => {
    pausedResolve = resolve;
    pausedReject = reject;
  });
  let request = null;
  const listener = params => {
    if (!request && params.request?.url?.includes(urlPattern)) {
      request = params;
      pausedResolve(params);
    }
  };
  session.on("Fetch.requestPaused", listener);
  try {
    await session.send("Fetch.enable", {
      patterns: [{ urlPattern: `*${urlPattern}*`, requestStage: "Request" }],
    });
  } catch (error) {
    session.off("Fetch.requestPaused", listener);
    pausedReject(error);
    throw error;
  }
  return {
    paused,
    async wait(timeoutMs = 15_000) {
      let timer;
      try {
        return await Promise.race([
          paused,
          new Promise((_, reject) => {
            timer = setTimeout(
              () => reject(
                new Error(`Timed out waiting for an intercepted ${urlPattern} request`),
              ),
              timeoutMs,
            );
          }),
        ]);
      } catch (error) {
        session.off("Fetch.requestPaused", listener);
        await session.send("Fetch.disable");
        throw error;
      } finally {
        clearTimeout(timer);
      }
    },
    async fail(errorReason = "Failed") {
      const params = request ?? await this.wait();
      await session.send("Fetch.failRequest", {
        requestId: params.requestId,
        errorReason,
      });
      session.off("Fetch.requestPaused", listener);
      await session.send("Fetch.disable");
      return params.request?.url ?? "";
    },
    async cancel() {
      session.off("Fetch.requestPaused", listener);
      await session.send("Fetch.disable");
    },
  };
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

async function setViewport(
  session,
  width,
  height,
  mobile = width <= 760,
  resetDeviceMetrics = false,
) {
  if (resetDeviceMetrics) {
    await session.send("Emulation.clearDeviceMetricsOverride");
  }
  await session.send("Emulation.setDeviceMetricsOverride", {
    width,
    height,
    deviceScaleFactor: 1,
    mobile,
  });
}

async function setEnglishLocale(session) {
  await session.send("Emulation.setLocaleOverride", { locale: "en-US" });
}

async function dispatchKey(session, key, code = key, options = {}) {
  const keyCode = key === "Escape"
    ? 27
    : key === "Enter"
      ? 13
      : key === " "
        ? 32
        : key === "Tab"
          ? 9
          : key === "Backspace"
            ? 8
            : key.length === 1
              ? key.toUpperCase().charCodeAt(0)
              : 0;
  const modifiers =
    (options.alt ? 1 : 0) |
    (options.ctrl ? 2 : 0) |
    (options.meta ? 4 : 0) |
    (options.shift ? 8 : 0);
  const text = modifiers === 0
    ? key === "Enter"
      ? "\r"
      : key === " "
        ? " "
        : ""
    : "";
  await session.send("Input.dispatchKeyEvent", {
    type: "keyDown",
    key,
    code,
    modifiers,
    ...(options.commands ? { commands: options.commands } : {}),
    ...(text ? { text, unmodifiedText: text } : {}),
    windowsVirtualKeyCode: keyCode,
    nativeVirtualKeyCode: keyCode,
  });
  await session.send("Input.dispatchKeyEvent", {
    type: "keyUp",
    key,
    code,
    modifiers,
    windowsVirtualKeyCode: keyCode,
    nativeVirtualKeyCode: keyCode,
  });
}

async function activeKeyboardFocus(session) {
  return session.evaluate(`(() => {
    const el = document.activeElement;
    if (!(el instanceof HTMLElement)) {
      return {
        key: "",
        tag: "",
        testid: "",
        owningTestid: "",
        workspaceId: "",
        visible: false,
        inViewport: false,
        focusVisible: false,
        focusIndicator: false,
        disabled: true
      };
    }
    const rect = el.getBoundingClientRect();
    const style = getComputedStyle(el);
    const focusables = [...document.querySelectorAll(
      'a[href], button, input, textarea, select, details > summary, [tabindex]:not([tabindex="-1"])'
    )].filter(candidate => {
      if (!(candidate instanceof HTMLElement)) return false;
      const candidateRect = candidate.getBoundingClientRect();
      const candidateStyle = getComputedStyle(candidate);
      return candidateRect.width > 0 &&
        candidateRect.height > 0 &&
        candidateStyle.display !== 'none' &&
        candidateStyle.visibility !== 'hidden' &&
        candidate.getAttribute('aria-hidden') !== 'true' &&
        !candidate.matches(':disabled');
    });
    const testid = el.dataset.testid || '';
    const owningTestid = el.closest('[data-testid]')?.dataset.testid || '';
    const owningDetails = el.closest('details');
    const owningDialog = el.closest('[role="dialog"]');
    const workspaceId = el.dataset.workspaceId || '';
    const index = focusables.indexOf(el);
    const text = (
      el.getAttribute('aria-label') ||
      el.textContent ||
      el.getAttribute('placeholder') ||
      ''
    ).trim().replace(/\\s+/g, ' ').slice(0, 120);
    return {
      key: [
        el.tagName.toLowerCase(),
        testid,
        workspaceId,
        String(index),
        text
      ].join('|'),
      tag: el.tagName.toLowerCase(),
      testid,
      owningTestid,
      detailsTestid: owningDetails?.dataset.testid || '',
      detailsSummaryTestid:
        owningDetails?.querySelector(':scope > summary')?.dataset.testid || '',
      dialogTestid: owningDialog?.dataset.testid || '',
      detailsOpen:
        owningDetails instanceof HTMLDetailsElement && owningDetails.open,
      workspaceId,
      text,
      index,
      visible: rect.width > 0 &&
        rect.height > 0 &&
        style.display !== 'none' &&
        style.visibility !== 'hidden',
      inViewport: rect.width > 0 &&
        rect.height > 0 &&
        rect.right > 0 &&
        rect.bottom > 0 &&
        rect.left < innerWidth &&
        rect.top < innerHeight,
      focusVisible: el.matches(':focus-visible'),
      focusIndicator:
        (
          Number.parseFloat(style.outlineWidth) >= 2 &&
          style.outlineStyle !== 'none' &&
          style.outlineColor !== 'transparent' &&
          style.outlineColor !== 'rgba(0, 0, 0, 0)'
        ) ||
        style.boxShadow !== 'none',
      outlineWidth: style.outlineWidth,
      outlineStyle: style.outlineStyle,
      outlineColor: style.outlineColor,
      boxShadow: style.boxShadow,
      rect: {
        left: rect.left,
        top: rect.top,
        right: rect.right,
        bottom: rect.bottom
      },
      disabled: el.matches(':disabled'),
      connected: el.isConnected
    };
  })()`);
}

async function proveOwnedDisclosureKeyboardRestoration(
  session,
  {
    caseId,
    surface,
    owningTestid,
    screenshotName = "",
    maxSteps = 160,
  },
) {
  const label = `${caseId} ${surface} technical details`;
  const trace = [];
  const naturalFocus = await activeKeyboardFocus(session);
  trace.push({ operation: "Natural document focus", label, ...naturalFocus });
  assert(
    naturalFocus.tag === "body" &&
      naturalFocus.index === -1 &&
      naturalFocus.owningTestid === "",
    `${label} did not start from natural document focus: ` +
      `${JSON.stringify(naturalFocus)}`,
  );

  const seen = new Set();
  let trigger = null;
  for (let step = 1; step <= maxSteps; step += 1) {
    await dispatchKey(session, "Tab", "Tab");
    await waitTwoAnimationFrames(session);
    const focus = await activeKeyboardFocus(session);
    trace.push({ operation: "Tab", label, step, ...focus });
    assert(
      focus.connected &&
        focus.visible &&
        focus.inViewport &&
        !focus.disabled &&
        focus.focusVisible &&
        focus.focusIndicator,
      `${label} reached a target without a usable visible keyboard focus: ` +
        `${JSON.stringify(focus)}`,
    );
    if (focus.tag === "summary" && focus.owningTestid === owningTestid) {
      trigger = focus;
      break;
    }
    assert(
      !seen.has(focus.key),
      `${label} cycled before reaching its owned summary: ${JSON.stringify(trace)}`,
    );
    seen.add(focus.key);
  }
  assert(
    trigger !== null,
    `${label} did not reach its owned summary within ${maxSteps} Tab steps`,
  );
  assert(!trigger.detailsOpen, `${label} started open: ${JSON.stringify(trigger)}`);

  await dispatchKey(session, " ", "Space");
  await waitTwoAnimationFrames(session);
  const opened = await activeKeyboardFocus(session);
  trace.push({ operation: "Space", label, ...opened });
  assert(
    opened.key === trigger.key &&
      opened.detailsOpen &&
      opened.focusVisible &&
      opened.focusIndicator,
    `${label} did not open from Space while retaining visible focus: ` +
      `${JSON.stringify(opened)}`,
  );

  await dispatchKey(session, "Escape", "Escape");
  await waitTwoAnimationFrames(session);
  const restored = await activeKeyboardFocus(session);
  trace.push({ operation: "Escape", label, ...restored });
  assert(
    restored.key === trigger.key &&
      !restored.detailsOpen &&
      restored.focusVisible &&
      restored.focusIndicator,
    `${label} did not close and restore the exact trigger on Escape: ` +
      `${JSON.stringify(restored)}`,
  );

  const screenshot = screenshotName === ""
    ? ""
    : await captureDeskScreenshot(session, screenshotName, 1440, 900);

  await dispatchKey(session, "Tab", "Tab", { shift: true });
  await waitTwoAnimationFrames(session);
  const reverse = await activeKeyboardFocus(session);
  trace.push({ operation: "Shift+Tab", label, ...reverse });
  assert(
    reverse.key !== trigger.key &&
      reverse.connected &&
      reverse.visible &&
      reverse.inViewport &&
      !reverse.disabled &&
      reverse.focusVisible &&
      reverse.focusIndicator,
    `${label} reverse traversal did not reach a usable visibly focused target: ` +
      `${JSON.stringify(reverse)}`,
  );

  await dispatchKey(session, "Tab", "Tab");
  await waitTwoAnimationFrames(session);
  const returned = await activeKeyboardFocus(session);
  trace.push({ operation: "Tab", label, ...returned });
  assert(
    returned.key === trigger.key &&
      !returned.detailsOpen &&
      returned.focusVisible &&
      returned.focusIndicator,
    `${label} forward traversal did not return to the exact trigger: ` +
      `${JSON.stringify(returned)}`,
  );

  return {
    caseId,
    surface,
    owningTestid,
    naturalFocus,
    trigger,
    opened,
    restored,
    reverse,
    returned,
    screenshot,
    trace,
  };
}

async function tabToTestId(
  session,
  testId,
  trace,
  label,
  { shift = false, maxSteps = 160 } = {},
) {
  const seen = new Set();
  for (let step = 1; step <= maxSteps; step += 1) {
    await dispatchKey(session, "Tab", "Tab", { shift });
    await session.evaluate(
      `new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))`,
    );
    const focus = await activeKeyboardFocus(session);
    trace.push({ operation: shift ? "Shift+Tab" : "Tab", label, step, ...focus });
    assert(
      focus.connected && focus.visible && focus.inViewport && !focus.disabled,
      `${label} reached an unusable focus target: ${JSON.stringify(focus)}`,
    );
    if (focus.testid === testId) {
      return focus;
    }
    assert(
      !seen.has(focus.key),
      `${label} cycled before reaching ${testId}: ${JSON.stringify(trace)}`,
    );
    seen.add(focus.key);
  }
  throw new Error(
    `${label} did not reach ${testId} within ${maxSteps} keyboard steps: ${JSON.stringify(trace)}`,
  );
}

async function insertTextAtKeyboardFocus(session, testId, value, trace, label) {
  const before = await activeKeyboardFocus(session);
  assert(
    before.testid === testId && before.visible && !before.disabled,
    `${label} requires keyboard focus on ${testId}: ${JSON.stringify(before)}`,
  );
  const existingValue = await session.evaluate(
    `document.querySelector('[data-testid=${JSON.stringify(testId)}]')?.value ?? ""`,
  );
  if (existingValue !== "") {
    await dispatchKey(session, "a", "KeyA", {
      meta: true,
      commands: ["SelectAll"],
    });
    const selectedRange = await session.evaluate(`(() => {
      const el = document.querySelector('[data-testid=${JSON.stringify(testId)}]');
      return el && el === document.activeElement
        ? { start: el.selectionStart, end: el.selectionEnd, length: el.value.length }
        : null;
    })()`);
    assert(
      selectedRange &&
        selectedRange.start === 0 &&
        selectedRange.end === selectedRange.length,
      `${label} keyboard select-all failed: ${JSON.stringify(selectedRange)}`,
    );
    await dispatchKey(session, "Backspace", "Backspace");
    await waitFor(
      session,
      `document.querySelector('[data-testid=${JSON.stringify(testId)}]')?.value === ""`,
      `${label} keyboard clear`,
    );
    trace.push({
      operation: "Meta+A Backspace",
      label,
      previousValueLength: existingValue.length,
      ...(await activeKeyboardFocus(session)),
    });
  }
  await session.send("Input.insertText", { text: value });
  await waitFor(
    session,
    `document.querySelector('[data-testid=${JSON.stringify(testId)}]')?.value === ${jsString(value)}`,
    `${label} input`,
  );
  const after = await activeKeyboardFocus(session);
  assert(
    after.testid === testId && after.visible && !after.disabled,
    `${label} lost keyboard focus after typing: ${JSON.stringify(after)}`,
  );
  trace.push({
    operation: "Input.insertText",
    label,
    valueLength: value.length,
    ...after,
  });
}

async function activateKeyboardFocus(session, testId, key, trace, label) {
  const before = await activeKeyboardFocus(session);
  assert(
    before.testid === testId && before.visible && !before.disabled,
    `${label} requires keyboard focus on ${testId}: ${JSON.stringify(before)}`,
  );
  assert(key === "Enter" || key === " ", `${label} uses an unsupported activation key`);
  trace.push({ operation: key === " " ? "Space" : "Enter", label, ...before });
  await dispatchKey(session, key, key === " " ? "Space" : "Enter");
}

const workspaceKeyboardViewports = [
  { width: 1440, height: 900, navigation: "desktop" },
  { width: 1024, height: 768, navigation: "desktop" },
  { width: 390, height: 844, navigation: "compact" },
  { width: 320, height: 700, navigation: "compact" },
];

async function waitTwoAnimationFrames(session) {
  await session.evaluate(
    `new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))`,
  );
}

async function tabToWorkspaceId(session, workspaceId, trace, label, maxSteps = 180) {
  const seen = new Set();
  for (let step = 1; step <= maxSteps; step += 1) {
    await dispatchKey(session, "Tab", "Tab");
    await waitTwoAnimationFrames(session);
    const focus = await activeKeyboardFocus(session);
    trace.push({ operation: "Tab", label, step, ...focus });
    assert(
      focus.connected && focus.visible && focus.inViewport && !focus.disabled,
      `${label} reached an unusable focus target: ${JSON.stringify(focus)}`,
    );
    if (focus.workspaceId === workspaceId) {
      return focus;
    }
    assert(
      !seen.has(focus.key),
      `${label} cycled before reaching workspace ${workspaceId}: ${JSON.stringify(trace)}`,
    );
    seen.add(focus.key);
  }
  throw new Error(
    `${label} did not reach workspace ${workspaceId} within ${maxSteps} keyboard steps`,
  );
}

async function workspaceKeyboardState(session) {
  return session.evaluate(`(() => {
    const visible = element => {
      if (!(element instanceof HTMLElement)) return false;
      const box = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return box.width > 0 &&
        box.height > 0 &&
        style.display !== 'none' &&
        style.visibility !== 'hidden';
    };
    const rect = element => {
      const box = element.getBoundingClientRect();
      return {
        left: box.left,
        top: box.top,
        right: box.right,
        bottom: box.bottom,
        width: box.width,
        height: box.height
      };
    };
    const rows = [...document.querySelectorAll('[data-testid="desk-workspace-row"]')]
      .filter(visible)
      .map((row, domIndex) => ({
        id: row.dataset.workspaceId || '',
        name: (row.querySelector('strong')?.textContent || '').trim(),
        status: row.dataset.status || '',
        pressed: row.getAttribute('aria-pressed') || '',
        active: row.classList.contains('active'),
        accessibleName: (
          row.getAttribute('aria-label') ||
          row.innerText ||
          row.textContent ||
          ''
        ).trim().replace(/\\s+/g, ' '),
        domIndex,
        rect: rect(row)
      }));
    const visualOrder = [...rows]
      .sort((left, right) =>
        left.rect.top - right.rect.top ||
        left.rect.left - right.rect.left ||
        left.domIndex - right.domIndex
      )
      .map(row => row.id);
    const panes = [
      document.querySelector('.desk-sidebar'),
      document.querySelector('.desk-browser'),
      document.querySelector('[data-testid="desk-details"]')
    ].filter(visible).map(element => ({
      selector: element.matches('.desk-sidebar')
        ? '.desk-sidebar'
        : element.matches('.desk-browser')
          ? '.desk-browser'
          : '[data-testid=desk-details]',
      rect: rect(element)
    }));
    const overlaps = [];
    for (let index = 0; index < panes.length; index += 1) {
      for (let other = index + 1; other < panes.length; other += 1) {
        const left = panes[index];
        const right = panes[other];
        const width = Math.max(
          0,
          Math.min(left.rect.right, right.rect.right) -
            Math.max(left.rect.left, right.rect.left)
        );
        const height = Math.max(
          0,
          Math.min(left.rect.bottom, right.rect.bottom) -
            Math.max(left.rect.top, right.rect.top)
        );
        if (width * height > 4) {
          overlaps.push([left.selector, right.selector, width, height]);
        }
      }
    }
    const desktopNavigation = document.querySelector('.primary-nav-desktop');
    const compactNavigation = document.querySelector('[data-testid="primary-nav-summary"]');
    return {
      viewport: {
        width: document.documentElement.clientWidth,
        height: document.documentElement.clientHeight
      },
      documentWidth: document.documentElement.scrollWidth,
      rows,
      domOrder: rows.map(row => row.id),
      visualOrder,
      selectedIds: rows.filter(row => row.pressed === 'true').map(row => row.id),
      activeIds: rows.filter(row => row.active).map(row => row.id),
      selectedName:
        (document.querySelector('[data-testid="desk-workspace-row"].active strong')
          ?.textContent || '').trim(),
      browserWorkspace:
        (document.querySelector('.desk-browser-workspace')?.textContent || '').trim(),
      directoryTitle:
        (document.querySelector('.desk-browser-head h2')?.textContent || '').trim(),
      locationValue:
        document.querySelector('[data-testid="desk-location-input"]')?.value || '',
      workspaceParam: new URLSearchParams(location.search).get('workspace') || '',
      homeReady:
        !!document.querySelector('[data-testid="desk-mode"]') &&
        !!document.querySelector('[data-testid="desk-file-list"]'),
      navigation: {
        desktop: visible(desktopNavigation),
        compact: visible(compactNavigation)
      },
      panes,
      overlaps
    };
  })()`);
}

async function navigateWorkspaceKeyboardCase(
  session,
  viewport,
  startWorkspaceId,
  expectedRowCount,
  expectedStartName,
  label,
) {
  await setViewport(session, viewport.width, viewport.height);
  const url =
    `${baseUrl}/?locale=en-US&workspace=${encodeURIComponent(startWorkspaceId)}`;
  await session.send("Page.navigate", { url });
  await waitFor(
    session,
    `document.readyState === 'complete' && ` +
      `!!document.querySelector('[data-testid="desk-mode"]') && ` +
      `document.querySelectorAll('[data-testid="desk-workspace-row"]').length === ${expectedRowCount}`,
    `${label} Home and row cardinality`,
  );
  await waitFor(
    session,
    `[...document.querySelectorAll('[data-testid="desk-workspace-row"]')]` +
      `.some(row => row.dataset.workspaceId === ${jsString(startWorkspaceId)} && ` +
      `row.classList.contains('active') && row.getAttribute('aria-pressed') === 'true')`,
    `${label} initial semantic selection`,
  );
  await waitFor(
    session,
    `document.querySelector('.desk-browser-workspace')?.textContent.includes(${jsString(expectedStartName)})`,
    `${label} initial Home content`,
  );
  await waitTwoAnimationFrames(session);
  const initialFocus = await activeKeyboardFocus(session);
  assert(
    initialFocus.tag === "body",
    `${label} must begin from natural document focus: ${JSON.stringify(initialFocus)}`,
  );
  return initialFocus;
}

async function verifyWorkspaceKeyboardMatrix(
  session,
  {
    cardinality,
    expectedRowCount,
    startWorkspaceId,
    startWorkspaceName,
    targetWorkspaceId,
    targetWorkspaceName,
  },
) {
  const cases = [];
  for (let index = 0; index < workspaceKeyboardViewports.length; index += 1) {
    const viewport = workspaceKeyboardViewports[index];
    const label =
      `${cardinality}-book keyboard ${viewport.width}x${viewport.height}`;
    const trace = [];
    const initialFocus = await navigateWorkspaceKeyboardCase(
      session,
      viewport,
      startWorkspaceId,
      expectedRowCount,
      startWorkspaceName,
      label,
    );
    trace.push({ operation: "initial", label, ...initialFocus });
    const before = await workspaceKeyboardState(session);
    assert(
      before.viewport.width === viewport.width &&
        before.viewport.height === viewport.height &&
        before.documentWidth <= before.viewport.width + 1,
      `${label} viewport or document width mismatch: ${JSON.stringify(before)}`,
    );
    assert(
      before.rows.length === expectedRowCount &&
        before.domOrder.join("|") === before.visualOrder.join("|"),
      `${label} row DOM/visual order mismatch: ${JSON.stringify(before)}`,
    );
    assert(
      before.selectedIds.length === 1 &&
        before.activeIds.length === 1 &&
        before.selectedIds[0] === startWorkspaceId &&
        before.activeIds[0] === startWorkspaceId,
      `${label} initial selected state mismatch: ${JSON.stringify(before)}`,
    );
    assert(
      viewport.navigation === "compact"
        ? before.navigation.compact && !before.navigation.desktop
        : before.navigation.desktop && !before.navigation.compact,
      `${label} primary navigation form mismatch: ${JSON.stringify(before.navigation)}`,
    );
    assert(
      before.overlaps.length === 0,
      `${label} panes overlap before keyboard selection: ${JSON.stringify(before.overlaps)}`,
    );
    const targetIndex = before.domOrder.indexOf(targetWorkspaceId);
    assert(targetIndex >= 0, `${label} target workspace is missing`);
    const focused = await tabToWorkspaceId(
      session,
      targetWorkspaceId,
      trace,
      `${label} forward traversal`,
    );
    const traversedRows = trace
      .filter(item => item.operation === "Tab" && item.workspaceId)
      .map(item => item.workspaceId);
    assert(
      traversedRows.join("|") === before.domOrder.slice(0, targetIndex + 1).join("|"),
      `${label} row focus order mismatch: ${JSON.stringify({
        traversedRows,
        expected: before.domOrder.slice(0, targetIndex + 1),
        trace,
      })}`,
    );
    assert(
      focused.focusVisible && focused.focusIndicator,
      `${label} workspace focus has no visible indicator: ${JSON.stringify(focused)}`,
    );
    const activationKey = index % 2 === 0 ? " " : "Enter";
    trace.push({
      operation: activationKey === " " ? "Space" : "Enter",
      label: `${label} activate`,
      ...focused,
    });
    await dispatchKey(
      session,
      activationKey,
      activationKey === " " ? "Space" : "Enter",
    );
    await waitFor(
      session,
      `(() => {
        const rows = [...document.querySelectorAll('[data-testid="desk-workspace-row"]')];
        const selected = rows.filter(row => row.getAttribute('aria-pressed') === 'true');
        const active = rows.filter(row => row.classList.contains('active'));
        return selected.length === 1 &&
          active.length === 1 &&
          selected[0].dataset.workspaceId === ${jsString(targetWorkspaceId)} &&
          active[0].dataset.workspaceId === ${jsString(targetWorkspaceId)} &&
          new URLSearchParams(location.search).get('workspace') === ${jsString(targetWorkspaceId)} &&
          document.querySelector('.desk-browser-workspace')?.textContent.includes(${jsString(targetWorkspaceName)});
      })()`,
      `${label} activated selection agreement`,
    );
    await waitTwoAnimationFrames(session);
    const retainedFocus = await activeKeyboardFocus(session);
    assert(
      retainedFocus.workspaceId === targetWorkspaceId &&
        retainedFocus.focusVisible &&
        retainedFocus.focusIndicator,
      `${label} did not retain focus on the activated workspace: ${JSON.stringify(retainedFocus)}`,
    );
    trace.push({ operation: "retained focus", label, ...retainedFocus });
    await dispatchKey(session, "Tab", "Tab", { shift: true });
    await waitTwoAnimationFrames(session);
    const reverseFocus = await activeKeyboardFocus(session);
    trace.push({ operation: "Shift+Tab", label: `${label} reverse`, ...reverseFocus });
    assert(
      reverseFocus.connected &&
        reverseFocus.visible &&
        reverseFocus.inViewport &&
        !reverseFocus.disabled &&
        (
          targetIndex === 0
            ? reverseFocus.workspaceId === ""
            : reverseFocus.workspaceId === before.domOrder[targetIndex - 1]
        ),
      `${label} reverse traversal mismatch: ${JSON.stringify(reverseFocus)}`,
    );
    await dispatchKey(session, "Tab", "Tab");
    await waitTwoAnimationFrames(session);
    const returnedFocus = await activeKeyboardFocus(session);
    trace.push({ operation: "Tab", label: `${label} return`, ...returnedFocus });
    assert(
      returnedFocus.workspaceId === targetWorkspaceId &&
        returnedFocus.focusVisible &&
        returnedFocus.focusIndicator,
      `${label} forward return did not restore target focus: ${JSON.stringify(returnedFocus)}`,
    );
    const after = await workspaceKeyboardState(session);
    assert(
      after.selectedIds.length === 1 &&
        after.activeIds.length === 1 &&
        after.selectedIds[0] === targetWorkspaceId &&
        after.activeIds[0] === targetWorkspaceId &&
        after.workspaceParam === targetWorkspaceId &&
        after.selectedName === targetWorkspaceName &&
        after.browserWorkspace.includes(targetWorkspaceName) &&
        after.homeReady &&
        after.documentWidth <= after.viewport.width + 1 &&
        after.overlaps.length === 0,
      `${label} final product state disagrees: ${JSON.stringify(after)}`,
    );
    const screenshot = await captureDeskScreenshot(
      session,
      `desk-keyboard-${cardinality}-${viewport.width}x${viewport.height}`,
      viewport.width,
      viewport.height,
    );
    cases.push({
      cardinality,
      viewport,
      activationKey: activationKey === " " ? "Space" : "Enter",
      startWorkspaceId,
      targetWorkspaceId,
      changedSelection: startWorkspaceId !== targetWorkspaceId,
      screenshot,
      before,
      after,
      trace,
    });
  }
  return cases;
}

function writeWorkspaceKeyboardPartialProof(cardinality, cases) {
  const proofPath = path.join(
    fixtureRoot,
    `desk-workspace-keyboard-${cardinality}-proof.json`,
  );
  fs.writeFileSync(
    proofPath,
    `${JSON.stringify({
      kind: "moondesk-workspace-keyboard-partial-proof.v1",
      cardinality,
      caseCount: cases.length,
      cases,
    }, null, 2)}\n`,
  );
  return proofPath;
}

async function verifyKeyboardAcceptance(session) {
  const prepared = await session.evaluate(`(() => {
    const details = document.querySelector('[data-testid="desk-library-storage-details"]');
    const trigger = details?.querySelector(':scope > summary');
    if (!trigger) return false;
    details.open = false;
    trigger.focus();
    return document.activeElement === trigger;
  })()`);
  assert(prepared, "Library storage disclosure summary is missing or cannot receive focus");

  await dispatchKey(session, " ", "Space");
  await waitFor(
    session,
    `document.querySelector('[data-testid="desk-library-storage-details"]')?.open === true`,
    "Space to open the library storage disclosure",
  );
  await dispatchKey(session, "Escape", "Escape");
  await waitFor(
    session,
    `(() => {
      const details = document.querySelector('[data-testid="desk-library-storage-details"]');
      return details?.open === false &&
        document.activeElement === details.querySelector(':scope > summary');
    })()`,
    "Escape to close the library storage disclosure and restore summary focus",
  );

  const navigationPrepared = await session.evaluate(`(() => {
    const control = document.querySelector('[data-testid="mode-wiki"]');
    if (!control) return false;
    control.focus();
    return document.activeElement === control;
  })()`);
  assert(navigationPrepared, "Pages primary navigation button is missing or cannot receive focus");
  await dispatchKey(session, " ", "Space");
  await waitFor(
    session,
    `document.querySelector('[data-testid="mode-wiki"]')?.getAttribute('aria-pressed') === 'true'`,
    "Space to activate Pages primary navigation",
  );
  await waitFor(
    session,
    `document.querySelector('[data-testid="activity-library"]') !== null`,
    "Pages surface after keyboard navigation",
  );
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

async function setInputByPlaceholder(session, placeholder, value) {
  const ok = await session.evaluate(`(async () => {
    const el = [...document.querySelectorAll('input, textarea')]
      .find(input => input.getAttribute('placeholder') === ${jsString(placeholder)});
    if (!el) return false;
    el.focus();
    el.value = ${jsString(value)};
    el.dispatchEvent(new InputEvent('input', {
      bubbles: true,
      inputType: 'insertText',
      data: ${jsString(value)}
    }));
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    const settled = [...document.querySelectorAll('input, textarea')]
      .find(input => input.getAttribute('placeholder') === ${jsString(placeholder)});
    return settled?.value === ${jsString(value)};
  })()`);
  assert(ok, `Input did not settle for placeholder ${placeholder}`);
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

function wikiRowExistsExpression(targetPath) {
  return `[...document.querySelectorAll('[data-testid="wiki-tree-row"]')]` +
    `.some(row => row.dataset.path === ${jsString(targetPath)})`;
}

async function clickWikiPath(session, targetPath) {
  const ok = await session.evaluate(`(() => {
    const row = [...document.querySelectorAll('[data-testid="wiki-tree-row"]')]
      .find(item => item.dataset.path === ${jsString(targetPath)});
    if (!row) return false;
    row.click();
    return true;
  })()`);
  assert(ok, `Missing Pages tree row ${targetPath}`);
}

function visibleRowsExpression() {
  return `[...document.querySelectorAll('[data-testid="desk-file-row"]')]` +
    `.map(row => row.dataset.path)`;
}

function mooncodeTranscriptItemsExpression() {
  return `(() => [...document.querySelectorAll('[data-testid="mooncode-message"], [data-testid="mooncode-activity"]')]
    .map((row, index) => {
      const kind = row.dataset.testid === "mooncode-message" ? "message" : "activity";
      const messageBody = kind === "message"
        ? row.querySelector(":scope > .mooncode-message-body")
        : null;
      return {
        index,
        kind,
        role: row.dataset.role || "",
        status: row.dataset.status || "",
        folded: row.dataset.folded || "",
        commandId: row.dataset.commandId || "",
        clientTurnId: row.dataset.clientTurnId || "",
        text: (messageBody?.textContent || row.textContent).trim()
      };
    }))()`;
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

function mooncodeCompletedTranscriptStateExpression(expectedPrompts) {
  return `(() => {
    const expectedPrompts = ${jsString(expectedPrompts)};
    const items = ${mooncodeTranscriptItemsExpression()};
    const userRows = items.filter(item =>
      item.kind === "message" && item.role === "user"
    );
    const assistantRows = items.filter(item =>
      item.kind === "message" && item.role === "assistant"
    );
    const state = {
      items,
      userTexts: userRows.map(item => item.text),
      assistantTexts: assistantRows.map(item => item.text),
    };
    state.pass =
      userRows.length === expectedPrompts.length &&
      expectedPrompts.every((prompt, index) => userRows[index]?.text === prompt) &&
      assistantRows.length === expectedPrompts.length &&
      assistantRows.every(row =>
        row.status === "done" &&
        row.text.trim() !== "" &&
        (row.commandId !== "" || row.clientTurnId !== "")
      );
    return state;
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

function mooncodeBackendTurnsStateExpression(
  expectedPrompts,
  expectedReplies = [],
  returnState = false,
  requireCompleted = false,
) {
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
        (
          expectedReplies.length === 0 &&
          (
            !${requireCompleted ? "true" : "false"} ||
            (
              summary.assistantTexts.length === expected.length &&
              summary.statuses.every(status => status === "done")
            )
          )
        ) ||
        (
          expectedReplies.length > 0 &&
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
    "Read wiki/index.md",
    "Read wiki/notes/alpha.md",
    "Read raw/evidence.txt",
  ];
  await setViewport(session, 1440, 900);
  await session.send("Page.navigate", {
    url: `${baseUrl}/?activity=code&workspace=book-research-alpha`,
  });
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
  const completedState = await waitForStatePass(
    session,
    mooncodeBackendTurnsStateExpression(prompts, [], true, true),
    "MoonCode backend completes three native turns",
    30000,
  );
  const completedSessions = completedState.summaries.filter(summary =>
    summary.userTexts.length === prompts.length &&
    prompts.every((prompt, index) => summary.userTexts[index] === prompt) &&
    summary.assistantTexts.length === prompts.length &&
    summary.statuses.every(status => status === "done")
  );
  assert(
    completedSessions.length === 1,
    `Expected one completed MoonCode session: ${JSON.stringify(completedState)}`,
  );
  const backendReplies = completedSessions[0].assistantTexts;
  assert(
    backendReplies.every(reply => reply.trim() !== ""),
    `MoonCode completed with an empty assistant reply: ${JSON.stringify(backendReplies)}`,
  );
  const completedTranscript = await waitForStatePass(
    session,
    mooncodeCompletedTranscriptStateExpression(prompts),
    "MoonCode UI renders three terminal native replies",
    16000,
  );
  const renderedReplies = completedTranscript.assistantTexts;
  await waitForStatePass(
    session,
    mooncodeTranscriptReplyStateExpression(prompts, renderedReplies),
    "MoonCode UI renders event-backed native replies",
    16000,
  );
  await sampleMoonCodeStableTranscript(
    session,
    prompts,
    "MoonCode stable native reply order",
    renderedReplies,
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
    mooncodeTranscriptReplyStateExpression(prompts, renderedReplies),
    "MoonCode hard refresh preserves native reply order",
    12000,
  );
  await waitForStatePass(
    session,
    mooncodeBackendTurnsStateExpression(prompts, backendReplies),
    "MoonCode hard refresh preserves backend native reply order",
    12000,
  );
  await sampleMoonCodeStableTranscript(
    session,
    prompts,
    "MoonCode stable hard-refresh reply order",
    renderedReplies,
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

function quickstartInboxPath() {
  const inboxRoot = path.join(fixtureRoot, "books/quickstart-book/inbox");
  if (!fs.existsSync(inboxRoot)) {
    return "";
  }
  const matches = fs.readdirSync(inboxRoot)
    .filter(name => name.startsWith("note-durable-quickstart-note-") && name.endsWith(".md"))
    .sort();
  assert(matches.length === 1, `Expected one durable quickstart note, found ${JSON.stringify(matches)}`);
  return `inbox/${matches[0]}`;
}

async function waitForQuickstartInboxPath(timeoutMs = 12000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const inboxRoot = path.join(fixtureRoot, "books/quickstart-book/inbox");
    if (fs.existsSync(inboxRoot)) {
      const matches = fs.readdirSync(inboxRoot)
        .filter(name => name.startsWith("note-durable-quickstart-note-") && name.endsWith(".md"));
      if (matches.length === 1) {
        return `inbox/${matches[0]}`;
      }
    }
    await sleep(100);
  }
  throw new Error("Timed out waiting for durable quickstart Inbox note");
}

async function runQuickstartMoonCode(session) {
  const inboxPath = quickstartInboxPath();
  const prompt = `Read ${inboxPath}`;
  await clickTestId(session, "mode-code");
  await waitFor(
    session,
    `!!document.querySelector('[data-testid="mooncode-center"]') && ` +
      `new URLSearchParams(location.search).get('workspace') === 'book-quickstart-book'`,
    "quickstart Code mode",
  );
  await waitFor(
    session,
    `!!document.querySelector('[data-testid="mooncode-input"]') && ` +
      `!!document.querySelector('[data-testid="mooncode-send"]')`,
    "quickstart Code composer",
  );
  await waitFor(
    session,
    `document.querySelector('[data-testid="mooncode-sessions-state-panel"]')?.dataset.state === 'legitimate-zero' && ` +
      `document.querySelector('[data-testid="mooncode-sessions-state-panel"]')?.textContent.includes('No chats yet')`,
    "quickstart honest empty Code session listing",
  );
  await setInputByTestId(session, "mooncode-input", prompt);
  await waitFor(
    session,
    `document.querySelector('[data-testid="mooncode-input"]')?.value === ${jsString(prompt)}`,
    "quickstart Code prompt typed",
  );
  await clickTestId(session, "mooncode-send");
  await waitForStatePass(
    session,
    mooncodeBackendTurnsStateExpression([prompt]),
    "quickstart backend canonical turn",
    12000,
  );
  await waitForStatePass(
    session,
    mooncodeUiSessionReadyStateExpression([prompt]),
    "quickstart UI session acknowledgement",
    12000,
  );
  await waitFor(
    session,
    `!document.querySelector('[data-testid="mooncode-sessions-state-panel"]') && ` +
      `document.querySelectorAll('[data-testid="mooncode-session"]').length === 1`,
    "quickstart ready Code session listing",
  );
  await waitForStatePass(
    session,
    mooncodeTranscriptStateExpression([prompt], false),
    "quickstart canonical conversation append",
    12000,
  );
  const completedState = await waitForStatePass(
    session,
    mooncodeBackendTurnsStateExpression([prompt], [], true, true),
    "quickstart backend terminal native reply",
    30000,
  );
  const completedSessions = completedState.summaries.filter(summary =>
    summary.userTexts.length === 1 &&
    summary.userTexts[0] === prompt &&
    summary.assistantTexts.length === 1 &&
    summary.statuses.every(status => status === "done")
  );
  assert(
    completedSessions.length === 1,
    `Expected one completed quickstart Code session: ${JSON.stringify(completedState)}`,
  );
  const backendReply = completedSessions[0].assistantTexts[0];
  assert(backendReply.trim() !== "", "Quickstart Code completed with an empty assistant reply");
  const completedTranscript = await waitForStatePass(
    session,
    mooncodeCompletedTranscriptStateExpression([prompt]),
    "quickstart UI terminal native reply",
    16000,
  );
  const renderedReply = completedTranscript.assistantTexts[0];
  await waitForStatePass(
    session,
    mooncodeTranscriptReplyStateExpression([prompt], [renderedReply]),
    "quickstart canonical evidence-backed reply",
    16000,
  );
  await sampleMoonCodeStableTranscript(
    session,
    [prompt],
    "quickstart stable canonical conversation",
    [renderedReply],
    800,
  );
  fs.writeFileSync(
    path.join(fixtureRoot, "quickstart-conversation-proof.json"),
    `${JSON.stringify({ prompt, backendReply, renderedReply }, null, 2)}\n`,
  );
}

async function runQuickstartBeforeRestart() {
  const session = await connect(cdpPort);
  const keyboardFocusTrace = [];
  try {
    await session.send("Page.enable");
    await setEnglishLocale(session);
    await enablePageProblemCapture(session);
    await setViewport(session, 1440, 900);
    await session.send("Page.navigate", { url: `${baseUrl}/?locale=en-US` });
    await waitFor(
      session,
      `document.readyState === 'complete' && !!document.querySelector('[data-testid="desk-mode"]')`,
      "quickstart empty Home",
    );
    await waitFor(
      session,
      `document.querySelectorAll('[data-testid="desk-workspace-row"]').length === 0`,
      "quickstart empty library",
    );

    const initialFocus = await activeKeyboardFocus(session);
    assert(
      initialFocus.tag === "body",
      `quickstart must begin from natural document focus: ${JSON.stringify(initialFocus)}`,
    );
    keyboardFocusTrace.push({
      operation: "initial",
      label: "empty-library document focus",
      ...initialFocus,
    });
    await tabToTestId(
      session,
      "desk-new-book-name",
      keyboardFocusTrace,
      "reach MoonBook name",
    );
    await insertTextAtKeyboardFocus(
      session,
      "desk-new-book-name",
      "Quickstart Book",
      keyboardFocusTrace,
      "type MoonBook name",
    );
    await tabToTestId(
      session,
      "desk-new-book-id",
      keyboardFocusTrace,
      "reach MoonBook folder name",
    );
    await insertTextAtKeyboardFocus(
      session,
      "desk-new-book-id",
      "quickstart-book",
      keyboardFocusTrace,
      "type MoonBook folder name",
    );
    await tabToTestId(
      session,
      "desk-create-book",
      keyboardFocusTrace,
      "reach Create MoonBook",
    );
    await activateKeyboardFocus(
      session,
      "desk-create-book",
      " ",
      keyboardFocusTrace,
      "create MoonBook",
    );
    await waitFor(
      session,
      `[...document.querySelectorAll('[data-testid="desk-workspace-row"]')]` +
        `.some(row => row.dataset.workspaceId === 'book-quickstart-book' && row.classList.contains('active'))`,
      "quickstart book created and selected",
    );
    await waitForFile(
      path.join(fixtureRoot, "books/quickstart-book/book.json"),
      "quickstart book manifest",
    );

    await tabToTestId(
      session,
      "mode-wiki",
      keyboardFocusTrace,
      "reach Pages",
    );
    await activateKeyboardFocus(
      session,
      "mode-wiki",
      " ",
      keyboardFocusTrace,
      "open Pages",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="mode-wiki"]')?.getAttribute('aria-pressed') === 'true'`,
      "quickstart Pages mode",
    );
    await tabToTestId(
      session,
      "wiki-new-note",
      keyboardFocusTrace,
      "reach New note",
    );
    await activateKeyboardFocus(
      session,
      "wiki-new-note",
      "Enter",
      keyboardFocusTrace,
      "open Inbox note composer",
    );
    await waitFor(
      session,
      `[...document.querySelectorAll('input, textarea')]` +
        `.some(input => input.getAttribute('placeholder') === 'Note title')`,
      "quickstart Inbox note composer",
    );
    await tabToTestId(
      session,
      "wiki-inbox-title",
      keyboardFocusTrace,
      "reach note title",
    );
    await insertTextAtKeyboardFocus(
      session,
      "wiki-inbox-title",
      "Durable quickstart note",
      keyboardFocusTrace,
      "type note title",
    );
    await tabToTestId(
      session,
      "wiki-inbox-body",
      keyboardFocusTrace,
      "reach note body",
    );
    await insertTextAtKeyboardFocus(
      session,
      "wiki-inbox-body",
      "Saved through the visible Pages UI.",
      keyboardFocusTrace,
      "type note body",
    );
    await waitForStatePass(
      session,
      `(() => {
        const fields = [...document.querySelectorAll('input, textarea')].map(input => ({
          placeholder: input.getAttribute('placeholder') || '',
          value: input.value || ''
        }));
        const state = {
          activity: new URLSearchParams(location.search).get('activity') || '',
          fields,
          buttons: [...document.querySelectorAll('button')].map(button => ({
            testid: button.dataset.testid || '',
            text: button.textContent.trim()
          })),
          hasSave: !!document.querySelector('[data-testid="wiki-save-note"]')
        };
        state.pass =
          fields.some(input => input.placeholder === 'Note title' && input.value === 'Durable quickstart note') &&
          fields.some(input => input.placeholder === 'Write down an idea, observation, or source note.' && input.value === 'Saved through the visible Pages UI.') &&
          state.hasSave;
        return state;
      })()`,
      "quickstart Inbox note draft settled",
    );
    await tabToTestId(
      session,
      "wiki-save-note",
      keyboardFocusTrace,
      "reach Save note",
    );
    await activateKeyboardFocus(
      session,
      "wiki-save-note",
      " ",
      keyboardFocusTrace,
      "save Inbox note",
    );
    const inboxPath = await waitForQuickstartInboxPath();
    fs.writeFileSync(
      path.join(fixtureRoot, "quickstart-keyboard-focus-proof.json"),
      `${JSON.stringify({
        kind: "moondesk-keyboard-first-use-proof.v1",
        viewport: { width: 1440, height: 900 },
        path: [
          "create MoonBook",
          "open Pages",
          "open Inbox note composer",
          "save durable Inbox note",
        ],
        inboxPath,
        trace: keyboardFocusTrace,
      }, null, 2)}\n`,
    );
    await waitFor(
      session,
      `location.search.includes('workspace=book-quickstart-book') && location.search.includes('activity=inbox')`,
      "quickstart selected book and Pages activity URL",
    );
    await waitFor(
      session,
      `document.querySelector('.preview-center')?.textContent.includes('Saved through the visible Pages UI.')`,
      "quickstart saved note preview",
    );
    const oneBookKeyboardCases = await verifyWorkspaceKeyboardMatrix(session, {
      cardinality: "one",
      expectedRowCount: 1,
      startWorkspaceId: "book-quickstart-book",
      startWorkspaceName: "Quickstart Book",
      targetWorkspaceId: "book-quickstart-book",
      targetWorkspaceName: "Quickstart Book",
    });
    const oneBookKeyboardProof = writeWorkspaceKeyboardPartialProof(
      "one",
      oneBookKeyboardCases,
    );
    console.log(`One-book keyboard proof: ${oneBookKeyboardProof}`);
    await setViewport(session, 1440, 900);
    await session.send("Page.navigate", {
      url: `${baseUrl}/?locale=en-US&workspace=book-quickstart-book`,
    });
    await waitFor(
      session,
      `document.readyState === 'complete' && ` +
        `!!document.querySelector('[data-testid="desk-mode"]') && ` +
        `document.querySelector('[data-testid="desk-workspace-row"].active')?.dataset.workspaceId === 'book-quickstart-book'`,
      "quickstart Home after one-book keyboard matrix",
    );

    await clickTestId(session, "mode-desk");
    await waitFor(session, `!!document.querySelector('[data-testid="desk-mode"]')`, "quickstart Home return");
    await clickTestId(session, "mode-wiki");
    await waitFor(
      session,
      `!!document.querySelector('[data-testid="activity-library"]')`,
      "quickstart Pages rail after Home",
    );
    await clickTestId(session, "activity-library");
    await waitFor(
      session,
      `!!document.querySelector('[data-testid="wiki-section-inbox"]')`,
      "quickstart Pages library controls",
    );
    await clickTestId(session, "wiki-section-inbox");
    await waitFor(session, wikiRowExistsExpression(inboxPath), "quickstart note after Pages return");
    await clickWikiPath(session, inboxPath);
    await waitFor(
      session,
      `document.querySelector('.preview-center')?.textContent.includes('Saved through the visible Pages UI.')`,
      "quickstart note preview after navigation",
    );
    await waitFor(
      session,
      `new URLSearchParams(location.search).get('path') === ${jsString(inboxPath)}`,
      "quickstart selected note URL",
    );
    await session.send("Page.reload", { ignoreCache: true });
    await waitFor(
      session,
      `document.readyState === 'complete' && ${wikiRowExistsExpression(inboxPath)}`,
      "quickstart note after hard reload",
    );
    await clickWikiPath(session, inboxPath);
    await waitFor(
      session,
      `document.querySelector('.preview-center')?.textContent.includes('Saved through the visible Pages UI.')`,
      "quickstart durable note preview after hard reload",
    );

    await runQuickstartMoonCode(session);
    await clickTestId(session, "mode-wiki");
    await waitFor(
      session,
      `!!document.querySelector('[data-testid="wiki-tab-review"]')`,
      "quickstart Wiki tabs after Code",
    );
    await clickTestId(session, "wiki-tab-review");
    await waitFor(
      session,
      `document.querySelector('[data-testid="wiki-tab-review"]')?.getAttribute('aria-pressed') === 'true' && ` +
        `location.search.includes('activity=review') && ` +
        `document.querySelector('[data-testid="review-state-panel"]')?.dataset.state === 'legitimate-zero' && ` +
        `document.querySelector('[data-testid="review-state-panel"]')?.textContent.includes('Nothing needs review')`,
      "quickstart honest Review result",
    );
    await clickTestId(session, "wiki-tab-publish");
    await waitFor(
      session,
      `location.search.includes('activity=publish') && ` +
        `!!document.querySelector('[data-testid="publish-workspace"]') && ` +
        `document.querySelector('[data-testid="publish-state-panel"]')?.dataset.state === 'legitimate-zero' && ` +
        `!!document.querySelector('[data-testid="publish-output-check"]') && ` +
        `!document.querySelector('[data-testid="publish-workspace"]')?.innerText.includes('output is ready')`,
      "quickstart honest Publish result",
    );

    await session.send("Page.navigate", {
      url: `${baseUrl}/?activity=code&workspace=book-quickstart-book`,
    });
    const { prompt, renderedReply } = JSON.parse(
      fs.readFileSync(
        path.join(fixtureRoot, "quickstart-conversation-proof.json"),
        "utf8",
      ),
    );
    await waitForStatePass(
      session,
      mooncodeTranscriptReplyStateExpression([prompt], [renderedReply]),
      "quickstart conversation before host restart",
      12000,
    );
    session.assertNoPageProblems("Quickstart before restart");
  } finally {
    session.close();
  }
}

async function runQuickstartAfterRestart() {
  const session = await connect(cdpPort);
  try {
    await session.send("Page.enable");
    await setEnglishLocale(session);
    await enablePageProblemCapture(session);
    await session.send("Page.reload", { ignoreCache: true });
    await waitFor(
      session,
      `document.readyState === 'complete' && location.search.includes('workspace=book-quickstart-book')`,
      "quickstart selected book after host restart",
    );
    const inboxPath = quickstartInboxPath();
    const { prompt, backendReply, renderedReply } = JSON.parse(
      fs.readFileSync(
        path.join(fixtureRoot, "quickstart-conversation-proof.json"),
        "utf8",
      ),
    );
    await waitForStatePass(
      session,
      mooncodeTranscriptReplyStateExpression([prompt], [renderedReply]),
      "quickstart durable conversation after host restart",
      16000,
    );
    await waitForStatePass(
      session,
      mooncodeBackendTurnsStateExpression([prompt], [backendReply]),
      "quickstart durable backend conversation after host restart",
      12000,
    );
    const restoredItems = await session.evaluate(mooncodeTranscriptItemsExpression());
    assert(
      restoredItems.filter(item => item.kind === "message" && item.role === "user").length === 1 &&
        restoredItems.filter(item => item.kind === "message" && item.role === "assistant").length === 1,
      `Quickstart restored duplicate or non-durable chat rows: ${JSON.stringify(restoredItems)}`,
    );

    await clickTestId(session, "mode-wiki");
    await waitFor(
      session,
      `!!document.querySelector('[data-testid="activity-library"]')`,
      "quickstart Pages rail after host restart",
    );
    await clickTestId(session, "activity-library");
    await waitFor(
      session,
      `!!document.querySelector('[data-testid="wiki-section-inbox"]')`,
      "quickstart Inbox control after host restart",
    );
    await clickTestId(session, "wiki-section-inbox");
    await waitFor(session, wikiRowExistsExpression(inboxPath), "quickstart saved note after host restart");
    await clickWikiPath(session, inboxPath);
    await waitFor(
      session,
      `document.querySelector('.preview-center')?.textContent.includes('Saved through the visible Pages UI.')`,
      "quickstart saved content after host restart",
    );
    const persisted = fs.readFileSync(
      path.join(fixtureRoot, "books/quickstart-book", inboxPath),
      "utf8",
    );
    assert(
      persisted.includes("# Durable quickstart note") &&
        persisted.includes("Saved through the visible Pages UI."),
      `Quickstart durable note bytes are incomplete: ${persisted}`,
    );
    session.assertNoPageProblems("Quickstart after restart");
    console.log("MoonDesk clean-workspace quickstart E2E passed");
  } finally {
    session.close();
  }
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
    const containment = [
      'html', 'body', '#app', '.desk-shell', '.file-desk-main',
      '.desk-detail-panel', '.desk-file-table', '.desk-file-rows',
      '.desk-browser-head .toolbar-actions'
    ].map(selector => {
      const el = document.querySelector(selector);
      if (!el) return null;
      const rect = el.getBoundingClientRect();
      const style = getComputedStyle(el);
      return {
        selector,
        left: rect.left,
        right: rect.right,
        width: rect.width,
        clientWidth: el.clientWidth,
        scrollWidth: el.scrollWidth,
        boxSizing: style.boxSizing,
        minWidth: style.minWidth,
        widthStyle: style.width,
        maxWidth: style.maxWidth,
        display: style.display,
        gridTemplateColumns: style.gridTemplateColumns
      };
    }).filter(Boolean);
    const horizontalOffenders = Array.from(document.querySelectorAll('body *'))
      .map(el => {
        const rect = el.getBoundingClientRect();
        const style = getComputedStyle(el);
        let depth = 0;
        for (let ancestor = el.parentElement; ancestor; ancestor = ancestor.parentElement) {
          depth += 1;
        }
        return {
          tag: el.tagName.toLowerCase(),
          id: el.id,
          className: typeof el.className === 'string' ? el.className : '',
          testid: el.dataset?.testid || '',
          text: (el.textContent || '').trim().replace(/\\s+/g, ' ').slice(0, 100),
          depth,
          left: rect.left,
          right: rect.right,
          width: rect.width,
          clientWidth: el.clientWidth,
          scrollWidth: el.scrollWidth,
          minWidth: style.minWidth,
          whiteSpace: style.whiteSpace,
          overflowX: style.overflowX,
          display: style.display,
          flexWrap: style.flexWrap,
          gridTemplateColumns: style.gridTemplateColumns
        };
      })
      .filter(item =>
        item.width > 0 &&
        (item.left < -1 || item.right > document.documentElement.clientWidth + 1)
      )
      .sort((a, b) => b.depth - a.depth || b.right - a.right)
      .slice(0, 40);
    const intrinsicOffenders = Array.from(document.querySelectorAll('body *'))
      .map(el => {
        const style = getComputedStyle(el);
        return {
          tag: el.tagName.toLowerCase(),
          className: typeof el.className === 'string' ? el.className : '',
          testid: el.dataset?.testid || '',
          text: (el.textContent || '').trim().replace(/\\s+/g, ' ').slice(0, 120),
          clientWidth: el.clientWidth,
          scrollWidth: el.scrollWidth,
          overflowDelta: el.scrollWidth - el.clientWidth,
          minWidth: style.minWidth,
          whiteSpace: style.whiteSpace,
          overflowWrap: style.overflowWrap,
          overflowX: style.overflowX
        };
      })
      .filter(item => item.clientWidth > 0 && item.overflowDelta > 1)
      .sort((a, b) => b.overflowDelta - a.overflowDelta)
      .slice(0, 30);
    let forcedViewportProbe = [];
    if (document.documentElement.scrollWidth > document.documentElement.clientWidth + 1) {
      const probe = document.createElement('style');
      probe.textContent = [
        'html', 'body', '#app', '.desk-shell', '.title-bar', '.desk-main',
        '.desk-sidebar', '.desk-browser', '.desk-details'
      ].map(selector =>
        selector + '{width:' + document.documentElement.clientWidth +
          'px!important;max-width:' + document.documentElement.clientWidth +
          'px!important;min-width:0!important}'
      ).join('');
      document.head.append(probe);
      forcedViewportProbe = Array.from(document.querySelectorAll('body *'))
        .map(el => {
          const rect = el.getBoundingClientRect();
          const style = getComputedStyle(el);
          return {
            tag: el.tagName.toLowerCase(),
            className: typeof el.className === 'string' ? el.className : '',
            testid: el.dataset?.testid || '',
            text: (el.textContent || '').trim().replace(/\\s+/g, ' ').slice(0, 120),
            left: rect.left,
            right: rect.right,
            width: rect.width,
            clientWidth: el.clientWidth,
            scrollWidth: el.scrollWidth,
            minWidth: style.minWidth,
            whiteSpace: style.whiteSpace,
            overflowWrap: style.overflowWrap,
            display: style.display,
            flexWrap: style.flexWrap,
            gridTemplateColumns: style.gridTemplateColumns
          };
        })
        .filter(item =>
          item.width > 0 &&
          (item.left < -1 || item.right > document.documentElement.clientWidth + 1)
        )
        .sort((a, b) => b.right - a.right)
        .slice(0, 40);
      probe.remove();
    }
    const libraryRoot = document.querySelector('[data-testid="desk-library-root"]');
    const libraryOverflow = [];
    if (libraryRoot) {
      const rootRect = libraryRoot.getBoundingClientRect();
      for (const el of libraryRoot.querySelectorAll('strong, code')) {
        const rect = el.getBoundingClientRect();
        const style = getComputedStyle(el);
        if (
          rect.width <= 0 ||
          rect.height <= 0 ||
          style.display === 'none' ||
          style.visibility === 'hidden'
        ) {
          continue;
        }
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
            rootRight: rootRect.right,
            ancestors: (() => {
              const items = [];
              for (
                let current = el.parentElement;
                current && items.length < 6;
                current = current.parentElement
              ) {
                const currentRect = current.getBoundingClientRect();
                const currentStyle = getComputedStyle(current);
                items.push({
                  tag: current.tagName.toLowerCase(),
                  className: current.className,
                  clientWidth: current.clientWidth,
                  left: currentRect.left,
                  right: currentRect.right,
                  width: currentStyle.width,
                  minWidth: currentStyle.minWidth,
                  maxWidth: currentStyle.maxWidth,
                  gridTemplateColumns: currentStyle.gridTemplateColumns
                });
                if (current === libraryRoot) break;
              }
              return items;
            })()
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
      containment,
      horizontalOffenders,
      intrinsicOffenders,
      forcedViewportProbe,
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

const sharedShellAccessibilityViewports = [
  { width: 1440, height: 900, navigation: "desktop" },
  { width: 1024, height: 768, navigation: "desktop" },
  { width: 390, height: 844, navigation: "compact" },
  { width: 320, height: 700, navigation: "compact" },
];

const sharedShellDestinations = [
  { label: "Desk", testid: "mode-desk", compactTestid: "compact-mode-desk", activity: "home" },
  { label: "Wiki", testid: "mode-wiki", compactTestid: "compact-mode-wiki", activity: "pages" },
  { label: "Code", testid: "mode-code", compactTestid: "compact-mode-code", activity: "code" },
  {
    label: "Flow",
    testid: "mode-flow",
    compactTestid: "compact-mode-flow",
    activity: "flow",
  },
  {
    label: "Packs",
    testid: "mode-packs",
    compactTestid: "compact-mode-packs",
    activity: "packs",
  },
];

async function navigateToAccessibilityHome(session, viewport) {
  await setViewport(session, viewport.width, viewport.height);
  await session.send("Page.navigate", {
    url:
      `${baseUrl}/?locale=en-US&activity=home&` +
      `workspace=book-research-alpha`,
  });
  await waitFor(
    session,
    `document.readyState === 'complete' && ` +
      `document.querySelector('[data-testid="mode-desk"]')?.getAttribute('aria-current') === 'page' && ` +
      `document.querySelector('#moondesk-main-content')?.getAttribute('aria-label') === 'Desk workspace' && ` +
      `document.querySelectorAll('[data-testid="desk-workspace-row"]').length === 4 && ` +
      `document.activeElement === document.body`,
    `fresh accessibility Home at ${viewport.width}x${viewport.height}`,
  );
  await waitTwoAnimationFrames(session);
}

async function sharedShellDomState(session) {
  return session.evaluate(`(() => {
    const visible = element => {
      if (!(element instanceof HTMLElement)) return false;
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return rect.width > 0 && rect.height > 0 &&
        style.display !== 'none' && style.visibility !== 'hidden' &&
        element.getAttribute('aria-hidden') !== 'true';
    };
    const rect = element => {
      const box = element.getBoundingClientRect();
      return {
        left: box.left, top: box.top, right: box.right, bottom: box.bottom,
        width: box.width, height: box.height
      };
    };
    const overlaps = [];
    const panes = [...document.querySelectorAll(
      '.desk-sidebar,.desk-browser,.desk-details,.activity-pane,.mooncode-pane,.mooncode-center'
    )].filter(visible);
    for (let first = 0; first < panes.length; first += 1) {
      for (let second = first + 1; second < panes.length; second += 1) {
        const a = panes[first].getBoundingClientRect();
        const b = panes[second].getBoundingClientRect();
        const width = Math.min(a.right, b.right) - Math.max(a.left, b.left);
        const height = Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top);
        if (width > 1 && height > 1) {
          overlaps.push({
            first: panes[first].className,
            second: panes[second].className,
            width,
            height
          });
        }
      }
    }
    const routeButtons = [...document.querySelectorAll(
      '[data-testid^="mode-"],[data-testid^="compact-mode-"]'
    )];
    const current = routeButtons.filter(
      button => button.getAttribute('aria-current') === 'page'
    );
    const pressed = routeButtons.filter(
      button => button.getAttribute('aria-pressed') === 'true'
    );
    const active = routeButtons.filter(button => button.classList.contains('active'));
    const visibleNavigation = [...document.querySelectorAll('[role="navigation"]')]
      .filter(visible);
    const main = document.querySelector('#moondesk-main-content');
    const announcement = document.querySelector(
      '[data-testid="destination-announcement"]'
    );
    return {
      viewport: {
        width: document.documentElement.clientWidth,
        height: document.documentElement.clientHeight
      },
      documentWidth: document.documentElement.scrollWidth,
      horizontalOverflow:
        document.documentElement.scrollWidth > document.documentElement.clientWidth + 1,
      mainCount: document.querySelectorAll('main').length,
      mainIdCount: document.querySelectorAll('#moondesk-main-content').length,
      main: main ? {
        name: main.getAttribute('aria-label') || '',
        focused: document.activeElement === main,
        tabindex: main.getAttribute('tabindex') || '',
        rect: rect(main)
      } : null,
      visibleNavigationCount: visibleNavigation.length,
      visibleNavigationClass: visibleNavigation[0]?.className || '',
      current: current.map(button => button.dataset.testid),
      pressed: pressed.map(button => button.dataset.testid),
      active: active.map(button => button.dataset.testid),
      announcement: announcement ? {
        text: announcement.textContent.trim(),
        role: announcement.getAttribute('role') || '',
        live: announcement.getAttribute('aria-live') || '',
        atomic: announcement.getAttribute('aria-atomic') || ''
      } : null,
      overlaps
    };
  })()`);
}

function assertAxPoliteAtomicStatus(node, label) {
  assert(node.role === "status", `${label} AX role mismatch: ${JSON.stringify(node)}`);
  assert(
    node.properties.live === "polite",
    `${label} AX live mode mismatch: ${JSON.stringify(node)}`,
  );
  assert(
    node.properties.atomic === true,
    `${label} AX atomic mode mismatch: ${JSON.stringify(node)}`,
  );
}

async function runSkipLandmarkAccessibilityCase(session, viewport) {
  const label = `shared shell skip ${viewport.width}x${viewport.height}`;
  const trace = [];
  await navigateToAccessibilityHome(session, viewport);
  const focusedSkip = await tabToTestId(session, "skip-to-main", trace, label, {
    maxSteps: 1,
  });
  assert(
    focusedSkip.focusVisible && focusedSkip.focusIndicator && focusedSkip.inViewport,
    `${label} skip link has no visible focus treatment: ${JSON.stringify(focusedSkip)}`,
  );
  const screenshot = await captureDeskScreenshot(
    session,
    `desk-accessibility-skip-${viewport.width}x${viewport.height}`,
    viewport.width,
    viewport.height,
  );
  const skipAx = await accessibilityNodeForSelector(
    session,
    '[data-testid="skip-to-main"]',
  );
  const navigationSelector = viewport.navigation === "desktop"
    ? ".primary-nav-desktop"
    : ".primary-nav-compact";
  const navigationAx = await accessibilityNodeForSelector(
    session,
    navigationSelector,
  );
  assert(
    skipAx.role === "link" && skipAx.name === "Skip to main content",
    `${label} skip AX contract mismatch: ${JSON.stringify(skipAx)}`,
  );
  assert(
    navigationAx.role === "navigation" &&
      navigationAx.name === "Primary destinations",
    `${label} navigation AX contract mismatch: ${JSON.stringify(navigationAx)}`,
  );
  await activateKeyboardFocus(session, "skip-to-main", "Enter", trace, label);
  await waitFor(
    session,
    `document.activeElement?.id === 'moondesk-main-content'`,
    `${label} main focus transfer`,
  );
  const mainAx = await accessibilityNodeForSelector(
    session,
    "#moondesk-main-content",
  );
  const destinationAx = await accessibilityNodeForSelector(
    session,
    '[data-testid="destination-announcement"]',
  );
  assert(
    mainAx.role === "main" && mainAx.name === "Desk workspace",
    `${label} main AX contract mismatch: ${JSON.stringify(mainAx)}`,
  );
  assertAxPoliteAtomicStatus(destinationAx, `${label} destination`);
  const afterActivation = await sharedShellDomState(session);
  assert(
    afterActivation.mainCount === 1 &&
      afterActivation.mainIdCount === 1 &&
      afterActivation.main?.focused &&
      afterActivation.main?.tabindex === "-1",
    `${label} main contract mismatch: ${JSON.stringify(afterActivation)}`,
  );
  assert(
    afterActivation.visibleNavigationCount === 1 &&
      !afterActivation.horizontalOverflow &&
      afterActivation.overlaps.length === 0,
    `${label} geometry/navigation mismatch: ${JSON.stringify(afterActivation)}`,
  );
  assert(
    viewport.navigation === "desktop"
      ? afterActivation.visibleNavigationClass.includes("primary-nav-desktop")
      : afterActivation.visibleNavigationClass.includes("primary-nav-compact"),
    `${label} rendered the wrong navigation: ${JSON.stringify(afterActivation)}`,
  );
  await dispatchKey(session, "Tab", "Tab", { shift: true });
  await waitTwoAnimationFrames(session);
  const reverse = await activeKeyboardFocus(session);
  trace.push({ operation: "Shift+Tab from main", label, ...reverse });
  assert(
    reverse.connected && reverse.visible && reverse.inViewport && !reverse.disabled,
    `${label} reverse traversal is unusable: ${JSON.stringify(reverse)}`,
  );
  await dispatchKey(session, "Tab", "Tab");
  await waitTwoAnimationFrames(session);
  const forward = await activeKeyboardFocus(session);
  trace.push({ operation: "Tab after reverse", label, ...forward });
  assert(
    forward.connected &&
      forward.visible &&
      forward.inViewport &&
      !forward.disabled &&
      forward.key !== reverse.key,
    `${label} forward traversal is trapped: ${JSON.stringify({ reverse, forward })}`,
  );
  return {
    kind: "skip-landmark",
    viewport,
    screenshot,
    focusedSkip,
    afterActivation,
    accessibility: {
      skip: skipAx,
      navigation: navigationAx,
      main: mainAx,
      destination: destinationAx,
    },
    reverse,
    forward,
    trace,
  };
}

async function activateDestinationByKeyboard(
  session,
  viewport,
  destination,
  trace,
  index,
) {
  await navigateToAccessibilityHome(session, viewport);
  await tabToTestId(session, "skip-to-main", trace, `${destination.label} skip`, {
    maxSteps: 1,
  });
  const testid = viewport.navigation === "desktop"
    ? destination.testid
    : destination.compactTestid;
  if (viewport.navigation === "compact") {
    await tabToTestId(
      session,
      "primary-nav-summary",
      trace,
      `${destination.label} compact summary`,
      { maxSteps: 1 },
    );
    await activateKeyboardFocus(
      session,
      "primary-nav-summary",
      " ",
      trace,
      `${destination.label} compact summary`,
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="primary-nav-summary"]')?.parentElement?.open === true`,
      `${destination.label} compact navigation open`,
    );
  }
  await tabToTestId(
    session,
    testid,
    trace,
    `${destination.label} destination`,
    { maxSteps: 12 },
  );
  await activateKeyboardFocus(
    session,
    testid,
    index % 2 === 0 ? "Enter" : " ",
    trace,
    `${destination.label} destination`,
  );
  await waitFor(
    session,
    `location.search.includes('activity=${destination.activity}') && ` +
      `document.querySelector('#moondesk-main-content')?.getAttribute('aria-label') === ` +
        `${JSON.stringify(`${destination.label} workspace`)} && ` +
      `document.querySelector('[data-testid="destination-announcement"]')?.textContent.includes(` +
        `${JSON.stringify(`${destination.label} destination.`)})`,
    `${destination.label} route and announcement`,
  );
  await waitTwoAnimationFrames(session);
}

async function assertDestinationAccessibility(
  session,
  viewport,
  destination,
) {
  const state = await sharedShellDomState(session);
  const selectedIds = viewport.navigation === "desktop"
    ? [destination.testid, destination.compactTestid]
    : [destination.testid, destination.compactTestid];
  assert(
    state.mainCount === 1 &&
      state.mainIdCount === 1 &&
      state.main?.name === `${destination.label} workspace`,
    `${destination.label} main mismatch: ${JSON.stringify(state)}`,
  );
  assert(
    state.current.length === 2 &&
      state.pressed.length === 2 &&
      state.active.length === 2 &&
      selectedIds.every(id =>
        state.current.includes(id) &&
        state.pressed.includes(id) &&
        state.active.includes(id)
      ),
    `${destination.label} selection mismatch: ${JSON.stringify(state)}`,
  );
  assert(
    state.announcement?.text.includes(`${destination.label} destination.`) &&
      state.announcement?.text.includes("Selected book: Research Alpha.") &&
      state.announcement?.role === "status" &&
      state.announcement?.live === "polite" &&
      state.announcement?.atomic === "true",
    `${destination.label} announcement mismatch: ${JSON.stringify(state)}`,
  );
  const expectedVisibleNavigationCount =
    destination.label === "Wiki" ? 2 : 1;
  assert(
    state.visibleNavigationCount === expectedVisibleNavigationCount &&
      !state.horizontalOverflow &&
      state.overlaps.length === 0,
    `${destination.label} shell geometry mismatch: ${JSON.stringify(state)}`,
  );
  const navigationAx = await accessibilityNodeForSelector(
    session,
    viewport.navigation === "desktop"
      ? ".primary-nav-desktop"
      : ".primary-nav-compact",
  );
  const mainAx = await accessibilityNodeForSelector(
    session,
    "#moondesk-main-content",
  );
  const destinationAx = await accessibilityNodeForSelector(
    session,
    '[data-testid="destination-announcement"]',
  );
  assert(
    navigationAx.role === "navigation" &&
      navigationAx.name === "Primary destinations",
    `${destination.label} navigation AX mismatch: ${JSON.stringify(navigationAx)}`,
  );
  assert(
    mainAx.role === "main" &&
      mainAx.name === `${destination.label} workspace`,
    `${destination.label} main AX mismatch: ${JSON.stringify(mainAx)}`,
  );
  assertAxPoliteAtomicStatus(destinationAx, `${destination.label} destination`);
  let selectedAx = null;
  if (viewport.navigation === "desktop") {
    selectedAx = await accessibilityNodeForSelector(
      session,
      `[data-testid="${destination.testid}"]`,
    );
    assert(
      selectedAx.role === "button" &&
        (selectedAx.properties.pressed === true ||
          selectedAx.properties.pressed === "true"),
      `${destination.label} selected button AX mismatch: ${JSON.stringify(selectedAx)}`,
    );
  }
  return {
    destination,
    state,
    accessibility: {
      navigation: navigationAx,
      main: mainAx,
      destination: destinationAx,
      selected: selectedAx,
    },
  };
}

async function proveSearchStateAnnouncements(session) {
  const controller = await pauseNextRequest(session, "/api/search");
  const searchPaneReady = await session.evaluate(
    `!!document.querySelector('.activity-pane input.line-input')`,
  );
  if (!searchPaneReady) {
    const opened = await session.evaluate(`(() => {
      const toggle = document.querySelector('[data-testid="command-palette-toggle"]');
      toggle?.click();
      return !!toggle;
    })()`);
    assert(opened, "Pages command palette toggle is missing");
    await waitFor(
      session,
      `!!document.querySelector('.command-palette')`,
      "Pages command palette",
    );
    const selectedSearch = await session.evaluate(`(() => {
      const command = Array.from(document.querySelectorAll('.palette-command'))
        .find(button => button.querySelector('h3')?.textContent.trim() === 'Search Books');
      command?.click();
      return !!command;
    })()`);
    assert(selectedSearch, "Pages Search Books command is missing");
    await waitFor(
      session,
      `!!document.querySelector('.activity-pane input.line-input')`,
      "Pages search pane",
    );
  }
  const focused = await session.evaluate(`(() => {
    const input = document.querySelector('.activity-pane input.line-input');
    if (!(input instanceof HTMLInputElement)) return false;
    input.focus();
    return true;
  })()`);
  assert(focused, "Pages search input is missing");
  await session.send("Input.insertText", { text: "command-040-no-results" });
  await waitFor(
    session,
    `document.querySelector('.activity-pane input.line-input')?.value === 'command-040-no-results'`,
    "Pages search keyboard input",
  );
  await session.evaluate(
    `new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))`,
  );
  const submitted = await session.evaluate(`(() => {
    const button = document.querySelector('[data-testid="pages-search-state-action"]');
    button?.click();
    return !!button;
  })()`);
  assert(submitted, "Pages search action is missing");
  const paused = await controller.wait();
  assert(
    paused.request?.url?.includes("/api/search"),
    `Pages search interception used the wrong request: ${JSON.stringify(paused)}`,
  );
  await waitFor(
    session,
    `document.querySelector('[data-testid="pages-search-state"]')?.dataset.state === 'loading'`,
    "Pages Loading accessibility state",
  );
  const loading = await accessibilityNodeForSelector(
    session,
    '[data-testid="pages-search-state-announcement"]',
  );
  assertAxPoliteAtomicStatus(loading, "Pages Loading");
  await controller.fail();
  await waitFor(
    session,
    `document.querySelector('[data-testid="pages-search-state"]')?.dataset.state === 'recoverable-error'`,
    "Pages recoverable accessibility state",
  );
  const recoverable = await accessibilityNodeForSelector(
    session,
    '[data-testid="pages-search-state-announcement"]',
  );
  assertAxPoliteAtomicStatus(recoverable, "Pages recoverable failure");
  const recoverableDom = await session.evaluate(`(() => {
    const announcement = document.querySelector(
      '[data-testid="pages-search-state-announcement"]'
    );
    const panel = document.querySelector('[data-testid="pages-search-state"]');
    return {
      announcementText: announcement?.textContent.trim() || '',
      panelText: panel?.textContent.trim() || '',
      technicalOpen:
        panel?.querySelector('details.technical-details')?.open === true
    };
  })()`);
  assert(
    recoverableDom.announcementText.includes("Something went wrong") &&
      !recoverableDom.announcementText.includes("Technical details") &&
      recoverableDom.panelText.includes("Technical details") &&
      !recoverableDom.technicalOpen,
    `Pages recoverable announcement leaked technical disclosure: ${JSON.stringify(recoverableDom)}`,
  );
  const retried = await session.evaluate(`(() => {
    const button = document.querySelector('[data-testid="pages-search-state-action"]');
    button?.click();
    return !!button;
  })()`);
  assert(retried, "Pages retry control is missing");
  await waitFor(
    session,
    `document.querySelector('[data-testid="pages-search-state"]')?.dataset.state === 'legitimate-zero'`,
    "Pages legitimate-zero accessibility state",
  );
  const legitimateZero = await accessibilityNodeForSelector(
    session,
    '[data-testid="pages-search-state-announcement"]',
  );
  assertAxPoliteAtomicStatus(legitimateZero, "Pages legitimate zero");
  const expectedFailedRequestProblems = session.pageProblems.filter(
    problem =>
      problem.kind === "log.error" &&
      problem.text.includes("net::ERR_FAILED") &&
      problem.url === paused.request.url,
  );
  assert(
    expectedFailedRequestProblems.length === 1,
    `Pages failed-request proof produced unexpected browser diagnostics: ${JSON.stringify(session.pageProblems)}`,
  );
  session.pageProblems = session.pageProblems.filter(
    problem => !expectedFailedRequestProblems.includes(problem),
  );
  return {
    requestUrl: paused.request.url,
    expectedBrowserDiagnostic: expectedFailedRequestProblems[0],
    states: [
      { state: "loading", accessibility: loading },
      {
        state: "recoverable-error",
        accessibility: recoverable,
        dom: recoverableDom,
      },
      { state: "legitimate-zero", accessibility: legitimateZero },
    ],
  };
}

async function runDestinationAccessibilityCase(session, viewport) {
  const trace = [];
  const routes = [];
  for (let index = 0; index < sharedShellDestinations.length; index += 1) {
    const destination = sharedShellDestinations[index];
    const flowComposition = destination.label === "Flow"
      ? await installScreenReaderFlowComposition(session)
      : null;
    await activateDestinationByKeyboard(
      session,
      viewport,
      destination,
      trace,
      index,
    );
    const route = await assertDestinationAccessibility(
      session,
      viewport,
      destination,
    );
    if (
      viewport.width === 1440 &&
      destination.label === "Wiki"
    ) {
      route.stateTransitions = await proveSearchStateAnnouncements(session);
    }
    routes.push(route);
    await flowComposition?.close();
  }
  const screenshot = await captureDeskScreenshot(
    session,
    `desk-accessibility-destinations-${viewport.width}x${viewport.height}`,
    viewport.width,
    viewport.height,
  );
  session.assertNoPageProblems(
    `shared shell destination accessibility ${viewport.width}x${viewport.height}`,
  );
  return {
    kind: "destination-announcements",
    viewport,
    routeCount: routes.length,
    screenshot,
    routes,
    trace,
  };
}

const capabilityRenderedCases = [
  {
    id: "detected-running",
    running: true,
    installed: true,
    configured: true,
    supported: true,
    codeTitle: "Code assistance is ready",
    codeDetail: "You can start or continue Code conversations.",
    codeAction: "",
    requestsTitle: "Request automation is ready",
    requestsDetail:
      "Requests can be saved now and automation can process scheduled work.",
    requestsAction: "",
    flowAvailable: true,
    flowState: "legitimate-zero",
  },
  {
    id: "installed-stopped",
    running: false,
    installed: true,
    configured: true,
    supported: true,
    codeTitle: "Code assistance is stopped",
    codeDetail: "Start Code assistance before beginning a conversation.",
    codeAction: "Start Code assistance",
    requestsTitle: "Request automation is stopped",
    requestsDetail:
      "Requests can still be saved. Start automation for scheduled work.",
    requestsAction: "Start automation",
    flowAvailable: false,
    flowState: "capability-limited",
  },
  {
    id: "not-installed",
    running: false,
    installed: false,
    configured: false,
    supported: true,
    codeTitle: "Code assistance is not installed",
    codeDetail: "Install Code assistance to use Code conversations.",
    codeAction: "Install Code assistance",
    requestsTitle: "Request automation needs setup",
    requestsDetail:
      "Requests can still be saved. Review setup before using scheduled work.",
    requestsAction: "Review setup",
    flowAvailable: false,
    flowState: "capability-limited",
  },
  {
    id: "misconfigured",
    running: false,
    installed: true,
    configured: false,
    supported: true,
    codeTitle: "Code assistance needs configuration",
    codeDetail: "Review the configuration before using Code assistance.",
    codeAction: "Review configuration",
    requestsTitle: "Request automation needs setup",
    requestsDetail:
      "Requests can still be saved. Review setup before using scheduled work.",
    requestsAction: "Review setup",
    flowAvailable: false,
    flowState: "capability-limited",
  },
  {
    id: "unsupported-platform",
    running: false,
    installed: true,
    configured: true,
    supported: false,
    codeTitle: "Code assistance is not supported here",
    codeDetail:
      "You can continue with Pages and files without local Code assistance.",
    codeAction: "",
    requestsTitle: "Request automation is not supported here",
    requestsDetail:
      "Requests can still be saved without local scheduled automation.",
    requestsAction: "",
    flowAvailable: false,
    flowState: "capability-limited",
  },
  {
    id: "temporarily-unavailable",
    unavailable: true,
    running: false,
    installed: false,
    configured: false,
    supported: true,
    codeTitle: "Code assistance status is unavailable",
    codeDetail:
      "Check again when status information is available. Pages and files remain available.",
    codeAction: "Check again",
    requestsTitle: "Request automation status is unavailable",
    requestsDetail:
      "Requests can still be saved. Check automation status again when available.",
    requestsAction: "Check again",
    flowAvailable: false,
    flowState: "capability-limited",
  },
];

function capabilityCodeResponse(item) {
  return {
    running: item.running,
    port: item.running ? 4188 : 0,
    message: `command057-code-${item.id}-private`,
    service_configured: item.configured,
    managed_install: item.installed,
    managed_running: item.running,
    platform_evidence: {
      supported: item.supported,
      platform: `command057-platform-${item.id}-private`,
      architecture: "command057-architecture-private",
    },
    installation_evidence: {
      installed: item.installed,
      source: `command057-installation-${item.id}-private`,
      reason: item.installed ? "runtime-present" : "runtime-absent",
    },
    configuration_evidence: {
      configured: item.configured,
      valid: item.configured,
      reason: item.configured ? "configuration-valid" : "configuration-invalid",
    },
  };
}

function capabilityRequestsResponse(item) {
  return {
    ok: true,
    action: "status",
    status: item.running ? "running" : "stopped",
    running: item.running,
    pid: item.running ? 57057 : 0,
    command: "command057-requests-command-private",
    cwd: "command057-requests-cwd-private",
    started_at: "",
    stopped_at: "",
    pid_file: "command057-requests-pid-private",
    stdout_path: "command057-requests-stdout-private",
    stderr_path: "command057-requests-stderr-private",
    message: `command057-requests-${item.id}-private`,
    supervision_enabled: false,
    desired_state: "stopped",
    restart_count: 0,
    last_health_check: "",
    policy_file: "command057-requests-policy-private",
    service_configured: item.configured,
    service_config_path: "command057-requests-config-private",
    service_cwd: "command057-requests-service-cwd-private",
    platform_evidence: {
      supported: item.supported,
      platform: `command057-platform-${item.id}-private`,
      architecture: "command057-architecture-private",
    },
    installation_evidence: {
      installed: item.installed,
      source: `command057-installation-${item.id}-private`,
    },
    configuration_evidence: {
      configured: item.configured,
      valid: item.configured,
      reason: item.configured ? "configuration-valid" : "configuration-invalid",
    },
  };
}

function capabilityFlowResponse(item) {
  return {
    ok: true,
    status: item.flowAvailable ? "ready" : "unavailable",
    message: item.flowAvailable
      ? "Flow preparation is available"
      : "Flow preparation is not available in the current setup",
    next_action: item.flowAvailable ? "prepare_flow" : "review_flow_setup",
    available: item.flowAvailable,
    reason: item.flowAvailable ? "capability-ready" : "runtime-root-unavailable",
    root: `command057-flow-${item.id}-private`,
    platform_evidence: {
      supported: true,
      platform: "command057-flow-platform-private",
      architecture: "command057-flow-architecture-private",
    },
    installation_evidence: {
      installed: true,
      source: "command057-flow-installation-private",
      reason: "runtime-command-available",
    },
    configuration_evidence: {
      configured: true,
      valid: item.flowAvailable,
      reason: item.flowAvailable ? "configuration-valid" : "runtime-root-unavailable",
    },
  };
}

async function installCapabilityResponseSubstitution(session, item) {
  const routeForPath = pathname => {
    if (pathname === "/api/moonclaw/daemon") return "code";
    if (pathname === "/api/town/daemon/status") return "requests";
    if (pathname === "/api/moonflow/capability") return "flow";
    return "";
  };
  const records = [];
  const seen = new Set();
  let failure = null;
  let firstSettleResolve;
  let firstSettleReject;
  const firstSettle = new Promise((resolve, reject) => {
    firstSettleResolve = resolve;
    firstSettleReject = reject;
  });
  const listener = params => {
    const pathname = new URL(params.request.url).pathname;
    const route = routeForPath(pathname);
    if (!route) {
      return;
    }
    void (async () => {
      const unavailable = item.unavailable && (route === "code" || route === "requests");
      const response = route === "code"
        ? capabilityCodeResponse(item)
        : route === "requests"
          ? capabilityRequestsResponse(item)
          : capabilityFlowResponse(item);
      const responseCode = unavailable ? 503 : 200;
      const body = unavailable
        ? {
            error: {
              code: "capability-unavailable",
              message: `command057-${route}-${item.id}-private`,
            },
          }
        : response;
      await session.send("Fetch.fulfillRequest", {
        requestId: params.requestId,
        responseCode,
        responseHeaders: [
          { name: "Content-Type", value: "application/json; charset=utf-8" },
          { name: "Cache-Control", value: "no-store" },
        ],
        body: Buffer.from(JSON.stringify(body)).toString("base64"),
      });
      records.push({
        caseId: item.id,
        route,
        pathname,
        responseCode,
        evidence: unavailable ? "http-unavailable" : "structured-json",
      });
      seen.add(route);
      if (seen.size === 3) {
        firstSettleResolve();
      }
    })().catch(error => {
      failure = error;
      firstSettleReject(error);
    });
  };
  session.on("Fetch.requestPaused", listener);
  await session.send("Fetch.enable", {
    patterns: [
      { urlPattern: "*/api/moonclaw/daemon*", requestStage: "Request" },
      { urlPattern: "*/api/town/daemon/status*", requestStage: "Request" },
      { urlPattern: "*/api/moonflow/capability*", requestStage: "Request" },
    ],
  });
  return {
    records,
    async waitForFirstSettle(timeoutMs = 15_000) {
      let timer;
      await Promise.race([
        firstSettle,
        new Promise((_, reject) => {
          timer = setTimeout(
            () => reject(
              new Error(
                `Capability substitution did not receive every route for ${item.id}: ` +
                  `${JSON.stringify([...seen])}`,
              ),
            ),
            timeoutMs,
          );
        }),
      ]).finally(() => clearTimeout(timer));
      if (failure) throw failure;
    },
    async close() {
      session.off("Fetch.requestPaused", listener);
      await session.send("Fetch.disable");
      if (failure) throw failure;
    },
  };
}

async function capabilityPanelEvidence(
  session,
  panelSelector,
  publicSelector,
) {
  return session.evaluate(`(() => {
    const panel = document.querySelector(${JSON.stringify(panelSelector)});
    const publicRoot = panel?.querySelector(${JSON.stringify(publicSelector)}) || panel;
    if (!(panel instanceof HTMLElement) || !(publicRoot instanceof HTMLElement)) {
      return null;
    }
    const details = panel.querySelector('details.technical-details');
    const visible = element => {
      if (!(element instanceof HTMLElement)) return false;
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return rect.width > 0 && rect.height > 0 &&
        style.display !== 'none' && style.visibility !== 'hidden';
    };
    const visibleOrdinary = selector =>
      [...publicRoot.querySelectorAll(selector)].find(element =>
        !element.closest('.visually-hidden') &&
        !element.closest('details.technical-details') &&
        visible(element)
      );
    const title = visibleOrdinary('strong');
    const detail = visibleOrdinary('p');
    const action = visibleOrdinary('button');
    const ordinary = publicRoot.cloneNode(true);
    ordinary.querySelectorAll('details.technical-details').forEach(node => node.remove());
    ordinary.querySelectorAll('.visually-hidden').forEach(node => node.remove());
    return {
      state: panel.dataset.state || '',
      title: title?.textContent.trim() || '',
      detail: detail?.textContent.trim() || '',
      action: action?.textContent.trim() || '',
      titleVisible: visible(title),
      detailVisible: visible(detail),
      actionVisible: visible(action),
      ordinaryText: ordinary.textContent.trim().replace(/\\s+/g, ' '),
      detailsPresent: details instanceof HTMLDetailsElement,
      detailsOpen: details instanceof HTMLDetailsElement && details.open,
      technicalText: details?.textContent.trim().replace(/\\s+/g, ' ') || ''
    };
  })()`);
}

async function runCapabilityRenderedCase(session, item) {
  const substitution = await installCapabilityResponseSubstitution(session, item);
  const screenshots = [];
  try {
    await session.send("Page.navigate", {
      url:
        `${baseUrl}/?locale=en-US&activity=home&workspace=book-research-alpha&` +
        `capability_case=${encodeURIComponent(item.id)}`,
    });
    await substitution.waitForFirstSettle();
    await waitFor(
      session,
      `document.querySelector('[data-testid="moongate-summary"]')?.dataset.state === ` +
        `${jsString(item.id)}`,
      `${item.id} Code capability`,
    );
    const code = await capabilityPanelEvidence(
      session,
      '[data-testid="moongate-summary"]',
      '[data-testid="code-assistance-public-summary"]',
    );
    assert(
      code &&
        code.state === item.id &&
        code.title === item.codeTitle &&
        code.detail === item.codeDetail &&
        code.action === item.codeAction &&
        code.titleVisible &&
        code.detailVisible &&
        (item.codeAction === "" || code.actionVisible) &&
        code.detailsPresent &&
        !code.detailsOpen &&
        !code.ordinaryText.includes("command057-"),
      `${item.id} Code presentation is not honest: ${JSON.stringify(code)}`,
    );
    screenshots.push(
      await captureDeskScreenshot(
        session,
        `desk-capability-code-${item.id}`,
        1440,
        900,
      ),
    );
    const codeKeyboard = await proveOwnedDisclosureKeyboardRestoration(
      session,
      {
        caseId: item.id,
        surface: "code",
        owningTestid: "code-assistance-technical-details",
        screenshotName: item.id === "not-installed"
          ? "desk-capability-keyboard-code-not-installed"
          : "",
      },
    );

    await session.send("Page.navigate", {
      url:
        `${baseUrl}/?locale=en-US&activity=requests&workspace=book-research-alpha&` +
        `capability_case=${encodeURIComponent(item.id)}`,
    });
    await waitFor(
      session,
      `document.querySelector('[data-testid="requests-capability"]')?.dataset.state === ` +
        `${jsString(item.id)}`,
      `${item.id} Requests capability`,
    );
    const requests = await capabilityPanelEvidence(
      session,
      '[data-testid="requests-capability"]',
      ':scope',
    );
    assert(
      requests &&
        requests.state === item.id &&
        requests.title === item.requestsTitle &&
        requests.detail === item.requestsDetail &&
        requests.action === item.requestsAction &&
        requests.titleVisible &&
        requests.detailVisible &&
        (item.requestsAction === "" || requests.actionVisible) &&
        !requests.detailsOpen &&
        !requests.ordinaryText.includes("command057-"),
      `${item.id} Requests presentation is not honest: ${JSON.stringify(requests)}`,
    );
    screenshots.push(
      await captureDeskScreenshot(
        session,
        `desk-capability-requests-${item.id}`,
        1440,
        900,
      ),
    );
    const requestsKeyboard = item.unavailable
      ? null
      : await proveOwnedDisclosureKeyboardRestoration(
          session,
          {
            caseId: item.id,
            surface: "requests",
            owningTestid: "requests-capability",
            screenshotName: item.id === "misconfigured"
              ? "desk-capability-keyboard-requests-misconfigured"
              : "",
          },
        );

    await session.send("Page.navigate", {
      url:
        `${baseUrl}/?locale=en-US&activity=flow&workspace=book-research-alpha&` +
        `capability_case=${encodeURIComponent(item.id)}`,
    });
    await waitFor(
      session,
      `document.querySelector('[data-testid="moonflow-runs-state-panel"]')?.dataset.state === ` +
        `${jsString(item.flowState)}`,
      `${item.id} Flow capability`,
    );
    const flow = await capabilityPanelEvidence(
      session,
      '[data-testid="moonflow-runs-state-panel"]',
      ':scope',
    );
    assert(
      flow &&
        flow.state === item.flowState &&
        flow.titleVisible &&
        flow.detailVisible &&
        !flow.detailsOpen &&
        !flow.ordinaryText.includes("command057-") &&
        (
          item.flowAvailable
            ? flow.action === "Start governed run" &&
              flow.actionVisible &&
              !flow.detailsPresent
            : flow.title === "Executable work isn’t available" &&
              flow.action === "" &&
              flow.detailsPresent &&
              flow.technicalText.includes(`command057-flow-${item.id}-private`)
        ),
      `${item.id} Flow presentation is not honest: ${JSON.stringify(flow)}`,
    );
    if (item.flowAvailable || item.id === "installed-stopped") {
      screenshots.push(
        await captureDeskScreenshot(
          session,
          `desk-capability-flow-${item.id}`,
          1440,
          900,
        ),
      );
    }
    const flowKeyboard = item.flowAvailable
      ? null
      : await proveOwnedDisclosureKeyboardRestoration(
          session,
          {
            caseId: item.id,
            surface: "flow",
            owningTestid: "moonflow-runs-state-panel",
            screenshotName: item.id === "installed-stopped"
              ? "desk-capability-keyboard-flow-installed-stopped"
              : "",
          },
        );
    const transportProblems = session.pageProblems.map(problem => ({ ...problem }));
    if (item.unavailable) {
      assert(
        transportProblems.length >= 2 &&
          transportProblems.every(problem =>
            problem.kind === "log.error" &&
            problem.text.includes("503") &&
            (
              problem.url.endsWith("/api/moonclaw/daemon") ||
              problem.url.endsWith("/api/town/daemon/status")
            )
          ),
        `Unavailable capability emitted unexpected browser errors: ` +
          `${JSON.stringify(transportProblems)}`,
      );
      session.clearPageProblems();
    } else {
      session.assertNoPageProblems(`rendered capability ${item.id}`);
    }
    return {
      id: item.id,
      structuredFacts: {
        supported: item.supported,
        installed: item.installed,
        configured: item.configured,
        running: item.running,
        unavailable: item.unavailable === true,
        flowAvailable: item.flowAvailable,
      },
      code,
      requests,
      flow,
      keyboardFocus: {
        code: codeKeyboard,
        requests: requestsKeyboard,
        flow: flowKeyboard,
      },
      screenshots,
      substitutions: substitution.records,
      transportProblems,
    };
  } finally {
    await substitution.close();
  }
}

async function capabilityResponsiveGeometry(session, item, surface, viewport, allowVerticalOverflow = false) {
  const codeUsesRuntimeSetup =
    surface === "code" && item.id !== "detected-running";
  const panelSelector = surface === "code"
    ? codeUsesRuntimeSetup
      ? '[data-testid="mooncode-runtime-setup"]'
      : '[data-testid="moongate-summary"]'
    : surface === "requests"
      ? '[data-testid="requests-capability"]'
      : '[data-testid="moonflow-runs-state-panel"]';
  const publicSelector = surface === "code"
    ? codeUsesRuntimeSetup
      ? ""
      : '[data-testid="code-assistance-public-summary"]'
    : "";
  const expectedState = surface === "flow" ? item.flowState : item.id;
  const expectedTitle = surface === "code"
    ? item.codeTitle
    : surface === "requests"
      ? item.requestsTitle
      : item.flowAvailable
        ? "No executable work yet"
        : "Executable work isn’t available";
  const expectedDetail = surface === "code"
    ? item.codeDetail
    : surface === "requests"
      ? item.requestsDetail
      : item.flowAvailable
        ? "Start with the selected MoonBook's executable document. " +
          "MoonFlow creates the run, then publishes authority-bound handoffs " +
          "for every governed decision."
        : "This setup cannot provide governed runs for the selected book.";
  const expectedAction = surface === "code"
    ? item.codeAction
    : surface === "requests"
      ? item.requestsAction
      : item.flowAvailable ? "Start governed run" : "";
  const expectedDisclosure = surface === "code" ||
    (surface === "requests" && !item.unavailable) ||
    (surface === "flow" && !item.flowAvailable);
  return session.evaluate(`(() => {
    const panel = document.querySelector(${JSON.stringify(panelSelector)});
    if (!panel) throw new Error("missing responsive capability panel");
    const publicRoot = ${JSON.stringify(publicSelector)}
      ? panel.querySelector(${JSON.stringify(publicSelector)})
      : panel;
    if (!(publicRoot instanceof HTMLElement)) {
      throw new Error("missing responsive capability public root");
    }
    const visible = element => {
      if (!(element instanceof HTMLElement)) return false;
      const closedDetails = element.closest("details:not([open])");
      if (
        closedDetails &&
        closedDetails !== element &&
        !element.closest("summary")
      ) {
        return false;
      }
      const box = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return box.width > 0 && box.height > 0 && style.display !== "none" &&
        style.visibility !== "hidden";
    };
    const ordinary = Array.from(
      publicRoot.querySelectorAll("strong,p,button,a")
    ).filter(element =>
      visible(element) &&
      !element.closest(".visually-hidden") &&
      !element.closest("details.technical-details")
    );
    const findText = text => ordinary.find(element =>
      element.textContent.trim() === text);
    const expectedTitle = ${JSON.stringify(expectedTitle)};
    const expectedDetail = ${JSON.stringify(expectedDetail)};
    const title = findText(expectedTitle);
    const detail = findText(expectedDetail);
    const expectedAction = ${JSON.stringify(expectedAction)};
    const action = expectedAction ? findText(expectedAction) : null;
    const expectedDisclosure = ${JSON.stringify(expectedDisclosure)};
    const disclosure = panel.querySelector("details.technical-details");
    const rect = element => {
      const box = element.getBoundingClientRect();
      return { left: box.left, top: box.top, right: box.right,
        bottom: box.bottom, width: box.width, height: box.height };
    };
    const allowVerticalOverflow = ${JSON.stringify(allowVerticalOverflow)};
    const allowDocumentFlow = allowVerticalOverflow ||
      ${JSON.stringify(surface === "code" && !codeUsesRuntimeSetup)};
    const inside = element => {
      const box = element.getBoundingClientRect();
      return box.left >= 0 && box.top >= 0 && box.right <= innerWidth + 0.5 &&
        box.bottom <= innerHeight + 0.5;
    };
    const horizontallyInside = element => {
      const box = element.getBoundingClientRect();
      return box.left >= -0.5 && box.right <= innerWidth + 0.5;
    };
    const verticallyReachable = element => {
      const box = element.getBoundingClientRect();
      const top = box.top + scrollY;
      const bottom = box.bottom + scrollY;
      if (top >= -0.5 &&
          bottom <= document.documentElement.scrollHeight + 0.5) {
        return true;
      }
      for (let ancestor = element.parentElement;
           ancestor && ancestor !== document.body;
           ancestor = ancestor.parentElement) {
        const style = getComputedStyle(ancestor);
        const scrollable = style.overflowY === "auto" ||
          style.overflowY === "scroll";
        if (!scrollable || ancestor.scrollHeight <= ancestor.clientHeight + 1) {
          continue;
        }
        const ancestorBox = ancestor.getBoundingClientRect();
        const contentTop =
          box.top - ancestorBox.top + ancestor.scrollTop;
        const contentBottom =
          box.bottom - ancestorBox.top + ancestor.scrollTop;
        if (contentTop >= -0.5 &&
            contentBottom <= ancestor.scrollHeight + 0.5) {
          return true;
        }
      }
      return false;
    };
    const clippedByAncestor = element => {
      const box = element.getBoundingClientRect();
      let horizontalBox = { left: box.left, right: box.right };
      let verticalBox = { top: box.top, bottom: box.bottom };
      for (let ancestor = element.parentElement;
           ancestor && ancestor !== document.body;
           ancestor = ancestor.parentElement) {
        const style = getComputedStyle(ancestor);
        const ancestorBox = ancestor.getBoundingClientRect();
        const scrollsX =
          (style.overflowX === "auto" || style.overflowX === "scroll") &&
          ancestor.scrollWidth > ancestor.clientWidth + 1;
        const scrollsY =
          (style.overflowY === "auto" || style.overflowY === "scroll") &&
          ancestor.scrollHeight > ancestor.clientHeight + 1;
        if (scrollsX) {
          horizontalBox = {
            left: ancestorBox.left,
            right: ancestorBox.right
          };
        }
        if (scrollsY) {
          verticalBox = {
            top: ancestorBox.top,
            bottom: ancestorBox.bottom
          };
        }
        const clipsX = style.overflowX === "hidden" ||
          style.overflowX === "clip";
        const clipsY = style.overflowY === "hidden" ||
          style.overflowY === "clip";
        if (clipsX &&
            (horizontalBox.left < ancestorBox.left - 0.5 ||
             horizontalBox.right > ancestorBox.right + 0.5)) return true;
        if (clipsY &&
            (verticalBox.top < ancestorBox.top - 0.5 ||
             verticalBox.bottom > ancestorBox.bottom + 0.5)) return true;
      }
      return false;
    };
    const layoutInside = element => allowDocumentFlow
      ? horizontallyInside(element) &&
        verticallyReachable(element) &&
        !clippedByAncestor(element)
      : inside(element) && !clippedByAncestor(element);
    const roots = Array.from(
      document.querySelectorAll(".desk-sidebar,.desk-browser,.desk-details")
    ).filter(visible);
    const overlap = (a, b) => {
      const x = Math.min(a.right, b.right) - Math.max(a.left, b.left);
      const y = Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top);
      return x > 1 && y > 1;
    };
    const rootRects = roots.map(rect);
    const compact = innerWidth <= 760;
    const compactNav = document.querySelector("[data-testid=primary-nav-summary]");
    const desktopNav = document.querySelector(".primary-nav-desktop");
    const flowChrome = ${JSON.stringify(surface === "flow")}
      ? document.querySelector(".flow-canvas-chrome")
      : null;
    const flowTitle = flowChrome?.querySelector(".flow-canvas-title") || null;
    const flowTools = flowChrome?.querySelector(".flow-canvas-tools") || null;
    const flowControls = flowTools
      ? Array.from(flowTools.querySelectorAll("button")).filter(visible)
      : [];
    const flowTitleRect = flowTitle ? rect(flowTitle) : null;
    const flowToolsRect = flowTools ? rect(flowTools) : null;
    const flowTitleToolsOverlap = flowTitleRect && flowToolsRect
      ? overlap(flowTitleRect, flowToolsRect)
      : false;
    const surfaceChromeElements = ${JSON.stringify(surface === "code")}
      ? ${JSON.stringify(codeUsesRuntimeSetup)}
        ? [
            document.querySelector('[data-testid="mooncode-rail"] .pane-heading'),
            document.querySelector('[data-testid="mooncode-new-session"]'),
            document.querySelector('[data-testid="mooncode-session-search"]')
          ]
        : [
            document.querySelector(
              '[data-testid="desk-mode"] .desk-sidebar .pane-heading h2'
            ),
            document.querySelector('[data-testid="desk-refresh-workspaces"]')
          ]
      : ${JSON.stringify(surface === "requests")}
        ? [
            document.querySelector(".user-pane .pane-heading h2"),
            document.querySelector(".user-pane .pane-heading button")
          ]
        : [
            document.querySelector(".flow-hero-compact h1"),
            document.querySelector(".flow-hero-compact button")
          ];
    const surfaceChromeRects = surfaceChromeElements
      .filter(element => element instanceof HTMLElement)
      .map(rect);
    const surfaceChromeOverlaps = [];
    for (let index = 0; index < surfaceChromeRects.length; index += 1) {
      for (let other = index + 1;
           other < surfaceChromeRects.length;
           other += 1) {
        if (overlap(surfaceChromeRects[index], surfaceChromeRects[other])) {
          surfaceChromeOverlaps.push({
            first: surfaceChromeElements[index].textContent.trim().slice(0, 80),
            second:
              surfaceChromeElements[other].textContent.trim().slice(0, 80)
          });
        }
      }
    }
    const surfaceChromeUsable =
      surfaceChromeElements.length ===
        ${JSON.stringify(surface === "code" && codeUsesRuntimeSetup ? 3 : 2)} &&
      surfaceChromeElements.every(element =>
        element instanceof HTMLElement &&
        visible(element) &&
        horizontallyInside(element) &&
        verticallyReachable(element) &&
        !clippedByAncestor(element) &&
        element.scrollWidth <= element.clientWidth + 1
      ) &&
      surfaceChromeOverlaps.length === 0;
    const flowPrimaryWorkUsable = ${JSON.stringify(surface === "flow")}
      ? Boolean(
          flowChrome &&
          flowTitle &&
          flowTools &&
          visible(flowChrome) &&
          layoutInside(flowChrome) &&
          visible(flowTitle) &&
          visible(flowTools) &&
          !flowTitleToolsOverlap &&
          flowControls.length >= 3 &&
          flowControls.every(control => layoutInside(control))
        )
      : true;
    const contentElements = [title, detail, action, disclosure]
      .filter(element => element instanceof HTMLElement && visible(element));
    const contentRects = contentElements.map(rect);
    const contentOverlaps = [];
    for (let index = 0; index < contentRects.length; index += 1) {
      for (let other = index + 1; other < contentRects.length; other += 1) {
        if (overlap(contentRects[index], contentRects[other])) {
          contentOverlaps.push({
            first: contentElements[index].textContent.trim().slice(0, 80),
            second: contentElements[other].textContent.trim().slice(0, 80)
          });
        }
      }
    }
    const panelBox = panel.getBoundingClientRect();
    const overflowDescendants = Array.from(panel.querySelectorAll("*"))
      .filter(element =>
        element instanceof HTMLElement &&
        visible(element) &&
        !element.closest(".visually-hidden")
      )
      .map(element => {
        const box = element.getBoundingClientRect();
        return {
          tag: element.tagName.toLowerCase(),
          className: element.className,
          text: element.textContent.trim().slice(0, 80),
          rect: rect(element),
          clientWidth: element.clientWidth,
          scrollWidth: element.scrollWidth,
          outsidePanel:
            box.left < panelBox.left - 0.5 ||
            box.right > panelBox.right + 0.5,
          internallyOverflowing:
            element.scrollWidth > element.clientWidth + 1
        };
      })
      .filter(entry => entry.outsidePanel || entry.internallyOverflowing);
    return {
      viewport: { width: innerWidth, height: innerHeight },
      expectedViewport: ${JSON.stringify(viewport)},
      caseId: ${JSON.stringify(item.id)},
      surface: ${JSON.stringify(surface)}, state: panel.dataset.state,
      expectedState: ${JSON.stringify(expectedState)},
      scrollY,
      atDocumentStart: Math.abs(scrollY) <= 0.5,
      documentWidth: document.documentElement.scrollWidth,
      noHorizontalOverflow: document.documentElement.scrollWidth <= innerWidth,
      panel: {
        ...rect(panel),
        clientWidth: panel.clientWidth,
        clientHeight: panel.clientHeight,
        scrollWidth: panel.scrollWidth,
        scrollHeight: panel.scrollHeight
      },
      panelVisible: visible(panel), panelInside: inside(panel),
      panelInsideContract: layoutInside(panel),
      panelNotClipped: panel.scrollWidth <= panel.clientWidth + 1 &&
        panel.scrollHeight <= panel.clientHeight + 1 &&
        !clippedByAncestor(panel),
      overflowDescendants,
      expectedTitle, expectedDetail,
      title: title ? {
        text: title.textContent.trim(), rect: rect(title),
        inside: layoutInside(title),
        horizontallyInside: horizontallyInside(title),
        visible: visible(title),
        clippedByAncestor: clippedByAncestor(title)
      } : null,
      detail: detail ? {
        text: detail.textContent.trim(), rect: rect(detail),
        inside: layoutInside(detail),
        horizontallyInside: horizontallyInside(detail),
        visible: visible(detail),
        clippedByAncestor: clippedByAncestor(detail)
      } : null,
      expectedDisclosure,
      disclosure: disclosure ? {
        present: true,
        open: disclosure.open,
        visible: visible(disclosure),
        rect: rect(disclosure),
        inside: layoutInside(disclosure),
        horizontallyInside: horizontallyInside(disclosure),
        clippedByAncestor: clippedByAncestor(disclosure)
      } : { present: false, open: false, visible: false, inside: false },
      disclosureContract: expectedDisclosure
        ? Boolean(disclosure && !disclosure.open && visible(disclosure) &&
            layoutInside(disclosure))
        : !disclosure,
      expectedAction, action: action ? {
        rect: rect(action),
        inside: layoutInside(action),
        horizontallyInside: horizontallyInside(action),
        visible: visible(action),
        clippedByAncestor: clippedByAncestor(action),
        contentFits: action.scrollWidth <= action.clientWidth + 1
      } : null,
      actionVisibleWhenApplicable: !expectedAction ||
        Boolean(
          action &&
          visible(action) &&
          layoutInside(action) &&
          action.scrollWidth <= action.clientWidth + 1
        ),
      correctNavigation: compact
        ? visible(compactNav) && !visible(desktopNav)
        : visible(desktopNav) && !visible(compactNav),
      compactNavigation: compact,
      noRootOverlap: rootRects.every((a, i) => rootRects.every((b, j) =>
        i >= j || !overlap(a, b))),
      contentOverlaps,
      noContentOverlap: contentOverlaps.length === 0,
      surfaceChrome: {
        expectedCount:
          ${JSON.stringify(surface === "code" && codeUsesRuntimeSetup ? 3 : 2)},
        elements: surfaceChromeElements.map(element =>
          element instanceof HTMLElement
            ? {
                text: element.textContent.trim().slice(0, 80),
                rect: rect(element),
                visible: visible(element),
                horizontallyInside: horizontallyInside(element),
                verticallyReachable: verticallyReachable(element),
                clippedByAncestor: clippedByAncestor(element),
                contentFits: element.scrollWidth <= element.clientWidth + 1
              }
            : null
        ),
        overlaps: surfaceChromeOverlaps,
        usable: surfaceChromeUsable
      },
      flowPrimaryWork: ${JSON.stringify(surface === "flow")} ? {
        chrome: flowChrome ? rect(flowChrome) : null,
        title: flowTitleRect,
        tools: flowToolsRect,
        controlCount: flowControls.length,
        controls: flowControls.map(control => ({
          text: control.textContent.trim(),
          rect: rect(control),
          inside: layoutInside(control),
          horizontallyInside: horizontallyInside(control),
          clippedByAncestor: clippedByAncestor(control)
        })),
        titleToolsOverlap: flowTitleToolsOverlap
      } : null,
      primaryWorkUsable: visible(document.querySelector("main")) &&
        (expectedAction
          ? Boolean(
              action &&
              layoutInside(action) &&
              action.scrollWidth <= action.clientWidth + 1
            )
          : true) &&
        surfaceChromeUsable &&
        flowPrimaryWorkUsable &&
        contentOverlaps.length === 0
    };
  })()`);
}

async function runCapabilityScaleEvidence() {
  const session = await connect(cdpPort);
  const modes = [
    { id: "browser-zoom-200", width: 720, height: 450, textFactor: null },
    { id: "text-only-200-desktop", width: 1440, height: 900, textFactor: 2 },
    { id: "text-only-200-narrow", width: 320, height: 700, textFactor: 2 },
  ];
  const cases = [];
  const screenshots = [];
  try {
    await session.send("Page.enable");
    await enablePageProblemCapture(session);
    await setEnglishLocale(session);
    for (const item of capabilityRenderedCases) {
      const substitution = await installCapabilityResponseSubstitution(session, item);
      let firstNavigation = true;
      try {
        for (const mode of modes) {
          await setViewport(session, mode.width, mode.height);
          for (const surface of ["code", "requests", "flow"]) {
            const setup = surface === "code" && item.id !== "detected-running";
            const activity = surface === "code" ? setup ? "code" : "home" : surface;
            const panelSelector = surface === "code"
              ? setup ? '[data-testid="mooncode-runtime-setup"]' : '[data-testid="moongate-summary"]'
              : surface === "requests" ? '[data-testid="requests-capability"]'
              : '[data-testid="moonflow-runs-state-panel"]';
            const expectedState = surface === "flow" ? item.flowState : item.id;
            await session.send("Page.navigate", { url:
              `${baseUrl}/?locale=en-US&activity=${activity}&workspace=book-research-alpha&` +
              `capability_case=${encodeURIComponent(item.id)}` });
            if (firstNavigation) { await substitution.waitForFirstSettle(); firstNavigation = false; }
            await waitFor(session,
              `document.querySelector(${JSON.stringify(panelSelector)})?.dataset.state === ${jsString(expectedState)}`,
              `${mode.id} ${surface} ${item.id}`);
            const start = await session.evaluate(
              "({ scrollY, width: innerWidth, height: innerHeight })",
            );
            assert(
              Math.abs(start.scrollY) <= 0.5,
              `${mode.id} ${surface} ${item.id} must naturally start at scrollY zero`,
            );
            let scaled = null;
            if (mode.textFactor) {
              await sleep(250);
              await waitTwoAnimationFrames(session);
              scaled = await setTextOnlyScale(session, mode.textFactor);
            }
            try {
              if (mode.textFactor) {
                scaled.coverage = await textOnlyScaleCoverage(session);
                assert(
                  scaled.coverage.active &&
                    scaled.coverage.unmarkedCount === 0,
                  `${mode.id} ${surface} ${item.id} has incomplete text-scale ` +
                    `coverage: ${JSON.stringify(scaled.coverage)}`,
                );
              }
              const geometry = await capabilityResponsiveGeometry(
                session,
                item,
                surface,
                { width: mode.width, height: mode.height },
                mode.textFactor !== null,
              );
              for (const [key, value] of Object.entries({
                atDocumentStart: geometry.atDocumentStart,
                noHorizontalOverflow: geometry.noHorizontalOverflow,
                panelVisible: geometry.panelVisible,
                panelInsideContract: geometry.panelInsideContract,
                panelNotClipped: geometry.panelNotClipped,
                titleVisible: geometry.title?.visible && geometry.title?.inside,
                detailVisible: geometry.detail?.visible && geometry.detail?.inside,
                disclosureContract: geometry.disclosureContract,
                actionReachable: geometry.actionVisibleWhenApplicable,
                correctNavigation: geometry.correctNavigation,
                noRootOverlap: geometry.noRootOverlap,
                noContentOverlap: geometry.noContentOverlap,
                primaryWorkUsable: geometry.primaryWorkUsable,
              })) assert(value, `${mode.id} ${surface} ${item.id} failed ${key}: ${JSON.stringify(geometry)}`);
              if (mode.textFactor) {
                scaled.geometryCoverage = await textOnlyScaleCoverage(session);
                assert(
                  scaled.geometryCoverage.active &&
                    scaled.geometryCoverage.unmarkedCount === 0,
                  `${mode.id} ${surface} ${item.id} replaced scaled nodes ` +
                    `during geometry: ${JSON.stringify(scaled.geometryCoverage)}`,
                );
              }
              cases.push({ mode: mode.id, viewpoint: `${mode.width}x${mode.height}`,
                evidenceCase: item.id, surface, state: expectedState, scaled, geometry });
              if (
                (item.id === "not-installed" && surface === "code") ||
                (item.id === "misconfigured" && surface === "requests") ||
                (item.id === "detected-running" && surface === "flow") ||
                (item.id === "installed-stopped" && surface === "flow")
              ) {
                screenshots.push(await captureDeskScreenshot(session,
                  `desk-capability-scale-${mode.id}-${surface}-${item.id}`, mode.width, mode.height));
              }
              if (mode.textFactor) {
                scaled.captureCoverage = await textOnlyScaleCoverage(session);
                assert(
                  scaled.captureCoverage.active &&
                    scaled.captureCoverage.unmarkedCount === 0,
                  `${mode.id} ${surface} ${item.id} replaced scaled nodes ` +
                    `during capture: ${JSON.stringify(scaled.captureCoverage)}`,
                );
              }
            } finally {
              if (mode.textFactor) {
                const restored = await restoreTextOnlyScale(session);
                const afterRestore = await textOnlyScaleCoverage(session);
                assert(
                  restored > 0 &&
                    !afterRestore.active &&
                    afterRestore.markedCount === 0,
                  `${mode.id} ${surface} ${item.id} did not fully restore ` +
                    `text scaling: ${JSON.stringify({
                      restored,
                      initial: scaled.elementCount,
                      afterRestore,
                    })}`,
                );
                scaled.restoredCount = restored;
                scaled.afterRestore = afterRestore;
              }
            }
          }
        }
        const transportProblems = session.pageProblems.map(problem => ({
          ...problem,
        }));
        if (item.unavailable) {
          assert(
            transportProblems.length >= 2 &&
              transportProblems.every(problem =>
                problem.kind === "log.error" &&
                problem.text.includes("503") &&
                (
                  problem.url.endsWith("/api/moonclaw/daemon") ||
                  problem.url.endsWith("/api/town/daemon/status")
                )
              ),
            `Capability scale unavailable case emitted unexpected errors: ` +
              `${JSON.stringify(transportProblems)}`,
          );
        } else {
          session.assertNoPageProblems(`capability scale ${item.id}`);
        }
        session.clearPageProblems();
      } finally {
        await substitution.close();
      }
    }
    const counts = {
      total: cases.length,
      browserZoom: cases.filter(item => item.mode === "browser-zoom-200").length,
      textOnly: cases.filter(item => item.mode.startsWith("text-only")).length,
      evidenceCases: new Set(cases.map(item => item.evidenceCase)).size,
      surfaces: Object.fromEntries(["code", "requests", "flow"].map(surface =>
        [surface, cases.filter(item => item.surface === surface).length])),
      viewpoints: Object.fromEntries(modes.map(mode =>
        [mode.id, cases.filter(item => item.mode === mode.id).length])),
    };
    const uniqueKeys = new Set(cases.map(item =>
      `${item.mode}:${item.surface}:${item.evidenceCase}:${item.state}`
    ));
    assert(
      counts.total === 54 &&
        counts.browserZoom === 18 &&
        counts.textOnly === 36 &&
        counts.evidenceCases === 6 &&
        Object.values(counts.surfaces).every(value => value === 18) &&
        Object.values(counts.viewpoints).every(value => value === 18) &&
        uniqueKeys.size === 54 &&
        screenshots.length === 12,
      `capability scale matrix count mismatch: ${JSON.stringify(counts)}`);
    const proof = { kind: "moondesk-capability-scale-proof.v1", version: 1,
      scaleFactor: 2, counts, uniqueCaseCount: uniqueKeys.size,
      screenshotCount: screenshots.length, screenshots, cases };
    const proofPath = path.join(fixtureRoot, "desk-capability-scale-proof.json");
    fs.writeFileSync(proofPath, `${JSON.stringify(proof, null, 2)}\n`);
    console.log(`Capability scale proof: ${proofPath}`);
    return proof;
  } finally { session.close(); }
}

async function runCapabilityResponsiveEvidence() {
  const session = await connect(cdpPort);
  try {
    await session.send("Page.enable");
    await enablePageProblemCapture(session);
    await setEnglishLocale(session);
    const viewports = [
      { width: 1440, height: 900 },
      { width: 1024, height: 768 },
      { width: 390, height: 844 },
      { width: 320, height: 700 },
    ];
    const cases = [];
    const substitutionCounts = [];
    for (const item of capabilityRenderedCases) {
      const substitution = await installCapabilityResponseSubstitution(
        session,
        item,
      );
      let firstNavigation = true;
      try {
        for (const viewport of viewports) {
          await setViewport(session, viewport.width, viewport.height);
        for (const surface of ["code", "requests", "flow"]) {
          const codeUsesRuntimeSetup =
            surface === "code" && item.id !== "detected-running";
          const activity = surface === "code"
            ? codeUsesRuntimeSetup ? "code" : "home"
            : surface;
          const panelSelector = surface === "code"
            ? codeUsesRuntimeSetup
              ? '[data-testid="mooncode-runtime-setup"]'
              : '[data-testid="moongate-summary"]'
            : surface === "requests"
              ? '[data-testid="requests-capability"]'
              : '[data-testid="moonflow-runs-state-panel"]';
          const expectedState = surface === "flow" ? item.flowState : item.id;
          await session.send("Page.navigate", {
            url:
              `${baseUrl}/?locale=en-US&activity=${activity}&` +
              `workspace=book-research-alpha&` +
              `capability_case=${encodeURIComponent(item.id)}`,
          });
          if (firstNavigation) {
            await substitution.waitForFirstSettle();
            firstNavigation = false;
          }
          await waitFor(
            session,
            `document.querySelector(${JSON.stringify(panelSelector)})?.dataset.state === ` +
              `${jsString(expectedState)}`,
            `${surface} ${item.id} responsive capability panel`,
          );
          const geometry = await capabilityResponsiveGeometry(
            session, item, surface, viewport,
          );
          for (const [key, value] of Object.entries({
            atDocumentStart: geometry.atDocumentStart,
            noHorizontalOverflow: geometry.noHorizontalOverflow,
            panelVisible: geometry.panelVisible,
            panelInsideContract: geometry.panelInsideContract,
            panelNotClipped: geometry.panelNotClipped,
            disclosureContract: geometry.disclosureContract,
            actionVisibleWhenApplicable: geometry.actionVisibleWhenApplicable,
            correctNavigation: geometry.correctNavigation,
            noRootOverlap: geometry.noRootOverlap,
            primaryWorkUsable: geometry.primaryWorkUsable,
            titleVisible: geometry.title?.visible,
            detailVisible: geometry.detail?.visible,
          })) {
            assert(
              value,
              `${surface}/${item.id}/${viewport.width}x${viewport.height}: ` +
                `${key}: ${JSON.stringify(geometry)}`,
            );
          }
          assert(geometry.state === geometry.expectedState,
            `${surface}/${item.id}: state mismatch`);
          const capture =
            (surface === "code" && item.id === "not-installed") ||
            (surface === "requests" && item.id === "misconfigured") ||
            (surface === "flow" && item.flowAvailable) ||
            (surface === "flow" && item.id === "installed-stopped");
          geometry.screenshot = capture
            ? await captureDeskScreenshot(
                session,
                `desk-capability-responsive-${surface}-${item.id}-` +
                  `${viewport.width}x${viewport.height}`,
                viewport.width,
                viewport.height,
              )
            : "";
          cases.push(geometry);
        }
        }
        const transportProblems = session.pageProblems.map(problem => ({
          ...problem,
        }));
        if (item.unavailable) {
          assert(
            transportProblems.length >= 2 &&
              transportProblems.every(problem =>
                problem.kind === "log.error" &&
                problem.text.includes("503") &&
                (
                  problem.url.endsWith("/api/moonclaw/daemon") ||
                  problem.url.endsWith("/api/town/daemon/status")
                )
              ),
            `Responsive unavailable case emitted unexpected browser errors: ` +
              `${JSON.stringify(transportProblems)}`,
          );
        } else {
          session.assertNoPageProblems(
            `responsive capability ${item.id}`,
          );
        }
        session.clearPageProblems();
        substitutionCounts.push({
          caseId: item.id,
          recordCount: substitution.records.length,
        });
      } finally {
        await substitution.close();
      }
    }
    const caseKeys = new Set(cases.map(item =>
      `${item.surface}:${item.caseId}:${item.state}:` +
        `${item.viewport.width}x${item.viewport.height}`
    ));
    const screenshotCount = cases.filter(item => item.screenshot !== "").length;
    assert(cases.length === 72, `Responsive proof has ${cases.length} cases`);
    assert(caseKeys.size === 72, `Responsive proof has ${caseKeys.size} unique cases`);
    assert(screenshotCount === 16, `Responsive proof has ${screenshotCount} screenshots`);
    for (const viewport of viewports) {
      const viewportCases = cases.filter(item =>
        item.viewport.width === viewport.width &&
        item.viewport.height === viewport.height
      );
      assert(
        viewportCases.length === 18,
        `${viewport.width}x${viewport.height} has ${viewportCases.length} cases`,
      );
    }
    const proofPath = path.join(
      fixtureRoot, "desk-capability-responsive-geometry-proof.json",
    );
    fs.writeFileSync(proofPath, JSON.stringify({
      kind: "moondesk-capability-responsive-geometry-proof.v1",
      viewports,
      caseCount: cases.length,
      screenshotCount,
      surfaceCaseCounts: { code: 24, requests: 24, flow: 24 },
      stateCaseCounts: { code: 6, requests: 6, flow: 2 },
      substitutionCounts,
      cases,
      reuses: ["moondesk-rendered-capability-state-proof.v1",
        "moondesk-capability-keyboard-focus-proof.v1"],
    }, null, 2) + "\n");
    console.log(`Responsive capability geometry proof: ${proofPath}`);
  } finally {
    session.close();
  }
}

async function runCapabilityRenderedEvidence() {
  const session = await connect(cdpPort);
  try {
    await session.send("Page.enable");
    await enablePageProblemCapture(session);
    await setEnglishLocale(session);
    await setViewport(session, 1440, 900);
    const cases = [];
    for (const item of capabilityRenderedCases) {
      cases.push(await runCapabilityRenderedCase(session, item));
    }
    const codeStates = new Set(cases.map(item => item.code.state));
    const requestsStates = new Set(cases.map(item => item.requests.state));
    const flowStates = new Set(cases.map(item => item.flow.state));
    assert(codeStates.size === 6, `Capability proof has ${codeStates.size} Code states`);
    assert(
      requestsStates.size === 6,
      `Capability proof has ${requestsStates.size} Requests states`,
    );
    assert(
      flowStates.has("legitimate-zero") && flowStates.has("capability-limited"),
      `Capability proof is missing a Flow boundary: ${JSON.stringify([...flowStates])}`,
    );
    const keyboardCases = cases.flatMap(item =>
      Object.values(item.keyboardFocus).filter(value => value !== null)
    );
    const codeKeyboardCases = keyboardCases.filter(item => item.surface === "code");
    const requestsKeyboardCases = keyboardCases.filter(
      item => item.surface === "requests",
    );
    const flowKeyboardCases = keyboardCases.filter(item => item.surface === "flow");
    assert(
      keyboardCases.length === 16 &&
        codeKeyboardCases.length === 6 &&
        requestsKeyboardCases.length === 5 &&
        flowKeyboardCases.length === 5,
      `Capability keyboard proof has the wrong matrix: ` +
        `${JSON.stringify({
          total: keyboardCases.length,
          code: codeKeyboardCases.length,
          requests: requestsKeyboardCases.length,
          flow: flowKeyboardCases.length,
        })}`,
    );
    const proofPath = path.join(
      fixtureRoot,
      "desk-rendered-capability-state-proof.json",
    );
    fs.writeFileSync(
      proofPath,
      `${JSON.stringify({
        kind: "moondesk-rendered-capability-state-proof.v1",
        viewport: { width: 1440, height: 900 },
        caseCount: cases.length,
        codeStates: [...codeStates],
        requestsStates: [...requestsStates],
        flowStates: [...flowStates],
        cases,
      }, null, 2)}\n`,
    );
    console.log(`Rendered capability-state proof: ${proofPath}`);
    const keyboardProofPath = path.join(
      fixtureRoot,
      "desk-capability-keyboard-focus-proof.json",
    );
    fs.writeFileSync(
      keyboardProofPath,
      `${JSON.stringify({
        kind: "moondesk-capability-keyboard-focus-proof.v1",
        viewport: { width: 1440, height: 900 },
        naturalDocumentFocus: true,
        programmaticFocusUsed: false,
        activationKeys: ["Tab", "Space", "Escape", "Shift+Tab"],
        caseCount: keyboardCases.length,
        codeCaseCount: codeKeyboardCases.length,
        requestsCaseCount: requestsKeyboardCases.length,
        flowCaseCount: flowKeyboardCases.length,
        cases: keyboardCases,
      }, null, 2)}\n`,
    );
    console.log(`Capability keyboard-focus proof: ${keyboardProofPath}`);
  } finally {
    session.close();
  }
}

async function runAccessibility() {
  const session = await connect(cdpPort);
  try {
    await enablePageProblemCapture(session);
    await setEnglishLocale(session);
    const skipCases = [];
    for (const viewport of sharedShellAccessibilityViewports) {
      skipCases.push(
        await runSkipLandmarkAccessibilityCase(session, viewport),
      );
    }
    const destinationCases = [];
    for
      (const viewport of [
        sharedShellAccessibilityViewports[0],
        sharedShellAccessibilityViewports[2],
      ]) {
      destinationCases.push(
        await runDestinationAccessibilityCase(session, viewport),
      );
    }
    const stateTransitionCount = destinationCases
      .flatMap(item => item.routes)
      .flatMap(item => item.stateTransitions?.states ?? [])
      .length;
    assert(skipCases.length === 4, "Accessibility proof requires four skip cases");
    assert(
      destinationCases.length === 2 &&
        destinationCases.every(item => item.routeCount === 5),
      "Accessibility proof requires two five-destination cases",
    );
    assert(
      stateTransitionCount === 3,
      `Accessibility proof requires three typed state transitions: ${stateTransitionCount}`,
    );
    const proofPath = path.join(
      fixtureRoot,
      "desk-shared-shell-accessibility-proof.json",
    );
    fs.writeFileSync(
      proofPath,
      `${JSON.stringify({
        kind: "moondesk-shared-shell-accessibility-proof.v1",
        skipCaseCount: skipCases.length,
        destinationCaseCount: destinationCases.length,
        routeCaseCount: destinationCases.reduce(
          (count, item) => count + item.routeCount,
          0,
        ),
        stateTransitionCount,
        skipCases,
        destinationCases,
      }, null, 2)}\n`,
    );
    console.log(`Shared shell accessibility proof: ${proofPath}`);
    session.assertNoPageProblems("shared shell accessibility");
  } finally {
    session.close();
  }
}

async function run() {
  verifyDeskStyleImports();
  const session = await connect(cdpPort);
  const screenshots = [];
  try {
    await session.send("Page.enable");
    await setEnglishLocale(session);
    await enablePageProblemCapture(session);
    await setViewport(session, 1440, 900);
    await session.send("Page.navigate", { url: `${baseUrl}/?locale=en-US` });
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
    const manyBookKeyboardCases = await verifyWorkspaceKeyboardMatrix(session, {
      cardinality: "many",
      expectedRowCount: 4,
      startWorkspaceId: "book-research-alpha",
      startWorkspaceName: "Research Alpha",
      targetWorkspaceId: "book-research-beta",
      targetWorkspaceName: "Research Beta",
    });
    const manyBookKeyboardProof = writeWorkspaceKeyboardPartialProof(
      "many",
      manyBookKeyboardCases,
    );
    console.log(`Many-book keyboard proof: ${manyBookKeyboardProof}`);
    await navigateWorkspaceKeyboardCase(
      session,
      workspaceKeyboardViewports[0],
      "book-research-alpha",
      4,
      "Research Alpha",
      "restore populated Home after many-book keyboard matrix",
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
    const codeAssistanceState = await session.evaluate(`(() => {
      const card = document.querySelector('[data-testid="moongate-summary"]');
      const publicSummary = card?.querySelector(
        '[data-testid="code-assistance-public-summary"]'
      );
      const technical = card?.querySelector(
        '[data-testid="code-assistance-technical-details"]'
      );
      return {
        state: card?.dataset.state ?? '',
        cardVisibleText: card?.innerText ?? '',
        publicText: publicSummary?.textContent ?? '',
        technicalText: technical?.textContent ?? '',
        technicalOpen: technical?.open === true,
      };
    })()`);
    const ordinaryInternalTerms = ["MoonClaw", "MoonGate", "daemon", "AI boundary"];
    assert(
      codeAssistanceState.state === "detected-running" &&
        codeAssistanceState.publicText.includes("Code assistance is ready") &&
        codeAssistanceState.publicText.includes(
          "You can start or continue Code conversations.",
        ) &&
        ordinaryInternalTerms.every(
          term => !codeAssistanceState.publicText.includes(term),
        ) &&
        ordinaryInternalTerms.every(
          term => !codeAssistanceState.cardVisibleText.includes(term),
        ) &&
        codeAssistanceState.technicalText.includes("MoonClaw") &&
        codeAssistanceState.technicalText.includes("Platform:") &&
        !codeAssistanceState.technicalOpen,
      `Home Code assistance copy boundary mismatch: ${JSON.stringify(codeAssistanceState)}`,
    );
    const copyProofPath = path.join(
      fixtureRoot,
      "desk-first-use-copy-proof.json",
    );
    fs.writeFileSync(
      copyProofPath,
      `${JSON.stringify({
        kind: "moondesk-first-use-copy-partial-proof.v1",
        scope: "home-code-assistance",
        ordinaryInternalTerms,
        ...codeAssistanceState,
      }, null, 2)}\n`,
    );
    console.log(`First-use copy proof: ${copyProofPath}`);
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
      `document.querySelector('[data-testid="desk-open-embedded-preview"]')?.textContent.includes('Preview / Run here') && !document.querySelector('[data-testid="desk-preview"] a[target="_blank"]')`,
      "generated-site preview stays inside MoonDesk",
    );
    await clickTestId(session, "desk-open-embedded-preview");
    await waitFor(
      session,
      `document.querySelector('[data-testid="browser-preview-host"]') && document.querySelector('[data-testid="browser-prepare-evidence"]')?.textContent.includes('Prepare evidence')`,
      "embedded browser evidence preparation UI",
    );
    await clickTestId(session, "browser-prepare-evidence");
    await waitFor(
      session,
      `document.querySelector('[data-testid="browser-preview-host"]')?.dataset.evidenceState === 'persisted'`,
      "browser evidence host receipt persisted",
    );
    const durableEvidenceRef = await session.evaluate(
      `document.querySelector('[data-testid="browser-preview-host"]')?.dataset.evidenceRef || ''`,
    );
    assert(
      durableEvidenceRef.startsWith("book/evidence/browser/") &&
        fs.existsSync(path.join(fixtureRoot, "books/research-alpha", durableEvidenceRef)),
      `Browser evidence receipt did not resolve to durable book evidence: ${durableEvidenceRef}`,
    );
    await session.evaluate(`globalThis.dispatchEvent(new CustomEvent('moondesk-browser-evidence-status', {
      detail: { protocol: 'moondesk-browser-host-v1', state: 'persisted' }
    }))`);
    assert(
      await session.evaluate(`document.querySelector('[data-testid="browser-preview-host"]')?.dataset.evidenceState !== 'persisted'`),
      "Evidence became persisted without host receipt and durable reference",
    );
    await session.evaluate(`globalThis.dispatchEvent(new CustomEvent('moondesk-browser-evidence-status', {
      detail: { protocol: 'moondesk-browser-host-v1', state: 'failed', reason: 'fixture persistence failure' }
    }))`);
    await waitFor(
      session,
      `document.querySelector('[data-testid="browser-preview-status"]')?.textContent.includes('Evidence not persisted')`,
      "browser evidence persistence failure",
    );
    await session.evaluate(`globalThis.dispatchEvent(new CustomEvent('moondesk-browser-evidence-status', {
      detail: {
        protocol: 'moondesk-browser-host-v1', state: 'persisted',
        hostReceiptId: 'fixture-host-receipt', evidenceRef: 'book://evidence/browser/fixture.json'
      }
    }))`);
    await waitFor(
      session,
      `document.querySelector('[data-testid="browser-preview-host"]')?.dataset.evidenceState === 'persisted'`,
      "browser evidence persisted receipt",
    );
    await session.evaluate(`globalThis.dispatchEvent(new CustomEvent('moondesk-browser-host-status', {
      detail: { protocol: 'moondesk-browser-host-v1', state: 'restarted', label: 'Browser host restarted' }
    }))`);
    await waitFor(
      session,
      `document.querySelector('[data-testid="browser-preview-host"]')?.dataset.evidenceState === 'not-persisted' && document.querySelector('[data-testid="browser-preview-status"]')?.textContent.includes('not persisted')`,
      "browser evidence reset after host restart",
    );
    await clickTestId(session, "mode-desk");
    await waitFor(session, `document.querySelector('[data-testid="desk-mode"]')`, "return to Desk after embedded preview evidence test");
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
    // Phase 1 narrow-phone acceptance: captureDeskViewport applies the shared
    // no-page-overflow, no-pane-overlap, and reachable-primary-content checks.
    screenshots.push(await captureDeskViewport(session, "narrow-mobile", 320, 700));
    // Browser-zoom reflow equivalence: a 1440x900 physical window at 200%
    // exposes an exact 720x450 CSS viewport. captureDeskViewport keeps all
    // shared geometry, reachability, ordering, overflow, PNG, and error checks.
    screenshots.push(await captureDeskViewport(session, "zoom-200-percent", 720, 450));

    const textOnlyProof = [];
    for (const [label, width, height] of [
      ["desktop", 1440, 900],
      ["narrow", 320, 700],
    ]) {
      // Existing mobile captures above exercise device emulation. Keep this
      // acceptance path in a fixed CSS viewport so text enlargement cannot be
      // conflated with Chrome's synthetic mobile page-scale heuristics.
      await setViewport(session, width, height, false, true);
      const before = await session.evaluate(`({ width: innerWidth, height: innerHeight, devicePixelRatio })`);
      const applied = await setTextOnlyScale(session, 2);
      try {
        await session.evaluate(`(async () => {
          scrollTo(0, 0);
          for (const element of document.querySelectorAll(
            '.desk-sidebar,.desk-browser,.desk-details,.desk-file-table'
          )) {
            element.scrollTop = 0;
            element.scrollLeft = 0;
          }
          await new Promise(resolve => requestAnimationFrame(() =>
            requestAnimationFrame(resolve)));
        })()`);
        await verifyDeskVisualLayout(session, `text-only-${label}`);
        const geometry = await collectTextOnlyGeometry(session, width, height);
        assert(
          geometry.viewport.width === width && geometry.viewport.height === height,
          `text-only ${label} changed viewport: ${JSON.stringify(geometry.viewport)}`,
        );
        assert(
          applied.devicePixelRatio === before.devicePixelRatio,
          `text-only ${label} changed device scale`,
        );
        assert(!geometry.horizontalOverflow,
          `text-only ${label} horizontally overflows: ${JSON.stringify(geometry)}`);
        assert(geometry.panes.every((pane, index, panes) => panes.every((other, otherIndex) =>
          index === otherIndex || pane.rect.right <= other.rect.left + 1 ||
          other.rect.right <= pane.rect.left + 1 || pane.rect.bottom <= other.rect.top + 1 ||
          other.rect.bottom <= pane.rect.top + 1)),
          `text-only ${label} panes overlap: ${JSON.stringify(geometry.panes)}`);
        assert(
          label === "narrow"
            ? geometry.compactPrimaryVisible && !geometry.desktopPrimaryVisible
            : geometry.desktopPrimaryVisible && !geometry.compactPrimaryVisible,
          `text-only ${label} uses the wrong primary navigation: ${JSON.stringify(geometry)}`,
        );
        for (const [group, targets] of Object.entries(geometry.targets)) {
          assert(targets.length > 0, `text-only ${label} has no visible ${group}`);
          assert(targets.every(target =>
            !target.clipped && (group === "historyActions" || target.enabled)),
            `text-only ${label} has disabled or clipped ${group}: ${JSON.stringify(targets)}`);
        }
        session.assertNoPageProblems(`text-only ${label}`);
        screenshots.push(await captureDeskScreenshot(
          session, `desk-text-only-200-${label}-${width}x${height}`, width, height));
        textOnlyProof.push({ label, factor: 2, applied, geometry });
      } finally {
        const restored = await restoreTextOnlyScale(session);
        assert(restored === applied.elementCount,
          `text-only ${label} did not restore every element: ${restored}/${applied.elementCount}`);
      }
    }
    fs.writeFileSync(path.join(fixtureRoot, "desk-text-only-200-geometry-proof.json"),
      `${JSON.stringify({ kind: "text-only-large-text", cases: textOnlyProof }, null, 2)}\n`);

    // The text-only cases intentionally leave their final narrow viewport in
    // place. Restore the earlier browser-zoom contract before asserting it.
    await setViewport(session, 720, 450);
    const zoomContract = await session.evaluate(`({
      width: window.innerWidth,
      height: window.innerHeight,
      compactPrimaryVisible: (() => {
        const control = document.querySelector('.primary-nav-compact summary');
        if (!control) return false;
        const style = getComputedStyle(control);
        const rect = control.getBoundingClientRect();
        return style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
      })(),
      compactPrimaryFocusable: (() => {
        const control = document.querySelector('.primary-nav-compact summary');
        if (!control) return false;
        control.focus();
        return document.activeElement === control;
      })(),
    })`);
    assert(
      zoomContract.width === 720 && zoomContract.height === 450,
      `200% browser zoom reflow contract requires a 720x450 CSS viewport for a 1440x900 physical window: ${JSON.stringify(zoomContract)}`,
    );
    assert(
      zoomContract.compactPrimaryVisible && zoomContract.compactPrimaryFocusable,
      `200% browser zoom reflow at 1440x900 must keep the compact primary destination control visible and keyboard-focusable: ${JSON.stringify(zoomContract)}`,
    );
    await setViewport(session, 1440, 900);
    await verifyKeyboardAcceptance(session);
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
    await setEnglishLocale(session);
    await enablePageProblemCapture(session);
    await setViewport(session, 1440, 900);
    await session.send("Page.navigate", { url: `${baseUrl}/?locale=en-US` });
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
      `document.querySelector('[data-testid="desk-cold-start"]')?.dataset.state === 'empty-library'`,
      "empty MoonBook library state",
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
        libraryState.addBookOpen,
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
    await clickTestId(session, "mode-wiki");
    await waitFor(
      session,
      `!!document.querySelector('[data-testid="wiki-tab-requests"]')`,
      "Wiki tabs after empty-library creation",
    );
    await clickTestId(session, "wiki-tab-requests");
    await waitFor(
      session,
      `location.search.includes('activity=requests') && ` +
        `document.querySelector('[data-testid="wiki-tab-requests"]')?.getAttribute('aria-pressed') === 'true'`,
      "Requests navigation after empty-library creation",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="requests-state-panel"]')?.dataset.state === 'legitimate-zero' && ` +
        `document.querySelector('[data-testid="requests-state-panel"]')?.innerText.includes('No requests yet') && ` +
        `document.querySelector('[data-testid="requests-state-panel"]')?.innerText.includes('no saved requests yet')`,
      "honest empty Requests ledger",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="requests-capability"]')?.dataset.state === 'not-installed' && ` +
        `document.querySelector('[data-testid="requests-capability"]')?.innerText.includes('Requests can still be saved') && ` +
        `document.querySelector('[data-testid="requests-capability"]')?.innerText.includes('Review setup')`,
      "Requests misconfigured automation capability",
    );
    await setInputByTestId(
      session,
      "requests-prompt",
      "Keep this request stageable without automation.",
    );
    await waitFor(
      session,
      `document.querySelector('[data-testid="requests-submit"]')?.disabled === false`,
      "Requests composer remains enabled without automation",
    );
    await clickTestId(session, "wiki-tab-runs");
    await waitFor(
      session,
      `location.search.includes('activity=runs') && ` +
        `!!document.querySelector('[data-testid="runs-workspace"]') && ` +
        `document.querySelector('[data-testid="runs-state-panel"]')?.dataset.state === 'legitimate-zero' && ` +
        `document.querySelector('[data-testid="runs-state-panel"]')?.textContent.includes('No runs yet')`,
      "honest empty Runs destination",
    );
    await clickTestId(session, "wiki-tab-review");
    await waitFor(
      session,
      `location.search.includes('activity=review') && ` +
        `document.querySelector('[data-testid="review-state-panel"]')?.dataset.state === 'legitimate-zero'`,
      "honest empty Review destination",
    );
    await clickTestId(session, "wiki-tab-publish");
    await waitFor(
      session,
      `location.search.includes('activity=publish') && ` +
        `!!document.querySelector('[data-testid="publish-workspace"]') && ` +
        `document.querySelector('[data-testid="publish-state-panel"]')?.dataset.state === 'legitimate-zero' && ` +
        `!!document.querySelector('[data-testid="publish-output-check"]') && ` +
        `!document.querySelector('[data-testid="publish-workspace"]')?.innerText.includes('output is ready')`,
      "honest Publish destination",
    );
    await clickTestId(session, "mode-wiki");
    await waitFor(
      session,
      `location.search.includes('activity=pages') && ` +
        `document.querySelectorAll('.rail-buttons .rail-button').length === 4 && ` +
        `!document.querySelector('[data-testid="activity-activity"]') && ` +
        `!document.querySelector('[data-testid="activity-review"]')`,
      "Wiki page rail excludes workflow tabs",
    );
    await setViewport(session, 320, 700);
    await waitFor(
      session,
      `getComputedStyle(document.querySelector('.primary-nav-desktop')).display === 'none' && ` +
        `getComputedStyle(document.querySelector('[data-testid="primary-nav-summary"]')).display !== 'none' && ` +
        `document.documentElement.scrollWidth <= document.documentElement.clientWidth + 1`,
      "compact primary navigation without horizontal overflow",
    );
    const compactSummaryFocused = await session.evaluate(`(() => {
      const summary = document.querySelector('[data-testid="primary-nav-summary"]');
      summary?.focus();
      return document.activeElement === summary;
    })()`);
    assert(compactSummaryFocused, "Compact primary navigation summary cannot receive focus");
    await dispatchKey(session, " ", "Space");
    await waitFor(
      session,
      `document.querySelector('[data-testid="primary-nav-summary"]')?.parentElement?.open === true`,
      "keyboard-opened compact primary navigation",
    );
    const compactRequestsFocused = await session.evaluate(`(() => {
      const button = document.querySelector('[data-testid="compact-mode-wiki"]');
      button?.focus();
      return document.activeElement === button;
    })()`);
    assert(compactRequestsFocused, "Compact Wiki action cannot receive focus");
    await dispatchKey(session, " ", "Space");
    await waitFor(
      session,
      `location.search.includes('activity=pages') && ` +
        `!!document.querySelector('[data-testid="wiki-tab-requests"]')`,
      "keyboard-operated compact Wiki destination",
    );
    const compactRequestsTabFocused = await session.evaluate(`(() => {
      const button = document.querySelector('[data-testid="wiki-tab-requests"]');
      button?.focus();
      return document.activeElement === button;
    })()`);
    assert(compactRequestsTabFocused, "Compact Requests tab cannot receive focus");
    await dispatchKey(session, " ", "Space");
    await waitFor(
      session,
      `location.search.includes('activity=requests') && ` +
        `!!document.querySelector('[data-testid="requests-state-panel"]')`,
      "keyboard-operated compact Requests tab",
    );
    await setViewport(session, 1440, 900);
    await clickTestId(session, "mode-desk");
    await waitFor(
      session,
      `document.querySelector('[data-testid="mode-desk"]')?.getAttribute('aria-pressed') === 'true'`,
      "return Home after Requests capability proof",
    );
    await clickTestId(session, "mode-code");
    await waitFor(
      session,
      `document.readyState === 'complete' && ` +
        `!!document.querySelector('[data-testid="mooncode-runtime-setup"]') && ` +
        `!!document.querySelector('[data-testid="mooncode-install-moonclaw"]')`,
      "Code capability setup control",
    );
    const capabilityControlDebug = await session.evaluate(`(() => {
      const el = document.querySelector('[data-testid="mooncode-install-moonclaw"]');
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
      capabilityControlDebug.rect &&
        capabilityControlDebug.rect.width > 0 &&
        capabilityControlDebug.rect.height > 0 &&
        capabilityControlDebug.hit.includes('mooncode-install-moonclaw') &&
        !capabilityControlDebug.disabled,
      `Code capability setup control is not a visible pointer target: ${JSON.stringify(capabilityControlDebug)}`,
    );
    console.log(`Code capability pointer target: ${JSON.stringify(capabilityControlDebug)}`);
    await clickTestId(session, "mode-desk");
    await waitFor(
      session,
      `location.search.includes('activity=home') && ` +
        `location.search.includes('workspace=book-empty-library-created') && ` +
        `document.querySelector('[data-testid="mode-desk"]')?.getAttribute('aria-pressed') === 'true'`,
      "Code capability return to Home",
    );
    console.log(`Desk empty-library screenshots: ${screenshots.join(", ")}`);
    session.assertNoPageProblems("Desk empty-library smoke");
  } finally {
    session.close();
  }
}

const keyboardTransientViewports = [
  { width: 1440, height: 900, navigation: "desktop" },
  { width: 1024, height: 768, navigation: "desktop" },
  { width: 390, height: 844, navigation: "compact" },
  { width: 320, height: 700, navigation: "compact" },
];

function assertUsableKeyboardFocus(focus, label) {
  assert(
    focus.connected &&
      focus.visible &&
      focus.inViewport &&
      !focus.disabled &&
      focus.focusVisible &&
      focus.focusIndicator,
    `${label} has no usable visible keyboard focus: ${JSON.stringify(focus)}`,
  );
}

async function keyboardNavigationState(session, viewport) {
  const state = await session.evaluate(`(() => {
    const visible = element => {
      if (!(element instanceof HTMLElement)) return false;
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return rect.width > 0 && rect.height > 0 &&
        style.display !== "none" && style.visibility !== "hidden";
    };
    const compact = document.querySelector("[data-testid=primary-nav-summary]");
    const desktop = Array.from(
      document.querySelectorAll(".primary-nav-desktop [data-testid^=mode-]")
    );
    const visibleFocusables = Array.from(document.querySelectorAll(
      'a[href],button,input,textarea,select,details > summary,' +
      '[tabindex]:not([tabindex="-1"])'
    )).filter(visible);
    return {
      compactVisible: visible(compact),
      desktopVisible: desktop.some(visible),
      hiddenFocusableCount: visibleFocusables.filter(element =>
        element.closest(".primary-nav-compact") && !visible(compact)
      ).length,
      documentWidth: document.documentElement.scrollWidth,
      viewportWidth: innerWidth
    };
  })()`);
  assert(
    state.documentWidth <= state.viewportWidth,
    `keyboard ${viewport.width}x${viewport.height} has horizontal overflow: ` +
      `${JSON.stringify(state)}`,
  );
  assert(
    viewport.navigation === "compact"
      ? state.compactVisible && !state.desktopVisible
      : !state.compactVisible && state.desktopVisible,
    `keyboard ${viewport.width}x${viewport.height} navigation mismatch: ` +
      `${JSON.stringify(state)}`,
  );
  assert(
    state.hiddenFocusableCount === 0,
    `keyboard ${viewport.width}x${viewport.height} exposes hidden navigation controls`,
  );
  return state;
}

async function beginKeyboardCase(
  session,
  viewport,
  url,
  readyExpression,
  label,
) {
  await setViewport(session, viewport.width, viewport.height);
  await session.send("Page.navigate", { url });
  await waitFor(
    session,
    `document.readyState === "complete" && (${readyExpression})`,
    `${label} rendered surface`,
  );
  await waitTwoAnimationFrames(session);
  const naturalFocus = await activeKeyboardFocus(session);
  assert(
    naturalFocus.tag === "body" &&
      naturalFocus.index === -1 &&
      naturalFocus.owningTestid === "",
    `${label} did not begin at natural document focus: ` +
      `${JSON.stringify(naturalFocus)}`,
  );
  const navigation = await keyboardNavigationState(session, viewport);
  return { naturalFocus, navigation };
}

async function tabToOwnedTestId(
  session,
  owningTestid,
  trace,
  label,
  maxSteps = 180,
) {
  const seen = new Set();
  for (let step = 1; step <= maxSteps; step += 1) {
    await dispatchKey(session, "Tab", "Tab");
    await waitTwoAnimationFrames(session);
    const focus = await activeKeyboardFocus(session);
    trace.push({ operation: "Tab", step, ...focus });
    assertUsableKeyboardFocus(focus, `${label} Tab ${step}`);
    if (focus.owningTestid === owningTestid) return focus;
    assert(
      !seen.has(focus.key),
      `${label} cycled before ${owningTestid}: ${JSON.stringify(trace)}`,
    );
    seen.add(focus.key);
  }
  throw new Error(`${label} did not reach owned surface ${owningTestid}`);
}

async function assertKeyboardRoundTrip(session, trigger, trace, label) {
  await dispatchKey(session, "Tab", "Tab", { shift: true });
  await waitTwoAnimationFrames(session);
  const reverse = await activeKeyboardFocus(session);
  trace.push({ operation: "Shift+Tab after restore", ...reverse });
  assertUsableKeyboardFocus(reverse, `${label} reverse traversal`);
  assert(
    reverse.key !== trigger.key,
    `${label} reverse traversal remained on the trigger`,
  );

  await dispatchKey(session, "Tab", "Tab");
  await waitTwoAnimationFrames(session);
  const returned = await activeKeyboardFocus(session);
  trace.push({ operation: "Tab after reverse", ...returned });
  assertUsableKeyboardFocus(returned, `${label} forward traversal`);
  assert(
    returned.key === trigger.key,
    `${label} did not round-trip to its exact trigger: ` +
      `${JSON.stringify({ trigger, reverse, returned })}`,
  );
  return { reverse, returned };
}

async function proveDisclosureTransient(
  session,
  {
    caseId,
    surface,
    viewport,
    url,
    readyExpression,
    owningTestid,
    innerTestid = "",
    activationKey,
  },
) {
  const label = `${caseId} ${surface}`;
  const trace = [];
  const start = await beginKeyboardCase(
    session,
    viewport,
    url,
    readyExpression,
    label,
  );
  trace.push({ operation: "Natural document focus", ...start.naturalFocus });
  const trigger = await tabToOwnedTestId(
    session,
    owningTestid,
    trace,
    label,
  );
  assert(
    trigger.tag === "summary" && !trigger.detailsOpen,
    `${label} did not reach a closed summary: ${JSON.stringify(trigger)}`,
  );

  await dispatchKey(
    session,
    activationKey,
    activationKey === " " ? "Space" : "Enter",
  );
  await waitTwoAnimationFrames(session);
  const opened = await activeKeyboardFocus(session);
  trace.push({
    operation: activationKey === " " ? "Space" : "Enter",
    ...opened,
  });
  assertUsableKeyboardFocus(opened, `${label} open`);
  assert(
    opened.key === trigger.key && opened.detailsOpen,
    `${label} did not open its exact owned disclosure: ` +
      `${JSON.stringify({ trigger, opened })}`,
  );

  let inner = null;
  if (innerTestid !== "") {
    inner = await tabToTestId(session, innerTestid, trace, label);
    assertUsableKeyboardFocus(inner, `${label} first disclosed action`);
    assert(
      inner.detailsTestid === owningTestid,
      `${label} escaped its owned disclosure: ${JSON.stringify(inner)}`,
    );
  }

  const screenshot = await captureDeskScreenshot(
    session,
    `desk-keyboard-transient-${caseId}`,
    viewport.width,
    viewport.height,
  );
  await dispatchKey(session, "Escape", "Escape");
  await waitTwoAnimationFrames(session);
  const restored = await activeKeyboardFocus(session);
  trace.push({ operation: "Escape", ...restored });
  assertUsableKeyboardFocus(restored, `${label} Escape restoration`);
  assert(
    restored.key === trigger.key && !restored.detailsOpen,
    `${label} did not restore its exact trigger: ` +
      `${JSON.stringify({ trigger, restored })}`,
  );
  const roundTrip = await assertKeyboardRoundTrip(
    session,
    trigger,
    trace,
    label,
  );
  return {
    caseId,
    kind: surface,
    viewport,
    activationKey: activationKey === " " ? "Space" : "Enter",
    owningTestid,
    innerTestid,
    naturalFocus: start.naturalFocus,
    navigation: start.navigation,
    trigger,
    opened,
    inner,
    restored,
    ...roundTrip,
    screenshot,
    trace,
  };
}

async function proveCommandPaletteTransient(session, viewport, index) {
  const caseId = `palette-${viewport.width}x${viewport.height}`;
  const label = `${caseId} command palette`;
  const trace = [];
  const start = await beginKeyboardCase(
    session,
    viewport,
    `${baseUrl}/?locale=en-US&activity=home&workspace=book-research-alpha&` +
      `keyboard_case=${caseId}`,
    `!!document.querySelector('[data-testid="desk-library-storage-details"]')`,
    label,
  );
  trace.push({ operation: "Natural document focus", ...start.naturalFocus });
  const triggerTestid = viewport.navigation === "desktop"
    ? "command-palette-toggle"
    : "primary-nav-summary";
  const trigger = await tabToTestId(
    session,
    triggerTestid,
    trace,
    label,
  );
  assertUsableKeyboardFocus(trigger, `${label} trigger`);

  const shortcut = index % 2 === 0 ? { meta: true } : { ctrl: true };
  await dispatchKey(session, "k", "KeyK", shortcut);
  await waitFor(
    session,
    `document.activeElement?.dataset.testid === "command-palette-input"`,
    `${label} input autofocus`,
  );
  const opened = await activeKeyboardFocus(session);
  trace.push({
    operation: shortcut.meta ? "Meta+K" : "Control+K",
    ...opened,
  });
  assertUsableKeyboardFocus(opened, `${label} autofocus`);
  assert(
    opened.testid === "command-palette-input",
    `${label} did not autofocus the palette input`,
  );

  const semantics = await accessibilityNodeForSelector(
    session,
    '[data-testid="command-palette-panel"]',
  );
  assert(
    semantics.role === "dialog" &&
      semantics.name === "Commands" &&
      (semantics.properties.modal === true ||
        semantics.properties.modal === "true"),
    `${label} dialog semantics mismatch: ${JSON.stringify(semantics)}`,
  );

  await dispatchKey(session, "Tab", "Tab", { shift: true });
  await waitTwoAnimationFrames(session);
  const trappedLast = await activeKeyboardFocus(session);
  trace.push({ operation: "Shift+Tab wraps to last", ...trappedLast });
  assertUsableKeyboardFocus(trappedLast, `${label} reverse trap`);
  assert(
    trappedLast.testid !== "command-palette-input" &&
      trappedLast.dialogTestid === "command-palette-panel",
    `${label} reverse Tab escaped the dialog: ${JSON.stringify(trappedLast)}`,
  );
  await dispatchKey(session, "Tab", "Tab");
  await waitTwoAnimationFrames(session);
  const trappedFirst = await activeKeyboardFocus(session);
  trace.push({ operation: "Tab wraps to first", ...trappedFirst });
  assertUsableKeyboardFocus(trappedFirst, `${label} forward trap`);
  assert(
    trappedFirst.testid === "command-palette-input",
    `${label} forward Tab did not wrap to the input: ` +
      `${JSON.stringify(trappedFirst)}`,
  );

  const screenshot = await captureDeskScreenshot(
    session,
    `desk-keyboard-transient-${caseId}`,
    viewport.width,
    viewport.height,
  );
  await session.send("Input.insertText", { text: "typed shortcut guard" });
  await waitFor(
    session,
    `document.querySelector('[data-testid="command-palette-input"]')?.value === ` +
      `"typed shortcut guard"`,
    `${label} typed query`,
  );
  const locationBeforeShortcut = await session.evaluate(`location.href`);
  await dispatchKey(session, "1", "Digit1", shortcut);
  await waitTwoAnimationFrames(session);
  const typingGuard = await activeKeyboardFocus(session);
  trace.push({
    operation: shortcut.meta ? "Meta+1 while typing" : "Control+1 while typing",
    ...typingGuard,
  });
  const locationAfterShortcut = await session.evaluate(`location.href`);
  assert(
    locationAfterShortcut === locationBeforeShortcut &&
      typingGuard.testid === "command-palette-input" &&
      await session.evaluate(
        `!!document.querySelector('[data-testid="command-palette-panel"]')`,
      ),
    `${label} fired an app shortcut while typing: ` +
      `${JSON.stringify({ locationBeforeShortcut, locationAfterShortcut, typingGuard })}`,
  );

  await dispatchKey(session, "Escape", "Escape");
  await waitFor(
    session,
    `!document.querySelector('[data-testid="command-palette-panel"]')`,
    `${label} close`,
  );
  await waitTwoAnimationFrames(session);
  const restored = await activeKeyboardFocus(session);
  trace.push({ operation: "Escape", ...restored });
  assertUsableKeyboardFocus(restored, `${label} Escape restoration`);
  assert(
    restored.key === trigger.key,
    `${label} did not restore its exact visible trigger: ` +
      `${JSON.stringify({ trigger, restored })}`,
  );
  const roundTrip = await assertKeyboardRoundTrip(
    session,
    trigger,
    trace,
    label,
  );
  return {
    caseId,
    kind: "command-palette",
    viewport,
    shortcut: shortcut.meta ? "Meta+K" : "Control+K",
    naturalFocus: start.naturalFocus,
    navigation: start.navigation,
    trigger,
    opened,
    semantics,
    trappedLast,
    trappedFirst,
    typingGuard,
    restored,
    ...roundTrip,
    screenshot,
    trace,
  };
}

function command061SessionFixture() {
  return {
    id: "command061-keyboard-session",
    workspace_id: "book-research-alpha",
    workspace_name: "Research Alpha",
    cwd: path.join(fixtureRoot, "books", "research-alpha"),
    source: "moonclaw",
    mooncode_runtime_session_id: "runtime-command061-keyboard-session",
    title: "Keyboard focus proof",
    model: "codex/gpt-5.6-sol",
    status: "idle",
    queued_count: 0,
    mooncode_summary: {
      event_count: 0,
      verified_test_count: 0,
      pending_diff_count: 0,
    },
    archived: false,
  };
}

async function installCommand061SessionSubstitution(session) {
  const fixture = command061SessionFixture();
  const records = [];
  let failure = null;
  const listener = params => {
    const url = new URL(params.request.url);
    if (!url.pathname.startsWith("/api/mooncode/sessions")) return;
    void (async () => {
      let body;
      if (url.pathname === "/api/mooncode/sessions") {
        body = url.searchParams.get("scope") === "archived" ? [] : [fixture];
      } else if (
        url.pathname === `/api/mooncode/sessions/${fixture.id}/watch`
      ) {
        body = {
          kind: "moonsuite-conversation-watch",
          contract_id: "moonsuite-conversation-watch.v1",
          session_id: fixture.id,
          revision: 0,
          next_sequence: 0,
          changed: false,
          heartbeat: true,
          terminal: false,
          retry_after_ms: 60000,
        };
      } else {
        body = fixture;
      }
      await session.send("Fetch.fulfillRequest", {
        requestId: params.requestId,
        responseCode: 200,
        responseHeaders: [
          { name: "Content-Type", value: "application/json; charset=utf-8" },
          { name: "Cache-Control", value: "no-store" },
        ],
        body: Buffer.from(JSON.stringify(body)).toString("base64"),
      });
      records.push({
        pathname: url.pathname,
        format: url.searchParams.get("format") || "",
        scope: url.searchParams.get("scope") || "active",
      });
    })().catch(error => {
      failure = error;
    });
  };
  session.on("Fetch.requestPaused", listener);
  await session.send("Fetch.enable", {
    patterns: [{
      urlPattern: "*/api/mooncode/sessions*",
      requestStage: "Request",
    }],
  });
  return {
    fixture,
    records,
    async close() {
      session.off("Fetch.requestPaused", listener);
      await session.send("Fetch.disable");
      if (failure) throw failure;
    },
  };
}

async function proveSessionMenuTransient(
  session,
  viewport,
  index,
  sessionRecords,
) {
  const caseId = `session-menu-${viewport.width}x${viewport.height}`;
  const label = `${caseId} Code session actions`;
  const trace = [];
  const start = await beginKeyboardCase(
    session,
    viewport,
    `${baseUrl}/?locale=en-US&activity=code&workspace=book-research-alpha&` +
      `keyboard_case=${caseId}`,
    `!!document.querySelector('[data-testid="mooncode-rail"]')`,
    label,
  );
  try {
    await waitFor(
      session,
      `!!document.querySelector('[data-testid="mooncode-session-menu"]')`,
      `${label} deterministic session menu`,
      5000,
    );
  } catch (error) {
    const diagnostic = await session.evaluate(`(() => ({
      url: location.href,
      state: document.querySelector(
        '[data-testid="mooncode-sessions-state-panel"]'
      )?.dataset.state || "",
      railText: document.querySelector(
        '[data-testid="mooncode-rail"]'
      )?.textContent.trim().replace(/\\s+/g, " ").slice(0, 500) || "",
      menuCount: document.querySelectorAll(
        '[data-testid="mooncode-session-menu"]'
      ).length
    }))()`);
    throw new Error(
      `${error.message}; diagnostic=${JSON.stringify(diagnostic)}; ` +
        `requests=${JSON.stringify(sessionRecords)}`,
    );
  }
  trace.push({ operation: "Natural document focus", ...start.naturalFocus });
  const trigger = await tabToTestId(
    session,
    "mooncode-session-menu",
    trace,
    label,
  );
  assertUsableKeyboardFocus(trigger, `${label} trigger`);
  assert(!trigger.detailsOpen, `${label} began open`);
  const activationKey = index % 2 === 0 ? " " : "Enter";
  await dispatchKey(
    session,
    activationKey,
    activationKey === " " ? "Space" : "Enter",
  );
  await waitTwoAnimationFrames(session);
  const opened = await activeKeyboardFocus(session);
  trace.push({
    operation: activationKey === " " ? "Space" : "Enter",
    ...opened,
  });
  assertUsableKeyboardFocus(opened, `${label} open`);
  assert(
    opened.key === trigger.key && opened.detailsOpen,
    `${label} did not open while retaining its trigger`,
  );
  await dispatchKey(session, "Tab", "Tab");
  await waitTwoAnimationFrames(session);
  const rename = await activeKeyboardFocus(session);
  trace.push({ operation: "Tab to Rename", ...rename });
  assertUsableKeyboardFocus(rename, `${label} Rename`);
  assert(
    rename.testid === "mooncode-session-rename" &&
      rename.detailsSummaryTestid === "mooncode-session-menu",
    `${label} did not reach Rename first: ${JSON.stringify(rename)}`,
  );
  const screenshot = await captureDeskScreenshot(
    session,
    `desk-keyboard-transient-${caseId}`,
    viewport.width,
    viewport.height,
  );
  await dispatchKey(session, "Escape", "Escape");
  await waitTwoAnimationFrames(session);
  const restored = await activeKeyboardFocus(session);
  trace.push({ operation: "Escape", ...restored });
  assertUsableKeyboardFocus(restored, `${label} Escape restoration`);
  assert(
    restored.key === trigger.key && !restored.detailsOpen,
    `${label} did not restore its exact trigger: ` +
      `${JSON.stringify({ trigger, restored })}`,
  );
  const roundTrip = await assertKeyboardRoundTrip(
    session,
    trigger,
    trace,
    label,
  );
  return {
    caseId,
    kind: "session-action-menu",
    viewport,
    activationKey: activationKey === " " ? "Space" : "Enter",
    naturalFocus: start.naturalFocus,
    navigation: start.navigation,
    trigger,
    opened,
    rename,
    restored,
    ...roundTrip,
    screenshot,
    trace,
  };
}

async function proveCompactNavigationTransient(session, viewport, index) {
  const caseId = `compact-navigation-${viewport.width}x${viewport.height}`;
  const label = `${caseId} primary navigation`;
  const trace = [];
  const start = await beginKeyboardCase(
    session,
    viewport,
    `${baseUrl}/?locale=en-US&activity=home&workspace=book-research-alpha&` +
      `keyboard_case=${caseId}`,
    `!!document.querySelector('[data-testid="desk-library-storage-details"]')`,
    label,
  );
  trace.push({ operation: "Natural document focus", ...start.naturalFocus });
  const trigger = await tabToTestId(
    session,
    "primary-nav-summary",
    trace,
    label,
  );
  assertUsableKeyboardFocus(trigger, `${label} trigger`);
  const activationKey = index % 2 === 0 ? "Enter" : " ";
  await dispatchKey(
    session,
    activationKey,
    activationKey === " " ? "Space" : "Enter",
  );
  await waitTwoAnimationFrames(session);
  const opened = await activeKeyboardFocus(session);
  trace.push({
    operation: activationKey === " " ? "Space" : "Enter",
    ...opened,
  });
  assertUsableKeyboardFocus(opened, `${label} open`);
  assert(
    opened.key === trigger.key && opened.detailsOpen,
    `${label} did not open while retaining its trigger`,
  );
  const destination = await tabToTestId(
    session,
    "compact-mode-wiki",
    trace,
    label,
  );
  assertUsableKeyboardFocus(destination, `${label} Wiki destination`);
  assert(
    destination.detailsSummaryTestid === "primary-nav-summary" &&
      destination.detailsOpen,
    `${label} Wiki destination escaped the open navigation: ` +
      `${JSON.stringify(destination)}`,
  );
  const screenshot = await captureDeskScreenshot(
    session,
    `desk-keyboard-transient-${caseId}`,
    viewport.width,
    viewport.height,
  );
  await dispatchKey(session, "Escape", "Escape");
  await waitTwoAnimationFrames(session);
  const restored = await activeKeyboardFocus(session);
  trace.push({ operation: "Escape", ...restored });
  assertUsableKeyboardFocus(restored, `${label} Escape restoration`);
  assert(
    restored.key === trigger.key && !restored.detailsOpen,
    `${label} did not restore its exact visible compact trigger`,
  );
  const roundTrip = await assertKeyboardRoundTrip(
    session,
    trigger,
    trace,
    label,
  );
  return {
    caseId,
    kind: "compact-primary-navigation",
    viewport,
    activationKey: activationKey === " " ? "Space" : "Enter",
    naturalFocus: start.naturalFocus,
    navigation: start.navigation,
    trigger,
    opened,
    destination,
    restored,
    ...roundTrip,
    screenshot,
    trace,
  };
}

async function verifyKeyboardTransients() {
  const session = await connect(cdpPort);
  const cases = [];
  try {
    await session.send("Page.enable");
    await enablePageProblemCapture(session);
    await setEnglishLocale(session);

    for (const [index, viewport] of keyboardTransientViewports.entries()) {
      cases.push(await proveDisclosureTransient(session, {
        caseId: `home-storage-${viewport.width}x${viewport.height}`,
        surface: "home-storage-disclosure",
        viewport,
        url:
          `${baseUrl}/?locale=en-US&activity=home&workspace=book-research-alpha&` +
          `keyboard_case=home-storage-${viewport.width}x${viewport.height}`,
        readyExpression:
          `!!document.querySelector('[data-testid="desk-library-storage-details"]')`,
        owningTestid: "desk-library-storage-details",
        innerTestid: "desk-change-library-folder",
        activationKey: index % 2 === 0 ? " " : "Enter",
      }));
    }

    const capabilityCase = capabilityRenderedCases.find(
      item => item.id === "not-installed",
    );
    assert(capabilityCase, "Command 061 capability fixture is missing");
    const capability = await installCapabilityResponseSubstitution(
      session,
      capabilityCase,
    );
    try {
      for (const [index, viewport] of keyboardTransientViewports.entries()) {
        cases.push(await proveDisclosureTransient(session, {
          caseId: `code-setup-${viewport.width}x${viewport.height}`,
          surface: "code-setup-disclosure",
          viewport,
          url:
            `${baseUrl}/?locale=en-US&activity=home&workspace=book-research-alpha&` +
            `keyboard_case=code-setup-${viewport.width}x${viewport.height}`,
          readyExpression:
            `document.querySelector('[data-testid="moongate-summary"]')?.` +
            `dataset.state === "not-installed" && ` +
            `!!document.querySelector(` +
            `'[data-testid="code-assistance-technical-details"]')`,
          owningTestid: "code-assistance-technical-details",
          activationKey: index % 2 === 0 ? "Enter" : " ",
        }));
      }
    } finally {
      await capability.close();
    }

    for (const [index, viewport] of keyboardTransientViewports.entries()) {
      cases.push(await proveCommandPaletteTransient(session, viewport, index));
    }

    const sessionSubstitution =
      await installCommand061SessionSubstitution(session);
    try {
      for (const [index, viewport] of keyboardTransientViewports.entries()) {
        cases.push(await proveSessionMenuTransient(
          session,
          viewport,
          index,
          sessionSubstitution.records,
        ));
      }
      assert(
        sessionSubstitution.records.some(record =>
          record.pathname === "/api/mooncode/sessions" &&
          record.scope === "active"
        ),
        `Command 061 session substitution did not serve the active listing: ` +
          `${JSON.stringify(sessionSubstitution.records)}`,
      );
    } finally {
      await sessionSubstitution.close();
    }

    for (const [index, viewport] of keyboardTransientViewports
      .filter(item => item.navigation === "compact")
      .entries()) {
      cases.push(
        await proveCompactNavigationTransient(session, viewport, index),
      );
    }

    const expectedCounts = {
      "home-storage-disclosure": 4,
      "code-setup-disclosure": 4,
      "command-palette": 4,
      "session-action-menu": 4,
      "compact-primary-navigation": 2,
    };
    const actualCounts = Object.fromEntries(
      Object.keys(expectedCounts).map(kind => [
        kind,
        cases.filter(item => item.kind === kind).length,
      ]),
    );
    assert(
      cases.length === 18 &&
        Object.entries(expectedCounts).every(
          ([kind, count]) => actualCounts[kind] === count,
        ),
      `Command 061 proof has the wrong matrix: ` +
        `${JSON.stringify({ expectedCounts, actualCounts, count: cases.length })}`,
    );
    const unique = new Set(cases.map(item => item.caseId));
    assert(
      unique.size === cases.length,
      `Command 061 proof has duplicate cases: ${JSON.stringify([...unique])}`,
    );
    assert(
      cases.every(item =>
        item.screenshot &&
        fs.existsSync(item.screenshot) &&
        item.restored.key === item.trigger.key &&
        item.returned.key === item.trigger.key
      ),
      "Command 061 proof has incomplete screenshot or focus evidence",
    );
    session.assertNoPageProblems("Command 061 keyboard transient matrix");

    const proofPath = path.join(
      fixtureRoot,
      "desk-page-keyboard-transient-proof.v1.json",
    );
    fs.writeFileSync(proofPath, JSON.stringify({
      kind: "moondesk-page-keyboard-transient-proof.v1",
      caseCount: cases.length,
      expectedCounts,
      actualCounts,
      viewports: keyboardTransientViewports,
      screenshotCount: cases.length,
      cases,
    }, null, 2) + "\n");
    console.log(`Page keyboard transient proof: ${proofPath}`);
  } finally {
    session.close();
  }
}

const screenReaderViewports = [
  { id: "desktop", width: 1440, height: 900, navigation: "desktop" },
  { id: "compact", width: 390, height: 844, navigation: "compact" },
];

const screenReaderDestinations = [
  ...sharedShellDestinations.map(destination => ({
    ...destination,
    source: "primary-navigation",
  })),
  {
    label: "Requests",
    activity: "requests",
    source: "command-palette",
    command: "Open Requests",
  },
  {
    label: "Runs",
    activity: "runs",
    source: "command-palette",
    command: "Open Runs",
  },
  {
    label: "Review",
    activity: "review",
    source: "command-palette",
    command: "Open Review",
  },
  {
    label: "Publish",
    activity: "publish",
    source: "command-palette",
    command: "Open Publish",
  },
];

const screenReaderActionableRoles = new Set([
  "button",
  "checkbox",
  "combobox",
  "link",
  "menuitem",
  "option",
  "radio",
  "slider",
  "spinbutton",
  "switch",
  "tab",
  "textbox",
  "treeitem",
]);

const screenReaderLandmarkRoles = new Set([
  "banner",
  "complementary",
  "contentinfo",
  "form",
  "main",
  "navigation",
  "region",
  "search",
]);

function screenReaderAxPropertyValue(value) {
  if (!value || typeof value !== "object") return value ?? null;
  return value.value ?? value.description ?? null;
}

function screenReaderAxNodes(tree) {
  return (tree.nodes ?? []).map(node => ({
    nodeId: node.nodeId,
    parentId: node.parentId ?? "",
    childIds: node.childIds ?? [],
    backendDOMNodeId: node.backendDOMNodeId ?? 0,
    ignored: Boolean(node.ignored),
    role: screenReaderAxPropertyValue(node.role) ?? "",
    name: screenReaderAxPropertyValue(node.name) ?? "",
    description: screenReaderAxPropertyValue(node.description) ?? "",
    properties: Object.fromEntries(
      (node.properties ?? []).map(property => [
        property.name,
        screenReaderAxPropertyValue(property.value),
      ]),
    ),
  }));
}

function screenReaderAxSubtree(nodes, rootNodeId) {
  const byId = new Map(nodes.map(node => [node.nodeId, node]));
  const result = [];
  const pending = [rootNodeId];
  const seen = new Set();
  while (pending.length > 0) {
    const nodeId = pending.shift();
    if (seen.has(nodeId)) continue;
    seen.add(nodeId);
    const node = byId.get(nodeId);
    if (!node) continue;
    result.push(node);
    pending.push(...node.childIds);
  }
  return result;
}

function screenReaderAxText(nodes) {
  return nodes
    .filter(node =>
      !node.ignored &&
      (node.role === "StaticText" || node.role === "InlineTextBox") &&
      node.name
    )
    .map(node => node.name)
    .filter((value, index, values) => index === 0 || value !== values[index - 1])
    .join(" ")
    .trim()
    .replace(/\s+/g, " ");
}

async function screenReaderAxSubtreeForSelector(session, selector) {
  const evaluated = await session.send("Runtime.evaluate", {
    expression: `document.querySelector(${JSON.stringify(selector)})`,
    returnByValue: false,
  });
  const objectId = evaluated.result?.objectId;
  assert(objectId, `Screen-reader selector is missing: ${selector}`);
  const described = await session.send("DOM.describeNode", { objectId });
  const backendNodeId = described.node?.backendNodeId;
  assert(
    backendNodeId,
    `Screen-reader selector has no backend node: ${selector}`,
  );
  const nodes = screenReaderAxNodes(
    await session.send("Accessibility.getFullAXTree", {}),
  );
  const root = nodes.find(node =>
    !node.ignored && node.backendDOMNodeId === backendNodeId
  );
  assert(
    root,
    `Full accessibility tree omitted ${selector}: ` +
      `${JSON.stringify(nodes.slice(0, 40))}`,
  );
  const subtree = screenReaderAxSubtree(nodes, root.nodeId);
  return {
    selector,
    backendNodeId,
    root,
    text: screenReaderAxText(subtree),
    nodes: subtree,
  };
}

async function screenReaderDomEvidenceForAxNodes(session, nodes) {
  const evidence = [];
  for (const node of nodes) {
    if (!node.backendDOMNodeId) {
      evidence.push({ ...node, dom: null });
      continue;
    }
    const resolved = await session.send("DOM.resolveNode", {
      backendNodeId: node.backendDOMNodeId,
    });
    const objectId = resolved.object?.objectId;
    if (!objectId) {
      evidence.push({ ...node, dom: null });
      continue;
    }
    const described = await session.send("Runtime.callFunctionOn", {
      objectId,
      functionDeclaration: `function () {
        return {
          tag: this.tagName?.toLowerCase() || "",
          testid: this.dataset?.testid || "",
          className: typeof this.className === "string" ? this.className : "",
          outerHTML: this.outerHTML?.slice(0, 800) || ""
        };
      }`,
      returnByValue: true,
    });
    evidence.push({
      ...node,
      dom: described.result?.value ?? null,
    });
  }
  return evidence;
}

async function activateScreenReaderPaletteCommand(
  session,
  command,
  label,
) {
  await dispatchKey(session, "k", "KeyK", { meta: true });
  await waitFor(
    session,
    `document.activeElement?.dataset.testid === "command-palette-input"`,
    `${label} palette input`,
  );
  await dispatchKey(session, "a", "KeyA", {
    meta: true,
    commands: ["selectAll"],
  });
  await dispatchKey(session, "Backspace", "Backspace");
  await waitFor(
    session,
    `document.querySelector('[data-testid="command-palette-input"]')?.value === ""`,
    `${label} cleared palette query`,
  );
  await session.send("Input.insertText", { text: command });
  await waitFor(
    session,
    `document.querySelector('[data-testid="command-palette-input"]')?.value === ` +
      JSON.stringify(command),
    `${label} palette query`,
  );
  await dispatchKey(session, "Tab", "Tab");
  await waitTwoAnimationFrames(session);
  await dispatchKey(session, "Tab", "Tab");
  await waitTwoAnimationFrames(session);
  const focused = await activeKeyboardFocus(session);
  assert(
    focused.dialogTestid === "command-palette-panel" &&
      focused.text.includes(command),
    `${label} did not reach ${command} by keyboard: ${JSON.stringify(focused)}`,
  );
  await dispatchKey(session, "Enter", "Enter");
  return focused;
}

async function openScreenReaderDestination(
  session,
  viewport,
  destination,
  index,
) {
  const trace = [];
  if (destination.source === "primary-navigation") {
    await activateDestinationByKeyboard(
      session,
      viewport,
      destination,
      trace,
      index,
    );
  } else {
    await navigateToAccessibilityHome(session, viewport);
    const focused = await activateScreenReaderPaletteCommand(
      session,
      destination.command,
      `${destination.label} destination`,
    );
    trace.push({
      operation: `Keyboard palette command ${destination.command}`,
      ...focused,
    });
    await waitFor(
      session,
      `location.search.includes('activity=${destination.activity}') && ` +
        `document.querySelector('#moondesk-main-content')?.getAttribute(` +
          `'aria-label') === ${JSON.stringify(`${destination.label} workspace`)} && ` +
        `document.querySelector('[data-testid="destination-announcement"]')?.` +
          `textContent.includes(${JSON.stringify(`${destination.label} destination.`)})`,
      `${destination.label} route and announcement`,
    );
    await waitTwoAnimationFrames(session);
  }
  return trace;
}

async function screenReaderRouteDomState(session) {
  return session.evaluate(`(() => {
    const visible = element => {
      if (!(element instanceof HTMLElement)) return false;
      const rect = element.getBoundingClientRect();
      const style = getComputedStyle(element);
      return rect.width > 0 && rect.height > 0 &&
        style.display !== 'none' && style.visibility !== 'hidden' &&
        element.getAttribute('aria-hidden') !== 'true';
    };
    const main = document.querySelector('#moondesk-main-content');
    const primaryNavigations = [...document.querySelectorAll(
      '[role="navigation"][aria-label="Primary destinations"]'
    )].filter(visible);
    const selected = primaryNavigations.flatMap(navigation =>
      [...navigation.querySelectorAll('button')].filter(button =>
        button.getAttribute('aria-current') === 'page' ||
        button.getAttribute('aria-pressed') === 'true' ||
        button.classList.contains('active')
      ).map(button => ({
        testid: button.dataset.testid || '',
        name: button.getAttribute('aria-label') || button.textContent.trim(),
        current: button.getAttribute('aria-current') || '',
        pressed: button.getAttribute('aria-pressed') || '',
        active: button.classList.contains('active')
      }))
    );
    const headings = [...document.querySelectorAll('h1,h2,h3,h4,h5,h6')]
      .filter(visible)
      .map(heading => ({
        level: Number(heading.tagName.slice(1)),
        text: heading.textContent.trim().replace(/\\s+/g, ' '),
        insideMain: main?.contains(heading) === true
      }));
    const announcement = document.querySelector(
      '[data-testid="destination-announcement"]'
    );
    return {
      viewportWidth: document.documentElement.clientWidth,
      documentWidth: document.documentElement.scrollWidth,
      horizontalOverflow:
        document.documentElement.scrollWidth >
          document.documentElement.clientWidth + 1,
      scrollX: window.scrollX,
      scrollY: window.scrollY,
      mainCount: document.querySelectorAll('main').length,
      mainIdCount: document.querySelectorAll('#moondesk-main-content').length,
      mainName: main?.getAttribute('aria-label') || '',
      primaryNavigationCount: primaryNavigations.length,
      primaryNavigationName:
        primaryNavigations[0]?.getAttribute('aria-label') || '',
      selected,
      headings,
      announcement: announcement ? {
        text: announcement.textContent.trim().replace(/\\s+/g, ' '),
        role: announcement.getAttribute('role') || '',
        live: announcement.getAttribute('aria-live') || '',
        atomic: announcement.getAttribute('aria-atomic') || ''
      } : null
    };
  })()`);
}

async function proveScreenReaderRouteCase(
  session,
  viewport,
  destination,
  index,
) {
  const label =
    `screen-reader ${destination.label} ${viewport.width}x${viewport.height}`;
  const trace = await openScreenReaderDestination(
    session,
    viewport,
    destination,
    index,
  );
  const dom = await screenReaderRouteDomState(session);
  const axNodes = screenReaderAxNodes(
    await session.send("Accessibility.getFullAXTree", {}),
  ).filter(node => !node.ignored);
  const mainNodes = axNodes.filter(node =>
    node.role === "main" && node.name === `${destination.label} workspace`
  );
  const primaryNavigationNodes = axNodes.filter(node =>
    node.role === "navigation" && node.name === "Primary destinations"
  );
  const unnamedActionNodes = axNodes.filter(node =>
    screenReaderActionableRoles.has(node.role) && node.name.trim() === ""
  );
  const decorativeNameNodes = axNodes.filter(node =>
    [">", "X", "⌄", "⌃"].includes(node.name.trim())
  );
  const unnamedActions = await screenReaderDomEvidenceForAxNodes(
    session,
    unnamedActionNodes,
  );
  const decorativeNames = await screenReaderDomEvidenceForAxNodes(
    session,
    decorativeNameNodes,
  );
  const landmarks = axNodes
    .filter(node => screenReaderLandmarkRoles.has(node.role))
    .map(node => ({ role: node.role, name: node.name.trim() }));
  const landmarkCounts = new Map();
  for (const landmark of landmarks) {
    const key = `${landmark.role}\u0000${landmark.name}`;
    landmarkCounts.set(key, (landmarkCounts.get(key) ?? 0) + 1);
  }
  const duplicateLandmarks = [...landmarkCounts.entries()]
    .filter(([, count]) => count > 1)
    .map(([key, count]) => {
      const [role, name] = key.split("\u0000");
      return { role, name, count };
    });
  const headingSkips = dom.headings.slice(1).filter((heading, headingIndex) =>
    heading.level > dom.headings[headingIndex].level + 1
  );
  const expectedPrimarySelection = 1;
  assert(
    dom.mainCount === 1 &&
      dom.mainIdCount === 1 &&
      dom.mainName === `${destination.label} workspace` &&
      mainNodes.length === 1,
    `${label} main landmark mismatch: ` +
      `${JSON.stringify({ dom, mainNodes })}`,
  );
  assert(
    dom.primaryNavigationCount === 1 &&
      dom.primaryNavigationName === "Primary destinations" &&
      primaryNavigationNodes.length === 1,
    `${label} primary navigation mismatch: ` +
      `${JSON.stringify({ dom, primaryNavigationNodes })}`,
  );
  assert(
    !dom.horizontalOverflow &&
      dom.documentWidth <= dom.viewportWidth + 1 &&
      dom.scrollX === 0 &&
      dom.scrollY === 0,
    `${label} has horizontal overflow or a shifted viewport: ` +
      `${JSON.stringify(dom)}`,
  );
  assert(
    dom.selected.length === expectedPrimarySelection &&
      dom.selected.every(item =>
        item.current === "page" &&
        item.pressed === "true" &&
        item.active
      ),
    `${label} selected/current mismatch: ${JSON.stringify(dom.selected)}`,
  );
  assert(
    dom.headings.length > 0 &&
      dom.headings[0].level === 1 &&
      headingSkips.length === 0,
    `${label} heading order mismatch: ${JSON.stringify(dom.headings)}`,
  );
  assert(
    unnamedActions.length === 0,
    `${label} exposes unnamed actions: ${JSON.stringify(unnamedActions)}`,
  );
  assert(
    decorativeNames.length === 0,
    `${label} exposes decorative text: ${JSON.stringify(decorativeNames)}`,
  );
  assert(
    duplicateLandmarks.length === 0,
    `${label} duplicates role/name landmarks: ` +
      `${JSON.stringify(duplicateLandmarks)}`,
  );
  const announcement = await screenReaderAxSubtreeForSelector(
    session,
    '[data-testid="destination-announcement"]',
  );
  const expectedAnnouncement =
    `${destination.label} destination. Selected book: Research Alpha.`;
  assert(
    dom.announcement?.text === expectedAnnouncement &&
      dom.announcement.role === "status" &&
      dom.announcement.live === "polite" &&
      dom.announcement.atomic === "true" &&
      announcement.root.role === "status" &&
      announcement.root.properties.live === "polite" &&
      announcement.root.properties.atomic === true &&
      announcement.text === expectedAnnouncement,
    `${label} announcement mismatch: ` +
      `${JSON.stringify({ dom: dom.announcement, ax: announcement })}`,
  );
  let screenshot = "";
  if (["Desk", "Flow"].includes(destination.label)) {
    screenshot = await captureDeskScreenshot(
      session,
      `desk-screen-reader-${destination.activity}-${viewport.width}x${viewport.height}`,
      viewport.width,
      viewport.height,
    );
  }
  return {
    caseId:
      `route-${destination.activity}-${viewport.width}x${viewport.height}`,
    kind: "route-landmark",
    viewport,
    destination: destination.label,
    destinationSource: destination.source,
    expectedPrimarySelection,
    dom,
    accessibility: {
      main: mainNodes,
      primaryNavigation: primaryNavigationNodes,
      landmarks,
      announcement,
      unnamedActions,
      decorativeNames,
      duplicateLandmarks,
    },
    headingSkips,
    trace,
    screenshot,
  };
}

async function proveScreenReaderPaletteCase(session, viewport) {
  const label =
    `screen-reader palette ${viewport.width}x${viewport.height}`;
  const trace = [];
  const start = await beginKeyboardCase(
    session,
    viewport,
    `${baseUrl}/?locale=en-US&activity=home&workspace=book-research-alpha&` +
      `screen_reader_case=palette-${viewport.width}x${viewport.height}`,
    `!!document.querySelector('[data-testid="desk-library-storage-details"]')`,
    label,
  );
  trace.push({ operation: "Natural document focus", ...start.naturalFocus });
  const trigger = await tabToTestId(
    session,
    "command-palette-toggle",
    trace,
    label,
    { maxSteps: 14 },
  );
  assertUsableKeyboardFocus(trigger, `${label} trigger`);
  const triggerBefore = await session.evaluate(`(() => {
    const trigger = document.querySelector(
      '[data-testid="command-palette-toggle"]'
    );
    return {
      visible: trigger instanceof HTMLElement &&
        trigger.getBoundingClientRect().width > 0 &&
        trigger.getBoundingClientRect().height > 0,
      haspopup: trigger?.getAttribute('aria-haspopup') || '',
      expanded: trigger?.getAttribute('aria-expanded') || '',
      keyshortcuts: trigger?.getAttribute('aria-keyshortcuts') || ''
    };
  })()`);
  assert(
    triggerBefore.visible &&
      triggerBefore.haspopup === "dialog" &&
      triggerBefore.expanded === "false" &&
      triggerBefore.keyshortcuts.includes("Meta+K") &&
      triggerBefore.keyshortcuts.includes("Control+K"),
    `${label} closed trigger semantics mismatch: ` +
      `${JSON.stringify(triggerBefore)}`,
  );
  await activateKeyboardFocus(
    session,
    "command-palette-toggle",
    "Enter",
    trace,
    label,
  );
  await waitFor(
    session,
    `document.activeElement?.dataset.testid === "command-palette-input"`,
    `${label} input autofocus`,
  );
  const opened = await activeKeyboardFocus(session);
  trace.push({ operation: "Palette input autofocus", ...opened });
  const triggerOpen = await session.evaluate(`(() => {
    const trigger = document.querySelector(
      '[data-testid="command-palette-toggle"]'
    );
    return {
      expanded: trigger?.getAttribute('aria-expanded') || '',
      panelCount:
        document.querySelectorAll('[data-testid="command-palette-panel"]').length,
      focusInside:
        document.querySelector('[data-testid="command-palette-panel"]')
          ?.contains(document.activeElement) === true,
      outsideFocusableCount: [...document.querySelectorAll(
        'a[href],button,input,textarea,select,[tabindex]:not([tabindex="-1"])'
      )].filter(element => {
        if (!(element instanceof HTMLElement)) return false;
        const panel = document.querySelector(
          '[data-testid="command-palette-panel"]'
        );
        const rect = element.getBoundingClientRect();
        const style = getComputedStyle(element);
        return !panel?.contains(element) &&
          rect.width > 0 && rect.height > 0 &&
          style.display !== 'none' && style.visibility !== 'hidden';
      }).length
    };
  })()`);
  const panel = await screenReaderAxSubtreeForSelector(
    session,
    '[data-testid="command-palette-panel"]',
  );
  const input = await accessibilityNodeForSelector(
    session,
    '[data-testid="command-palette-input"]',
  );
  const close = await accessibilityNodeForSelector(
    session,
    '[data-testid="command-palette-close"]',
  );
  const exposedPaletteDecoration = panel.nodes.filter(node =>
    !node.ignored &&
    (
      [">", "X"].includes(node.name.trim()) ||
      node.name.trim().startsWith("> ")
    )
  );
  assert(
    triggerOpen.expanded === "true" &&
      triggerOpen.panelCount === 1 &&
      triggerOpen.focusInside &&
      panel.root.role === "dialog" &&
      panel.root.name === "Commands" &&
      (panel.root.properties.modal === true ||
        panel.root.properties.modal === "true") &&
      input.role === "textbox" &&
      input.name === "Search commands" &&
      close.role === "button" &&
      close.name === "Close command palette" &&
      panel.nodes.some(node =>
        node.nodeId === panel.root.nodeId
      ) &&
      panel.nodes.some(node =>
        node.role === "textbox" && node.name === "Search commands"
      ) &&
      panel.nodes.some(node =>
        node.role === "button" && node.name === "Close command palette"
      ) &&
      exposedPaletteDecoration.length === 0,
    `${label} open dialog semantics mismatch: ` +
      `${JSON.stringify({
        triggerOpen,
        panel,
        input,
        close,
        exposedPaletteDecoration,
      })}`,
  );
  const screenshot = await captureDeskScreenshot(
    session,
    `desk-screen-reader-palette-${viewport.width}x${viewport.height}`,
    viewport.width,
    viewport.height,
  );
  await dispatchKey(session, "Escape", "Escape");
  await waitFor(
    session,
    `!document.querySelector('[data-testid="command-palette-panel"]')`,
    `${label} Escape close`,
  );
  await waitTwoAnimationFrames(session);
  const restored = await activeKeyboardFocus(session);
  trace.push({ operation: "Escape", ...restored });
  const triggerAfter = await session.evaluate(
    `document.querySelector('[data-testid="command-palette-toggle"]')` +
      `?.getAttribute('aria-expanded') || ''`,
  );
  assert(
    restored.key === trigger.key &&
      restored.testid === "command-palette-toggle" &&
      triggerAfter === "false",
    `${label} did not restore the exact trigger: ` +
      `${JSON.stringify({ trigger, restored, triggerAfter })}`,
  );
  return {
    caseId: `palette-${viewport.width}x${viewport.height}`,
    kind: "command-palette",
    viewport,
    triggerBefore,
    triggerOpen,
    triggerAfter,
    opened,
    restored,
    accessibility: { panel, input, close },
    screenshot,
    trace,
  };
}

async function installScreenReaderLiveTrace(session, key, selector) {
  const installed = await session.evaluate(`(() => {
    globalThis.__moondeskScreenReaderTraces ||= {};
    const key = ${JSON.stringify(key)};
    globalThis.__moondeskScreenReaderTraces[key]?.observer?.disconnect();
    const selector = ${JSON.stringify(selector)};
    const normalize = value => String(value || '').trim().replace(/\\s+/g, ' ');
    const text = element => {
      if (!(element instanceof HTMLElement)) return '';
      const childText = [...element.children]
        .map(child => normalize(child.textContent))
        .filter(Boolean);
      return normalize(
        childText.length > 0 ? childText.join(' ') : element.textContent
      );
    };
    const state = element => ({
      testid: element?.dataset.testid || '',
      text: text(element),
      role: element?.getAttribute('role') || '',
      live: element?.getAttribute('aria-live') || '',
      atomic: element?.getAttribute('aria-atomic') || ''
    });
    const initial = state(document.querySelector(selector));
    const trace = {
      selector,
      baseline: initial,
      lastText: initial.text,
      rawTargetMutationBatches: 0,
      entries: []
    };
    const touchesTarget = mutation => {
      const target = mutation.target instanceof Element
        ? mutation.target
        : mutation.target.parentElement;
      if (target?.matches(selector) || target?.closest(selector)) return true;
      return [...mutation.addedNodes, ...mutation.removedNodes].some(node => {
        if (!(node instanceof Element)) return node.parentElement?.closest(selector);
        return node.matches(selector) || node.querySelector(selector);
      });
    };
    trace.observer = new MutationObserver(mutations => {
      if (!mutations.some(touchesTarget)) return;
      trace.rawTargetMutationBatches += 1;
      const next = state(document.querySelector(selector));
      if (!next.text || next.text === trace.lastText) return;
      trace.lastText = next.text;
      trace.entries.push({
        ...next,
        ordinal: trace.entries.length + 1,
        timestamp: performance.now()
      });
    });
    trace.observer.observe(document.documentElement, {
      childList: true,
      characterData: true,
      subtree: true
    });
    globalThis.__moondeskScreenReaderTraces[key] = trace;
    return { baseline: trace.baseline };
  })()`);
  assert(installed, `Could not install screen-reader live trace ${key}`);
  return installed;
}

async function stopScreenReaderLiveTrace(session, key) {
  return session.evaluate(`(() => {
    const trace = globalThis.__moondeskScreenReaderTraces?.[
      ${JSON.stringify(key)}
    ];
    if (!trace) return null;
    trace.observer.disconnect();
    return {
      selector: trace.selector,
      baseline: trace.baseline,
      rawTargetMutationBatches: trace.rawTargetMutationBatches,
      entries: trace.entries
    };
  })()`);
}

async function proveDestinationAnnouncementSequence(session) {
  const viewport = screenReaderViewports[0];
  await navigateToAccessibilityHome(session, viewport);
  const traceKey = "screen-reader-destination-sequence";
  await installScreenReaderLiveTrace(
    session,
    traceKey,
    '[data-testid="destination-announcement"]',
  );
  const expectedLabels = ["Wiki", "Code", "Flow", "Packs"];
  for (let index = 0; index < expectedLabels.length; index += 1) {
    const destination = sharedShellDestinations[index + 1];
    await dispatchKey(
      session,
      String(index + 2),
      `Digit${index + 2}`,
      { meta: true },
    );
    await waitFor(
      session,
      `document.querySelector('#moondesk-main-content')?.getAttribute(` +
        `'aria-label') === ${JSON.stringify(`${destination.label} workspace`)}`,
      `${destination.label} destination sequence`,
    );
    await waitTwoAnimationFrames(session);
  }
  const nestedWikiDestinations = screenReaderDestinations.filter(
    destination => destination.source === "command-palette",
  );
  for (const destination of nestedWikiDestinations) {
    await activateScreenReaderPaletteCommand(
      session,
      destination.command,
      `${destination.label} destination sequence`,
    );
    await waitFor(
      session,
      `document.querySelector('#moondesk-main-content')?.getAttribute(` +
        `'aria-label') === ${JSON.stringify(`${destination.label} workspace`)}`,
      `${destination.label} destination sequence`,
    );
    await waitTwoAnimationFrames(session);
  }
  await dispatchKey(session, "1", "Digit1", { meta: true });
  await waitFor(
    session,
    `document.querySelector('#moondesk-main-content')?.getAttribute(` +
      `'aria-label') === "Desk workspace"`,
    "Desk destination sequence",
  );
  await waitTwoAnimationFrames(session);
  const beforeUnrelated = await session.evaluate(`(() => {
    const trace = globalThis.__moondeskScreenReaderTraces?.[
      "screen-reader-destination-sequence"
    ];
    return {
      entryCount: trace?.entries.length || 0,
      rawTargetMutationBatches: trace?.rawTargetMutationBatches || 0
    };
  })()`);
  const refreshFocused = await session.evaluate(`(() => {
    const refresh = document.querySelector('[data-testid="desk-refresh"]');
    if (!(refresh instanceof HTMLElement)) return false;
    refresh.focus();
    return document.activeElement === refresh;
  })()`);
  assert(refreshFocused, "Destination sequence could not focus Home Refresh");
  await dispatchKey(session, "Enter", "Enter");
  await waitTwoAnimationFrames(session);
  await sleep(150);
  const result = await stopScreenReaderLiveTrace(session, traceKey);
  const expectedAnnouncements = [
    ...expectedLabels,
    ...nestedWikiDestinations.map(destination => destination.label),
    "Desk",
  ].map(label =>
    `${label} destination. Selected book: Research Alpha.`
  );
  assert(
    result.entries.length === expectedAnnouncements.length &&
      result.entries.every((entry, index) =>
        entry.text === expectedAnnouncements[index] &&
        entry.role === "status" &&
        entry.live === "polite" &&
        entry.atomic === "true"
      ),
    `Destination announcement order/dedup mismatch: ` +
      `${JSON.stringify({ expectedAnnouncements, result })}`,
  );
  assert(
    result.entries.length === beforeUnrelated.entryCount &&
      result.rawTargetMutationBatches ===
        beforeUnrelated.rawTargetMutationBatches,
    `Unrelated Home Refresh mutated the destination announcement: ` +
      `${JSON.stringify({ beforeUnrelated, result })}`,
  );
  assert(
    result.entries.every(entry =>
      !/(technical|daemon|service|moonclaw|http|internal)/i.test(entry.text)
    ),
    `Destination announcement exposed internal detail: ` +
      `${JSON.stringify(result.entries)}`,
  );
  const screenshot = await captureDeskScreenshot(
    session,
    "desk-screen-reader-destination-sequence-1440x900",
    viewport.width,
    viewport.height,
  );
  return {
    caseId: "live-destination-order",
    kind: "live-region-sequence",
    viewport,
    expectedAnnouncements,
    unrelatedAction: "Home Refresh via Enter",
    beforeUnrelated,
    result,
    screenshot,
  };
}

function installScreenReaderSearchSequence(session) {
  const requests = [];
  let failure = null;
  const listener = params => {
    const url = new URL(params.request.url);
    if (url.pathname !== "/api/search") return;
    requests.push(params);
  };
  session.on("Fetch.requestPaused", listener);
  const ready = session.send("Fetch.enable", {
    patterns: [{
      urlPattern: "*/api/search*",
      requestStage: "Request",
    }],
  });
  const waitForRequest = async index => {
    await ready;
    const started = Date.now();
    while (requests.length <= index && Date.now() - started < 15_000) {
      await sleep(20);
    }
    assert(
      requests[index],
      `Pages search request ${index + 1} was not intercepted`,
    );
    if (failure) throw failure;
    return requests[index];
  };
  return {
    requests,
    async fail(index) {
      const request = await waitForRequest(index);
      await session.send("Fetch.failRequest", {
        requestId: request.requestId,
        errorReason: "Failed",
      });
      return request;
    },
    async fulfillZero(index) {
      const request = await waitForRequest(index);
      const url = new URL(request.request.url);
      const body = {
        contract: "pages-search.v1",
        ok: true,
        status: "ready",
        message: "Search completed",
        query: url.searchParams.get("query") ?? "",
        workspace_id: url.searchParams.get("workspace") ?? "",
        hits: [],
      };
      await session.send("Fetch.fulfillRequest", {
        requestId: request.requestId,
        responseCode: 200,
        responseHeaders: [
          { name: "Content-Type", value: "application/json; charset=utf-8" },
          { name: "Cache-Control", value: "no-store" },
        ],
        body: Buffer.from(JSON.stringify(body)).toString("base64"),
      });
      return { request, body };
    },
    async close() {
      session.off("Fetch.requestPaused", listener);
      await session.send("Fetch.disable");
      if (failure) throw failure;
    },
  };
}

async function provePagesSearchAnnouncementSequence(session) {
  const viewport = screenReaderViewports[0];
  await setViewport(session, viewport.width, viewport.height);
  await session.send("Page.navigate", {
    url:
      `${baseUrl}/?locale=en-US&activity=pages&` +
      `workspace=book-research-alpha&screen_reader_case=search-sequence`,
  });
  await waitFor(
    session,
    `document.readyState === "complete" && ` +
      `document.querySelector('#moondesk-main-content')?.` +
        `getAttribute('aria-label') === "Wiki workspace" && ` +
      `document.activeElement === document.body`,
    "Pages search announcement baseline",
  );
  await activateScreenReaderPaletteCommand(
    session,
    "Search Books",
    "Pages search announcement sequence",
  );
  await waitFor(
    session,
    `!!document.querySelector('.activity-pane input.line-input')`,
    "Pages search pane",
  );
  const focused = await session.evaluate(`(() => {
    const input = document.querySelector('.activity-pane input.line-input');
    if (!(input instanceof HTMLInputElement)) return false;
    input.focus();
    return document.activeElement === input;
  })()`);
  assert(focused, "Pages search announcement input could not receive focus");
  const query = "command-062-deterministic-zero";
  await session.send("Input.insertText", { text: query });
  await waitFor(
    session,
    `document.querySelector('.activity-pane input.line-input')?.value === ` +
      JSON.stringify(query),
    "Pages deterministic search query",
  );
  const searchResponses = installScreenReaderSearchSequence(session);
  const stateTraceKey = "screen-reader-pages-search";
  const destinationTraceKey = "screen-reader-pages-destination";
  await installScreenReaderLiveTrace(
    session,
    stateTraceKey,
    '[data-testid="pages-search-state-announcement"]',
  );
  await installScreenReaderLiveTrace(
    session,
    destinationTraceKey,
    '[data-testid="destination-announcement"]',
  );
  const focusAction = await session.evaluate(`(() => {
    const action = document.querySelector(
      '[data-testid="pages-search-state-action"]'
    );
    if (!(action instanceof HTMLElement)) return false;
    action.focus();
    return document.activeElement === action;
  })()`);
  assert(focusAction, "Pages Search action could not receive focus");
  await dispatchKey(session, "Enter", "Enter");
  const firstRequest = await searchResponses.fail(0);
  await waitFor(
    session,
    `document.querySelector('[data-testid="pages-search-state"]')?.` +
      `dataset.state === "recoverable-error"`,
    "Pages recoverable search state",
  );
  const focusRetry = await session.evaluate(`(() => {
    const action = document.querySelector(
      '[data-testid="pages-search-state-action"]'
    );
    if (!(action instanceof HTMLElement)) return false;
    action.focus();
    return document.activeElement === action;
  })()`);
  assert(focusRetry, "Pages Retry action could not receive focus");
  await dispatchKey(session, "Enter", "Enter");
  const secondResponse = await searchResponses.fulfillZero(1);
  await waitFor(
    session,
    `document.querySelector('[data-testid="pages-search-state"]')?.` +
      `dataset.state === "legitimate-zero"`,
    "Pages legitimate-zero search state",
  );
  await waitTwoAnimationFrames(session);
  const stateResult = await stopScreenReaderLiveTrace(session, stateTraceKey);
  const destinationResult = await stopScreenReaderLiveTrace(
    session,
    destinationTraceKey,
  );
  await searchResponses.close();
  const expectedStates = [
    "loading",
    "recoverable-error",
    "loading",
    "legitimate-zero",
  ];
  const entries = stateResult.entries;
  assert(
    entries.length === 4 &&
      entries.every(entry =>
        entry.role === "status" &&
        entry.live === "polite" &&
        entry.atomic === "true" &&
        !/(technical|daemon|service|moonclaw|http|internal|err_failed)/i
          .test(entry.text)
      ) &&
      entries[0].text === entries[2].text &&
      entries[0].text !== entries[1].text &&
      entries[1].text !== entries[3].text,
    `Pages live announcement order/dedup mismatch: ` +
      `${JSON.stringify(stateResult)}`,
  );
  assert(
    destinationResult.entries.length === 0,
    `Pages search also mutated the destination live region: ` +
      `${JSON.stringify(destinationResult)}`,
  );
  const stateTransitions = await session.evaluate(`(() => {
    const panel = document.querySelector('[data-testid="pages-search-state"]');
    const announcement = document.querySelector(
      '[data-testid="pages-search-state-announcement"]'
    );
    return {
      finalState: panel?.dataset.state || '',
      finalAnnouncement:
        announcement?.textContent.trim().replace(/\\s+/g, ' ') || '',
      technicalOpen:
        panel?.querySelector('details.technical-details')?.open === true
    };
  })()`);
  assert(
    stateTransitions.finalState === "legitimate-zero" &&
      !stateTransitions.technicalOpen,
    `Pages final search evidence mismatch: ${JSON.stringify(stateTransitions)}`,
  );
  const expectedRequestProblem = session.pageProblems.filter(problem =>
    problem.kind === "log.error" &&
    problem.text.includes("net::ERR_FAILED") &&
    problem.url === firstRequest.request.url
  );
  assert(
    expectedRequestProblem.length === 1,
    `Pages deterministic failure produced unexpected diagnostics: ` +
      `${JSON.stringify(session.pageProblems)}`,
  );
  session.pageProblems = session.pageProblems.filter(
    problem => !expectedRequestProblem.includes(problem),
  );
  const screenshot = await captureDeskScreenshot(
    session,
    "desk-screen-reader-pages-search-sequence-1440x900",
    viewport.width,
    viewport.height,
  );
  return {
    caseId: "live-pages-search-order",
    kind: "live-region-sequence",
    viewport,
    expectedStates,
    requestUrls: [
      firstRequest.request.url,
      secondResponse.request.request.url,
    ],
    stateResult,
    destinationResult,
    final: stateTransitions,
    expectedBrowserDiagnostic: expectedRequestProblem[0],
    screenshot,
  };
}

async function installScreenReaderFlowComposition(session) {
  const requests = [];
  let failure = null;
  const listener = params => {
    const url = new URL(params.request.url);
    if (url.pathname !== "/api/moonflow/composition") return;
    void session.send("Fetch.fulfillRequest", {
      requestId: params.requestId,
      responseCode: 200,
      responseHeaders: [
        { name: "Content-Type", value: "application/json; charset=utf-8" },
        { name: "Cache-Control", value: "no-store" },
      ],
      body: Buffer.from(JSON.stringify({
        selected_item_ids: [],
        items: [],
      })).toString("base64"),
    }).then(() => {
      requests.push({
        method: params.request.method,
        pathname: url.pathname,
        evidence: "deterministic-empty-composition",
      });
    }).catch(error => {
      failure = error;
    });
  };
  session.on("Fetch.requestPaused", listener);
  await session.send("Fetch.enable", {
    patterns: [{
      urlPattern: "*/api/moonflow/composition*",
      requestStage: "Request",
    }],
  });
  return {
    requests,
    async close() {
      session.off("Fetch.requestPaused", listener);
      await session.send("Fetch.disable");
      if (failure) throw failure;
    },
  };
}

async function runScreenReaderScenario() {
  const session = await connect(cdpPort);
  const routeCases = [];
  const paletteCases = [];
  const liveRegionCases = [];
  let flowComposition = null;
  try {
    await enablePageProblemCapture(session);
    await setEnglishLocale(session);
    flowComposition = await installScreenReaderFlowComposition(session);
    for (const viewport of screenReaderViewports) {
      for (let index = 0; index < screenReaderDestinations.length; index += 1) {
        routeCases.push(
          await proveScreenReaderRouteCase(
            session,
            viewport,
            screenReaderDestinations[index],
            index,
          ),
        );
      }
      paletteCases.push(
        await proveScreenReaderPaletteCase(session, viewport),
      );
    }
    liveRegionCases.push(
      await proveDestinationAnnouncementSequence(session),
    );
    liveRegionCases.push(
      await provePagesSearchAnnouncementSequence(session),
    );
    const cases = [...routeCases, ...paletteCases, ...liveRegionCases];
    const uniqueCaseIds = new Set(cases.map(item => item.caseId));
    assert(
      routeCases.length === 18 &&
        paletteCases.length === 2 &&
        liveRegionCases.length === 2 &&
        cases.length === 22 &&
        uniqueCaseIds.size === 22,
      `Screen-reader proof matrix mismatch: ` +
        `${JSON.stringify({
          routeCount: routeCases.length,
          paletteCount: paletteCases.length,
          liveRegionCount: liveRegionCases.length,
          caseCount: cases.length,
          uniqueCaseCount: uniqueCaseIds.size,
        })}`,
    );
    const screenshots = cases
      .map(item => item.screenshot)
      .filter(Boolean);
    assert(
      screenshots.length >= 8 &&
        screenshots.every(screenshot => fs.existsSync(screenshot)),
      `Screen-reader proof lacks representative screenshots: ` +
        `${JSON.stringify(screenshots)}`,
    );
    const voiceOverChecklist = [
      {
        caseId: "voiceover-desktop-home-landmarks",
        journey: "Desktop Home landmark and Primary destinations navigation",
      },
      {
        caseId: "voiceover-compact-home-navigation",
        journey: "Compact Home navigation and discoverable Commands trigger",
      },
      {
        caseId: "voiceover-command-palette-dialog",
        journey: "Commands dialog name, controls, containment, and Escape return",
      },
      {
        caseId: "voiceover-pages-recoverable-search",
        journey: "Pages loading, recoverable failure, retry, and zero-result speech",
      },
    ].map(item => ({
      ...item,
      status: "pending-real-voiceover-verification",
      spokenRoleNameState: "",
      announcementTranscript: "",
      operatorNotes: "",
    }));
    const proofPath = path.join(
      fixtureRoot,
      "moondesk-screen-reader-announcement-proof.v1.json",
    );
    fs.writeFileSync(proofPath, JSON.stringify({
      kind: "moondesk-screen-reader-announcement-proof.v1",
      caseCount: cases.length,
      routeCaseCount: routeCases.length,
      paletteCaseCount: paletteCases.length,
      liveRegionCaseCount: liveRegionCases.length,
      voiceOverChecklistCount: voiceOverChecklist.length,
      viewports: screenReaderViewports,
      screenshotCount: screenshots.length,
      screenshots,
      cases,
      voiceOverChecklist,
      deterministicFixtures: {
        flowCompositionRequests: flowComposition.requests,
      },
      limits: [
        "DOM and Chromium accessibility-tree evidence do not prove spoken VoiceOver output.",
        "The four VoiceOver rows remain pending until a real macOS assistive-technology journey records them.",
      ],
    }, null, 2) + "\n");
    console.log(`Screen-reader announcement proof: ${proofPath}`);
    session.assertNoPageProblems("screen-reader announcement matrix");
  } finally {
    await flowComposition?.close();
    session.close();
  }
}

const runner = scenario === "screen-reader"
  ? runScreenReaderScenario
  : scenario === "keyboard-transients"
  ? verifyKeyboardTransients
  : scenario === "empty"
  ? runEmptyLibrary
  : scenario === "accessibility"
    ? runAccessibility
    : scenario === "capability"
      ? runCapabilityRenderedEvidence
      : scenario === "capability-responsive"
        ? runCapabilityResponsiveEvidence
        : scenario === "capability-scale"
          ? runCapabilityScaleEvidence
          : scenario === "quickstart-before-restart"
            ? runQuickstartBeforeRestart
            : scenario === "quickstart-after-restart"
              ? runQuickstartAfterRestart
              : run;
runner().catch(error => {
  console.error(error.stack || error.message);
  process.exit(1);
});
