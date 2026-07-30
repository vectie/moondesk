import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = fs.readFileSync(new URL("./public/moonsuite-i18n.js", import.meta.url), "utf8");
const englishCatalog = JSON.parse(
  fs.readFileSync(new URL("../../locales/en-US.json", import.meta.url), "utf8"),
);
const chineseCatalog = JSON.parse(
  fs.readFileSync(new URL("../../locales/zh-Hans.json", import.meta.url), "utf8"),
);
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
    `${source}\nglobalThis.messageForTest = message;\nglobalThis.translateTextForTest = translateText;\nglobalThis.translateAttributeForTest = translateText;\nglobalThis.systemLanguageLabelForTest = () => selectedLocale() === "zh-Hans" ? "系统语言" : "System language";`,
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

test("text templates translate dynamic UI copy", () => {
  const context = runtime();
  assert.equal(context.translateTextForTest("3 sessions"), "3 个会话");
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
