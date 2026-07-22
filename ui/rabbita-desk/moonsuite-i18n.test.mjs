import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = fs.readFileSync(new URL("./public/moonsuite-i18n.js", import.meta.url), "utf8");

function runtime() {
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
    location: { search: "?locale=zh-Hans", reload() {} },
    navigator: { language: "en-US", languages: ["en-US"] },
    window: { name: "" },
  };
  vm.createContext(context);
  vm.runInContext(
    `${source}\nglobalThis.translateTextForTest = translateText;\nglobalThis.translateAttributeForTest = translateAttribute;`,
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
