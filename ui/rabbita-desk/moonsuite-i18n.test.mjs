import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = fs.readFileSync(new URL("./public/moonsuite-i18n.js", import.meta.url), "utf8");

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
    `${source}\nglobalThis.translateTextForTest = translateText;\nglobalThis.translateAttributeForTest = translateAttribute;\nglobalThis.systemLanguageLabelForTest = systemLanguageLabel;`,
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
