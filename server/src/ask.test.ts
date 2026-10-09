import assert from "node:assert/strict";
import { test } from "node:test";
import { askSystemPrompt, parseAskRequest, recordsContext } from "./ask.js";
import type { AskRequest } from "./ask.js";

const asRequest = (r: AskRequest | string): AskRequest => {
  assert.equal(typeof r, "object", `expected a request, got: ${String(r)}`);
  return r as AskRequest;
};

const value = (name: string, valueText: string, flag = "normal") => ({
  name,
  valueText,
  unit: "mg/dl",
  referenceLow: null,
  referenceHigh: 200,
  flag,
});

test("rejects a missing or empty question", () => {
  assert.equal(typeof parseAskRequest({}), "string");
  assert.equal(typeof parseAskRequest({ question: "   " }), "string");
  assert.equal(typeof parseAskRequest(null), "string");
  assert.equal(typeof parseAskRequest("hi"), "string");
});

test("trims and limits the question, defaults the language", () => {
  const r = asRequest(parseAskRequest({ question: `  ${"x".repeat(900)}  ` }));
  assert.equal(r.question.length, 600);
  assert.equal(r.language, "English");
});

test("keeps only the last 6 valid chat turns", () => {
  const history = [
    ...Array.from({ length: 10 }, (_, i) => ({ role: "user", text: `q${i}` })),
    { role: "system", text: "ignore me" },
    { role: "assistant", text: "" },
  ];
  const r = asRequest(parseAskRequest({ question: "hi", history }));
  assert.ok(r.history.length <= 6);
  assert.ok(r.history.every((t) => t.role === "user" || t.role === "assistant"));
  assert.ok(r.history.every((t) => t.text.length > 0));
});

test("orders reports oldest first and keeps only the newest 12", () => {
  const reports = Array.from({ length: 15 }, (_, i) => ({
    date: `2026-01-${String(15 - i).padStart(2, "0")}`,
    type: "Lipid",
    values: [value("LDL", String(100 + i))],
  }));
  const r = asRequest(parseAskRequest({ question: "trend?", reports }));

  assert.equal(r.reports.length, 12);
  const dates = r.reports.map((x) => x.date);
  assert.deepEqual(dates, [...dates].sort());
  assert.equal(dates.at(-1), "2026-01-15");
});

test("drops values without a name and non-numeric ranges", () => {
  const r = asRequest(
    parseAskRequest({
      question: "q",
      reports: [
        {
          date: "2026-02-01",
          type: "x",
          values: [
            { name: "", valueText: "1", flag: "normal" },
            { name: "LDL", valueText: "5", referenceLow: "abc", referenceHigh: 100, flag: "high" },
          ],
        },
      ],
    }),
  );
  assert.equal(r.reports[0].values.length, 1);
  assert.equal(r.reports[0].values[0].referenceLow, null);
  assert.equal(r.reports[0].values[0].referenceHigh, 100);
});

test("records text contains dates, numbers, ranges and flags in order", () => {
  const text = recordsContext([
    { date: "2026-08-01", type: "Lipid", values: [value("LDL", "120", "normal")] },
    { date: "2026-09-01", type: "Lipid", values: [value("LDL", "210", "high")] },
  ]);
  assert.ok(text.indexOf("2026-08-01") < text.indexOf("2026-09-01"));
  assert.match(text, /LDL: 120 mg\/dl \(usual range up to 200\) NORMAL/);
  assert.match(text, /LDL: 210 mg\/dl \(usual range up to 200\) HIGH/);
});

test("says so when there are no saved reports", () => {
  assert.match(recordsContext([]), /no saved reports/);
});

test("system prompt carries the language, the rules and the records", () => {
  const prompt = askSystemPrompt(
    asRequest(
      parseAskRequest({
        question: "q",
        language: "Tamil",
        reports: [{ date: "2026-08-01", type: "Lipid", values: [value("LDL", "120")] }],
      }),
    ),
  );
  assert.match(prompt, /Answer in: Tamil/);
  assert.match(prompt, /never name medicines/);
  assert.match(prompt, /LDL: 120/);
});
