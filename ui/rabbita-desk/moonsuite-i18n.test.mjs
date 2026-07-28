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
    `${source}\nglobalThis.messageForTest = message;\nglobalThis.translateTextForTest = translateText;\nglobalThis.translateAttributeForTest = translateAttribute;\nglobalThis.systemLanguageLabelForTest = systemLanguageLabel;`,
    context,
  );
  return context;
}

test("text templates translate dynamic UI copy", () => {
  const context = runtime();
  assert.equal(context.translateTextForTest("3 sessions"), "3 个会话");
});

test("accessibility attributes only use exact translations", () => {
  const context = runtime();
  assert.equal(context.translateAttributeForTest("Wiki"), "知识库");
  assert.equal(
    context.translateAttributeForTest("Search MoonCode sessions"),
    "Search MoonCode sessions",
  );
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
    "not installed",
    "needs configuration",
    "not supported",
    "checking",
    "Start Code assistance",
    "Install Code assistance",
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
