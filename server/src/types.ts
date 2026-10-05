export interface LabValue {
  name: string;
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
}

/** An AI backend that turns a report file into a structured analysis. */
export interface AnalysisProvider {
  analyze(file: Buffer, mimeType: string, language: string): Promise<ReportAnalysis>;
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
  },
} as const;

export const SYSTEM = `You help people understand their own medical reports.

Rules:
- Copy values exactly as printed in the report. Never guess or correct a number; if it is unreadable, set value to null and put what you can read in valueText.
- Take reference ranges from the report itself. If none is printed, leave them null and set flag to "unknown".
- Explain in plain, calm language a non-expert can follow, in the language requested by the user.
- You explain and organize. You do not diagnose, prescribe, or tell the user to start or stop a treatment.
- Set urgent to true only for results that would normally need prompt medical attention, and say why in urgentReason.
- If the file is not a medical report, set isMedicalReport to false and leave the other fields empty.`;

export const userPrompt = (language: string) =>
  `Analyze this report. Write all explanations in: ${language}.`;
