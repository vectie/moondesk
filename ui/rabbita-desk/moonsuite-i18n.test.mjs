import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";
import { JSDOM } from "jsdom";

const moduleSource = fs.readFileSync(new URL("./interface-locale.js", import.meta.url), "utf8");
const englishCatalog = JSON.parse(
  fs.readFileSync(new URL("../../locales/en-US.json", import.meta.url), "utf8"),
);
const chineseCatalog = JSON.parse(
  fs.readFileSync(new URL("../../locales/zh-Hans.json", import.meta.url), "utf8"),
);
const source = `const english = ${JSON.stringify(englishCatalog)};\nconst chinese = ${JSON.stringify(chineseCatalog)};\n` +
  moduleSource.replace(/^import .*$/gm, "");
const capabilitySources = [
  "main/capability_state.mbt",
  "main/desk_mode_views.mbt",
  "main/mooncode_views.mbt",
].map((path) =>
  fs.readFileSync(new URL(path, import.meta.url), "utf8"),
).join("\n");

function runtime(search = "?locale=zh-Hans") {
  const context = {
    URLSearchParams,
    document: {
      cookie: "",
      readyState: "loading",
      addEventListener() {},
    },
    localStorage: {
      getItem() { return null; },
      setItem() {},
    },
    location: { search, reload() {} },
    navigator: { language: "en-US", languages: ["en-US"] },
    window: { name: "" },
  };
  vm.createContext(context);
  vm.runInContext(
    `${source}\nglobalThis.messageForTest = message;\nglobalThis.translateTextForTest = translateText;\nglobalThis.translateAttributeForTest = translateAttribute;\nglobalThis.systemLanguageLabelForTest = () => selectedLocale() === "zh-Hans" ? "系统语言" : "System language";`,
    context,
  );
  return context;
}

test("primary navigation uses explicit keys with catalog parity", () => {
  const keys = ["nav.desk", "nav.wiki", "nav.code", "nav.flow", "nav.packs"];
  assert.deepEqual(Object.keys(englishCatalog).sort(), Object.keys(chineseCatalog).sort());
  for (const key of keys) {
    assert.ok(englishCatalog[key], `missing English catalog key: ${key}`);
    assert.ok(chineseCatalog[key], `missing Simplified Chinese catalog key: ${key}`);
  }
  const sourceText = fs.readFileSync(
    new URL("main/moonwiki_command_palette_views.mbt", import.meta.url),
    "utf8",
  );
  assert.match(sourceText, /class="primary-nav-label"/);
  assert.match(
    sourceText,
    /span\([\s\S]*?\.data_set\([\s\S]*?"i18n",\s*primary_navigation_i18n_key\(mode\)/,
  );
  assert.doesNotMatch(sourceText, /\.data_set\("testid", test_id\)[\s\S]*?\.data_set\("i18n"/);
  for (const key of keys) {
    assert.match(sourceText, new RegExp(`"${key.replaceAll(".", "\\.")}"`));
  }
});

test('every explicit interface key used by the views exists in both catalogs', () => {
  const paths = [
    ...fs.readdirSync(new URL('./main/', import.meta.url)).filter(name => name.endsWith('.mbt') && !name.endsWith('test.mbt')).map(name => `main/${name}`),
    ...fs.readdirSync(new URL('./', import.meta.url)).filter(name => name.endsWith('.js')),
  ];
  const keys = new Set(paths.flatMap(path => [...fs.readFileSync(new URL(path, import.meta.url), 'utf8')
    .matchAll(/["']((?:code|nav|common|pack|desk|flow|shell|task)\.[a-z_]+)["']/g)].map(match => match[1])));
  for (const view of ['source', 'review', 'browser', 'terminal', 'compare']) keys.add(`code.pane_${view}`);
  for (const area of ['staged', 'working']) for (const status of ['modified', 'added', 'deleted', 'renamed', 'copied', 'conflict', 'ignored']) keys.add(`code.git_${area}_${status}`);
  const missing = [...keys].filter(key => !key.endsWith('_') && (!englishCatalog[key] || !chineseCatalog[key]));
  assert.deepEqual(missing, [], 'missing UI translation keys');
});

async function localizedDOM(html, locale = 'zh-Hans') {
  const dom = new JSDOM(html, { url: `http://localhost/?workspace=coding&locale=${locale}`, runScripts: 'outside-only' });
  const observers = [];
  const NativeObserver = dom.window.MutationObserver;
  dom.window.MutationObserver = class extends NativeObserver {
    constructor(callback) { super(callback); observers.push(this); }
  };
  const close = dom.window.close.bind(dom.window);
  dom.window.close = () => { for (const observer of observers) observer.disconnect(); close(); };
  dom.window.eval(source);
  await new Promise(resolve => setTimeout(resolve, 0));
  return dom;
}

test('Code headings distinguish default labels from user task titles', async () => {
  const dom = await localizedDOM('<div class="mooncode-context-bar"><div><strong data-i18n-scope="interface">New chat</strong><span data-i18n-scope="content">Review</span></div></div><div class="mooncode-empty"><h1 data-i18n-scope="interface">Request saved</h1><h1 data-i18n-scope="content">New chat</h1></div>');
  const { document } = dom.window;
  assert.equal(document.querySelector('strong').textContent, '新建对话');
  assert.equal(document.querySelector('span').textContent, 'Review');
  assert.deepEqual([...document.querySelectorAll('h1')].map(node => node.textContent), ['请求已保存', 'New chat']);
  dom.window.close();
});

test('Book default headings and attachment actions translate without renaming content', async () => {
  const dom = await localizedDOM(`<header class="wiki-chat-header"><h2 data-i18n-scope="interface" data-i18n="task.new">New task</h2><h2 data-i18n-scope="content">New task</h2></header>
    <header class="wiki-viewer-header"><h2 data-i18n-scope="interface" data-i18n="task.document">Document</h2><h2 data-i18n-scope="content">Document</h2></header>
    <div><span data-i18n-scope="content">Skills</span><button aria-label="Remove attached file Skills">×</button></div>`);
  try {
    assert.deepEqual([...dom.window.document.querySelectorAll('h2')].map(node => node.textContent), ['新任务', 'New task', '文档', 'Document']);
    assert.equal(dom.window.document.querySelector('span').textContent, 'Skills');
    assert.equal(dom.window.document.querySelector('button').getAttribute('aria-label'), '移除附件 Skills');
  } finally { dom.window.close(); }
});

test('secondary surface messages translate while book names and drafts stay authored', async () => {
  const dom = await localizedDOM(`<div class="work-book-switcher"><summary><span data-i18n-scope="interface">No workspace</span></summary></div>
    <div class="work-book-switcher"><summary><span data-i18n-scope="content">Review</span></summary></div>
    <aside class="work-detail-drawer"><h3>Preferences & glossary</h3><select aria-label="Preference type"><option value="name">Name & spelling</option></select>
    <textarea placeholder="What MoonDesk should use or remember">Results</textarea><p role="status">Loading preferences…</p></aside>
    <p id="refresh">Refreshing 8 items</p><p id="package">Inspecting package contents…</p>`);
  const { document } = dom.window;
  assert.equal(document.querySelector('[data-i18n-scope="interface"]').textContent, '未选择知识库');
  assert.equal(document.querySelector('[data-i18n-scope="content"]').textContent, 'Review');
  assert.equal(document.querySelector('h3').textContent, chineseCatalog['preferences.heading']);
  assert.equal(document.querySelector('select').getAttribute('aria-label'), '偏好类型');
  assert.equal(document.querySelector('select').value, 'name');
  assert.equal(document.querySelector('textarea').value, 'Results');
  assert.equal(document.querySelector('[role="status"]').textContent, '正在加载偏好设置…');
  assert.equal(document.querySelector('#refresh').textContent, '正在刷新 8 项');
  assert.equal(document.querySelector('#package').textContent, '正在检查文件包内容…');
  dom.window.close();
});

test('new and rerendered controls translate text, placeholders and icon tooltips together', async () => {
  const dom = await localizedDOM('<main></main>');
  const { document } = dom.window;
  const button = document.createElement('button');
  button.textContent = 'Start a task';
  for (const attr of ['aria-label', 'title', 'data-tooltip']) button.setAttribute(attr, 'Start a task');
  document.querySelector('main').append(button);
  const input = document.createElement('textarea'); input.placeholder = 'Describe a result, a change, or a question…';
  document.querySelector('main').append(input);
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(button.textContent, '开始任务');
  for (const attr of ['aria-label', 'title', 'data-tooltip']) assert.equal(button.getAttribute(attr), '开始任务');
  assert.equal(input.placeholder, '描述想要的成果、修改或问题…');
  button.setAttribute('data-tooltip', 'Recent tasks');
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(button.dataset.tooltip, '最近任务');
  assert.equal(document.body.style.fontFamily, '', 'locale must not override the shared font');
  dom.window.close();
});

test('translation leaves user content, technical values and nested attributes intact', async () => {
  const dom = await localizedDOM(`<main>
    <section data-i18n-scope="content"><span title="Results" aria-label="Ready">Review</span></section>
    <pre><span title="Ready">Results</span></pre><textarea>Review</textarea>
    <div contenteditable="true">Results</div><button class="work-book-option" title="Review"><span>Review</span></button>
    <p>2 ready · 2 installed</p><button aria-label="Details for Review: Ready"></button>
  </main>`);
  const { document } = dom.window;
  assert.equal(document.querySelector('[data-i18n-scope] span').outerHTML, '<span title="Results" aria-label="Ready">Review</span>');
  assert.equal(document.querySelector('pre').textContent, 'Results');
  assert.equal(document.querySelector('pre span').title, 'Ready');
  assert.equal(document.querySelector('textarea').value, 'Review');
  assert.equal(document.querySelector('[contenteditable]').textContent, 'Results');
  assert.equal(document.querySelector('.work-book-option').textContent, 'Review');
  assert.equal(document.querySelector('p').textContent, '2 个可用 · 2 个已安装');
  assert.equal(document.querySelector('button[aria-label]').getAttribute('aria-label'), 'Review 的详情：可用');
  dom.window.close();
});

test('Desk section aliases translate without changing filenames, paths or rename fields', async () => {
  const fixture = `<div data-testid="desk-file-row" title="inbox" data-i18n-preserve="title" data-path="inbox">
    <span class="desk-file-name" data-i18n-scope="interface"><strong data-i18n="desk.section_inbox">Inbox</strong></span></div>
    <span class="folder-label" data-i18n-scope="interface" data-i18n="desk.section_review_queue">Review Queue</span>
    <div data-testid="desk-file-row" title="Skills" data-i18n-preserve="title" data-path="Skills">
      <span class="desk-file-name" data-i18n-scope="content"><strong>Skills</strong></span></div>
    <span class="folder-label">Tools</span><h3 data-i18n-scope="content">Inbox</h3>
    <input data-i18n-scope="content" value="Review Queue" placeholder="Review Queue">`;
  for (const locale of ['zh-Hans', 'en-US']) {
    const dom = await localizedDOM(fixture, locale);
    const { document } = dom.window;
    assert.equal(document.querySelector('[data-i18n="desk.section_inbox"]').textContent, locale === 'zh-Hans' ? '收件箱' : 'Inbox');
    assert.equal(document.querySelector('[data-i18n="desk.section_review_queue"]').textContent, locale === 'zh-Hans' ? '审阅队列' : 'Review Queue');
    assert.equal(document.querySelector('[data-path="inbox"]').title, 'inbox');
    assert.equal(document.querySelector('[data-path="Skills"]').title, 'Skills');
    assert.equal(document.querySelector('[data-path="Skills"] strong').textContent, 'Skills');
    assert.equal(document.querySelector('.folder-label:not([data-i18n])').textContent, 'Tools');
    assert.equal(document.querySelector('h3').textContent, 'Inbox');
    assert.equal(document.querySelector('input').value, 'Review Queue');
    assert.equal(document.querySelector('input').placeholder, 'Review Queue');
    dom.window.close();
  }
});

test('explicit attribute keys update without replacing button icons', async () => {
  const dom = await localizedDOM('<button data-i18n-aria-label="shell.results" data-i18n-data-tooltip="shell.results"><svg></svg></button>');
  const button = dom.window.document.querySelector('button');
  assert.equal(button.getAttribute('aria-label'), '成果');
  assert.equal(button.dataset.tooltip, '成果');
  assert.ok(button.querySelector('svg'));
  button.setAttribute('data-i18n-aria-label', 'shell.recent_tasks');
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(button.getAttribute('aria-label'), '最近任务');
  dom.window.close();
});

test('translated option labels preserve submitted values and selection', async () => {
  const dom = await localizedDOM('<select><option>low</option><option selected>high</option></select>');
  const select = dom.window.document.querySelector('select');
  assert.equal(select.value, 'high');
  assert.deepEqual([...select.options].map(option => [option.value, option.textContent]), [['low', '低'], ['high', '高']]);
  dom.window.close();
});

test('language preference stays in the workspace tools after a shell rerender', async () => {
  const dom = await localizedDOM('<header><div class="work-tools-options"></div></header>');
  const { document } = dom.window;
  assert.ok(document.querySelector('.work-tools-options #moonsuite-language'));
  document.querySelector('header').innerHTML = '<div class="work-tools-options"></div>';
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(document.querySelectorAll('#moonsuite-language').length, 1);
  assert.equal(document.querySelector('.work-tools-options select').value, 'zh-Hans');
  dom.window.close();
});

test('empty legacy keys still translate, missing keys keep their authored fallback', async () => {
  const dom = await localizedDOM('<p data-i18n="">Execution controls are unavailable</p><button data-i18n-aria-label="missing.key" aria-label="Action">Action</button>');
  assert.equal(dom.window.document.querySelector('p').textContent, '运行控制暂不可用');
  assert.equal(dom.window.document.querySelector('button').getAttribute('aria-label'), 'Action');
  assert.equal(dom.window.MoonSuiteI18n.text('Open an unrecognized feature'), 'Open an unrecognized feature');
  dom.window.close();
});

test('editor status observers settle when their labels are localized', async () => {
  const dom = await localizedDOM('<main><span id="cursor"></span><button id="check"></button></main>');
  const helpers = fs.readFileSync(new URL('./ui-locale.js', import.meta.url), 'utf8').replace(/^export /gm, '');
  dom.window.eval(helpers + '\nwindow.setUiText = setUiText');
  const cursor = dom.window.document.querySelector('#cursor');
  const check = dom.window.document.querySelector('#check');
  let passes = 0;
  // These controls are synchronized by the shell's child-list observer. The
  // producer must compare the localized value, or it fights the translator.
  const observer = new dom.window.MutationObserver(() => {
    if (++passes > 20) { observer.disconnect(); return; }
    dom.window.setUiText(cursor, 'Ln 1, Col 1');
    dom.window.setUiText(check, 'Check workspace');
  });
  observer.observe(dom.window.document.body, { childList: true, subtree: true });
  dom.window.setUiText(cursor, 'Ln 1, Col 1');
  await new Promise(resolve => setTimeout(resolve, 0));
  assert.equal(cursor.textContent, '第 1 行，第 1 列');
  assert.equal(check.textContent, '检查工作区');
  assert.ok(passes < 4, `editor observers did not settle: ${passes}`);
  observer.disconnect(); dom.window.close();
});

test('English stays English and an explicit language change removes the URL override', async () => {
  const dom = await localizedDOM('<button data-i18n="shell.start_task">Start a task</button>', 'en-US');
  const { document } = dom.window;
  assert.equal(document.querySelector('button').textContent, 'Start a task');
  assert.equal(document.documentElement.lang, 'en-US');
  // Avoid JSDOM navigation; exercise the actual preference writer with a stub.
  const context = runtime();
  context.URL = URL;
  context.location.href = 'http://localhost/?workspace=coding&locale=zh-Hans';
  let replaced, reloaded = false;
  context.history = { state: null, replaceState(_state, _title, url) { replaced = String(url); } };
  context.location.reload = () => { reloaded = true; };
  vm.runInContext("storeLocale('en-US')", context);
  assert.equal(replaced, 'http://localhost/?workspace=coding');
  assert.equal(context.window.name, 'moonsuite-locale:en-US');
  assert.ok(reloaded);
  dom.window.close();
});

test("text templates translate dynamic UI copy", () => {
  const context = runtime();
  assert.equal(context.translateTextForTest("3 sessions"), "3 个会话");
  assert.equal(
    context.translateTextForTest(
      "A copied MoonClaw service configuration points to an unavailable managed runtime; reinstall MoonClaw to repair it",
    ),
    "复制的 MoonClaw 服务配置指向不可用的托管运行时；请重新安装 MoonClaw 以修复。",
  );
  assert.equal(context.messageForTest("code.github_find_file"), "查找 PR 文件");
  assert.equal(
    context.messageForTest("code.github_filter_count", { visible: 1, total: 260 }),
    "显示 1 / 260 个 PR 文件",
  );
  assert.equal(
    context.messageForTest("code.github_conversation_context", { head: "4abc2389" }),
    "在提交 4abc2389 评论 PR 对话 · 评论将对有权访问此 PR 的读者公开",
  );
  assert.equal(
    context.messageForTest("code.github_line_location_right", {
      path: ".github/workflows/ci.yml", line: 45,
    }),
    "评论 .github/workflows/ci.yml · 新文件第 45 行",
  );
});

test("accessibility attributes use explicit keys without mixed-language templates", () => {
  const context = runtime();
  assert.equal(context.translateAttributeForTest("Wiki"), "知识库");
  assert.equal(context.messageForTest("code.search_sessions"), "搜索 MoonCode 会话");
  assert.notEqual(
    context.messageForTest("code.search_sessions"),
    "Search MoonCode 个会话",
  );
  const sourceText = fs.readFileSync(
    new URL("main/mooncode_views.mbt", import.meta.url),
    "utf8",
  );
  assert.match(sourceText, /data_set\("i18n-aria-label", "code\.search_sessions"\)/);
});

test("Code runtime messages use complete translations instead of matching fragments", () => {
  const context = runtime();
  assert.equal(
    context.translateTextForTest("MoonClaw is not installed"),
    "尚未安装 MoonClaw",
  );
  assert.equal(context.messageForTest("code.moonclaw_not_installed"), "尚未安装 MoonClaw");
  assert.equal(context.messageForTest("code.runtime_unavailable"), "代码运行环境不可用");
  const sourceText = fs.readFileSync(
    new URL("main/mooncode_views.mbt", import.meta.url),
    "utf8",
  );
  assert.match(sourceText, /"MoonClaw is not installed" => "code\.moonclaw_not_installed"/);
  assert.match(sourceText, /mooncode_capability_title_i18n_key/);
});

test("system language choice uses one locale instead of a bilingual label", () => {
  assert.equal(runtime("?locale=en-US").systemLanguageLabelForTest(), "System language");
  assert.equal(runtime("?locale=zh-Hans").systemLanguageLabelForTest(), "系统语言");
});

test("ordinary Code assistance capability copy translates in Simplified Chinese", () => {
  const context = runtime();
  const copy = [
    "Optional capability",
    "Code assistance",
    "Code assistance is ready",
    "You can start or continue Code conversations.",
    "Code assistance is stopped",
    "Start Code assistance before beginning a conversation.",
    "Code assistance needs an account or model",
    "Connect Codex, GitHub Copilot, or OpenRouter to finish setup.",
    "Code assistance is not installed",
    "Install Code assistance to use Code conversations.",
    "Code assistance needs configuration",
    "Review the configuration before using Code assistance.",
    "Code assistance is not supported here",
    "You can continue with Pages and files without local Code assistance.",
    "Code assistance status is unavailable",
    "Check again when status information is available. Pages and files remain available.",
    "running",
    "installed, stopped",
    "setup needed",
    "not installed",
    "needs configuration",
    "not supported",
    "checking",
    "Start Code assistance",
    "Install Code assistance",
    "Connect Codex",
    "Review configuration",
    "Check again",
    "Installing Code assistance…",
    "Preparing Code assistance. This can take a moment.",
  ];
  for (const english of copy) {
    const translated = context.translateTextForTest(english);
    assert.notEqual(translated, english, `expected Simplified Chinese for: ${english}`);
  }
  for (const legacy of [
    "MoonClaw needs setup",
    "Enable the installed MoonClaw product from MoonGate; no path or service file editing is required here.",
    "Open MoonGate setup",
  ]) {
    assert.equal(source.includes(legacy), false, `generated catalog retained legacy copy: ${legacy}`);
  }
});

test("ordinary Code assistance source keys have complete catalog parity", () => {
  assert.deepEqual(
    Object.keys(chineseCatalog).sort(),
    Object.keys(englishCatalog).sort(),
    "English and Simplified Chinese catalog keys differ",
  );
  const renderedKeys = [
    ...new Set(
      [...capabilitySources.matchAll(/"(code\.assistance_[^"]+)"/g)]
        .map((match) => match[1]),
    ),
  ].sort();
  const catalogKeys = Object.keys(englishCatalog)
    .filter((key) => key.startsWith("code.assistance_"))
    .sort();
  assert.deepEqual(
    renderedKeys,
    catalogKeys,
    "ordinary Code-assistance source and catalog keys differ",
  );
  const context = runtime();
  for (const key of renderedKeys) {
    assert.equal(
      context.messageForTest(key),
      chineseCatalog[key],
      `generated catalog does not resolve ${key}`,
    );
    assert.notEqual(
      chineseCatalog[key],
      englishCatalog[key],
      `Simplified Chinese falls back to English for ${key}`,
    );
  }
});
