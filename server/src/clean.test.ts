import assert from "node:assert/strict";
import { test } from "node:test";
import { cleanNames } from "./clean.js";
import type { LabValue, ReportAnalysis } from "./types.js";

const lab = (name: string, canonicalName: string): LabValue => ({
  name,
  canonicalName,
  value: 1,
  valueText: "1",
  unit: null,
  referenceLow: null,
  referenceHigh: null,
  flag: "normal",
  explanation: "",
});

const report = (...values: LabValue[]): ReportAnalysis => ({
  isMedicalReport: true,
  reportType: "x",
  reportDate: null,
  patientName: null,
  values,
  summary: "",
  urgent: false,
  urgentReason: null,
  questionsForDoctor: [],
  foodSuggestions: [],
  exerciseSuggestions: [],
  seeDoctor: false,
  seeDoctorReason: null,
  followUpMonths: null,
});

const names = (r: ReportAnalysis) => r.values.map((v) => v.name);

test("replaces a wrong-script name with the English name for an English result", () => {
  const kannada = "ಒಟ್ಟು ಕೊಲೆಸ್ಟ್ರಾಲ್";
  const out = cleanNames(report(lab(kannada, "Total cholesterol")), "English");
  assert.deepEqual(names(out), ["Total cholesterol"]);
});

test("replaces Sinhala letters when the requested language is not Sinhala", () => {
  const out = cleanNames(report(lab("මුළු කොලෙස්ටරෝල්", "Total cholesterol")), "Español");
  assert.deepEqual(names(out), ["Total cholesterol"]);
});

test("keeps names in the requested language's own script", () => {
  const sinhala = "මුළු කොලෙස්ටරෝල්";
  const out = cleanNames(report(lab(sinhala, "Total cholesterol")), "සිංහල (Sinhala)");
  assert.deepEqual(names(out), [sinhala]);
});

test("keeps Latin names, digits and punctuation", () => {
  const out = cleanNames(report(lab("HDL - Cholesterol (2)", "HDL cholesterol")), "Tamil");
  assert.deepEqual(names(out), ["HDL - Cholesterol (2)"]);
});

test("allows Latin letters mixed with the requested script", () => {
  const mixed = "HDL கொலஸ்ட்ரால்";
  const out = cleanNames(report(lab(mixed, "HDL cholesterol")), "தமிழ் (Tamil)");
  assert.deepEqual(names(out), [mixed]);
});

test("leaves a wrong-script name alone when there is no English name to use", () => {
  const kannada = "ಒಟ್ಟು";
  const out = cleanNames(report(lab(kannada, "")), "English");
  assert.deepEqual(names(out), [kannada]);
});
