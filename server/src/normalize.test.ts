import assert from "node:assert/strict";
import { test } from "node:test";
import { clampFollowUpMonths, normalizeReportDate } from "./normalize.js";

test("keeps ISO dates and pads single digits", () => {
  assert.equal(normalizeReportDate("2026-08-23"), "2026-08-23");
  assert.equal(normalizeReportDate("2026-8-3"), "2026-08-03");
  assert.equal(normalizeReportDate("2026-08-23T10:15:00Z"), "2026-08-23");
});

test("reads 'Month D, YYYY' in any capitalisation and with abbreviations", () => {
  assert.equal(normalizeReportDate("August 23, 2026"), "2026-08-23");
  assert.equal(normalizeReportDate("august 3 2026"), "2026-08-03");
  assert.equal(normalizeReportDate("Sep. 5, 2026"), "2026-09-05");
  assert.equal(normalizeReportDate("Dec 31, 2025"), "2025-12-31");
});

test("reads 'D Month YYYY' including ordinals", () => {
  assert.equal(normalizeReportDate("23 August 2026"), "2026-08-23");
  assert.equal(normalizeReportDate("1st March 2026"), "2026-03-01");
});

test("leaves ambiguous numeric dates alone rather than guessing", () => {
  assert.equal(normalizeReportDate("03/04/2026"), "03/04/2026");
  assert.equal(normalizeReportDate("23-08-2026"), "23-08-2026");
});

test("leaves impossible dates and other text unchanged", () => {
  assert.equal(normalizeReportDate("February 31, 2026"), "February 31, 2026");
  assert.equal(normalizeReportDate("sometime last week"), "sometime last week");
});

test("null stays null", () => {
  assert.equal(normalizeReportDate(null), null);
});

test("follow-up months must be a whole number from 1 to 24", () => {
  assert.equal(clampFollowUpMonths(3), 3);
  assert.equal(clampFollowUpMonths(2.6), 3);
  assert.equal(clampFollowUpMonths(24), 24);
  assert.equal(clampFollowUpMonths(0), null);
  assert.equal(clampFollowUpMonths(60), null);
  assert.equal(clampFollowUpMonths(-2), null);
  assert.equal(clampFollowUpMonths("3"), null);
  assert.equal(clampFollowUpMonths(null), null);
  assert.equal(clampFollowUpMonths(Number.NaN), null);
});
