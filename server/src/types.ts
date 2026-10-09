export interface LabValue {
  name: string;
  canonicalName: string;
  value: number | null;
  valueText: string;
  unit: string | null;
  referenceLow: number | null;
  referenceHigh: number | null;
  flag: "low" | "normal" | "high" | "unknown";
  explanation: string;
}

export interface ReportAnalysis {
  isMedicalReport: boolean;
  reportType: string;
  reportDate: string | null;
  patientName: string | null;
  values: LabValue[];
  summary: string;
  urgent: boolean;
  urgentReason: string | null;
  questionsForDoctor: string[];
  foodSuggestions: string[];
  exerciseSuggestions: string[];
  seeDoctor: boolean;
  seeDoctorReason: string | null;
  followUpMonths: number | null;
}

import type { AskRequest } from "./ask.js";

/** An AI backend that reads reports and answers questions about them. */
export interface AnalysisProvider {
  analyze(file: Buffer, mimeType: string, language: string): Promise<ReportAnalysis>;
  ask(request: AskRequest): Promise<string>;
}

const nullable = (type: string) => ({ type: [type, "null"] });

export const SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: [
    "isMedicalReport",
    "reportType",
    "reportDate",
    "patientName",
    "values",
    "summary",
    "urgent",
    "urgentReason",
    "questionsForDoctor",
    "foodSuggestions",
    "exerciseSuggestions",
    "seeDoctor",
    "seeDoctorReason",
    "followUpMonths",
  ],
  properties: {
    isMedicalReport: { type: "boolean" },
    reportType: { type: "string" },
    reportDate: nullable("string"),
    patientName: nullable("string"),
    values: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: [
          "name",
          "canonicalName",
          "value",
          "valueText",
          "unit",
          "referenceLow",
          "referenceHigh",
          "flag",
          "explanation",
        ],
        properties: {
          name: { type: "string" },
          canonicalName: { type: "string" },
          value: nullable("number"),
          valueText: { type: "string" },
          unit: nullable("string"),
          referenceLow: nullable("number"),
          referenceHigh: nullable("number"),
          flag: { type: "string", enum: ["low", "normal", "high", "unknown"] },
          explanation: { type: "string" },
        },
      },
    },
    summary: { type: "string" },
    urgent: { type: "boolean" },
    urgentReason: nullable("string"),
    questionsForDoctor: { type: "array", items: { type: "string" } },
    foodSuggestions: { type: "array", items: { type: "string" } },
    exerciseSuggestions: { type: "array", items: { type: "string" } },
    seeDoctor: { type: "boolean" },
    seeDoctorReason: nullable("string"),
    followUpMonths: nullable("integer"),
  },
} as const;

export const SYSTEM = `You help people understand their own medical reports.

Rules:
- Copy values exactly as printed in the report. Never guess or correct a number; if it is unreadable, set value to null and put what you can read in valueText.
- Take reference ranges from the report itself. If none is printed, leave them null and set flag to "unknown".
- Explain in plain, calm language a non-expert can follow, in the language requested by the user.
- You explain and organize. You do not diagnose, prescribe, or tell the user to start or stop a treatment.
- Set urgent to true only for results that would normally need prompt medical attention, and say why in urgentReason.
- The report may be in any language, and it may differ from the language the user asked for. Always write every explanation, tip, question, summary and the reportType in the language requested by the user. Numbers are never translated.
- name is how the test appears for the user, and it must be in the language requested by the user. If the report prints the name in that same language, copy it exactly as printed. If the report prints it in Latin letters (for example "HDL" or "Triglycerides") and the requested language uses another script, write the printed name followed by the requested-language name in parentheses. If the report prints it in a different script from the requested language, do NOT copy or transcribe the printed script; instead write the name in the requested language. Never output a test name in any script other than the requested language's script or Latin letters.
- canonicalName is always the standard English name of the test (for example "Total cholesterol", "Triglycerides", "HDL cholesterol", "LDL cholesterol", "Fasting glucose", "Hemoglobin"), regardless of the printed language, so the same test can be matched across reports. Use the same wording for the same test every time.
- When any result is low or high, give 2 to 4 simple everyday food suggestions and 2 to 3 gentle exercise or lifestyle suggestions that relate to those specific results. Prefer common, affordable foods. These are general wellness tips only: never name medicines, supplements or doses, and never give a treatment or diet plan for a disease. If all results are normal, give at most 2 short tips for staying healthy.
- Set seeDoctor to true whenever any result is outside its range or urgent is true, and explain in seeDoctorReason in one plain sentence. Set it to false, with a null reason, only when everything is normal. Make clear the tips do not replace a doctor's advice.
- reportDate must be the date printed on the report as YYYY-MM-DD (for example 2026-08-23), or null if none is printed. Never write the month as a word.
- followUpMonths is a gentle suggestion of how many months until the user might repeat these tests: 12 when everything is normal, 3 when some results are slightly outside their range, 1 when results are well outside their range or urgent is true. Use null if the file is not a medical report.
- If the file is not a medical report, set isMedicalReport to false and leave the other fields empty.`;

export const userPrompt = (language: string) =>
  `Analyze this report. Write all explanations in: ${language}.`;
