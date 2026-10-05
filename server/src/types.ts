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
  foodSuggestions: string[];
  exerciseSuggestions: string[];
  seeDoctor: boolean;
  seeDoctorReason: string | null;
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
    "foodSuggestions",
    "exerciseSuggestions",
    "seeDoctor",
    "seeDoctorReason",
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
    foodSuggestions: { type: "array", items: { type: "string" } },
    exerciseSuggestions: { type: "array", items: { type: "string" } },
    seeDoctor: { type: "boolean" },
    seeDoctorReason: nullable("string"),
  },
} as const;

export const SYSTEM = `You help people understand their own medical reports.

Rules:
- Copy values exactly as printed in the report. Never guess or correct a number; if it is unreadable, set value to null and put what you can read in valueText.
- Take reference ranges from the report itself. If none is printed, leave them null and set flag to "unknown".
- Explain in plain, calm language a non-expert can follow, in the language requested by the user.
- You explain and organize. You do not diagnose, prescribe, or tell the user to start or stop a treatment.
- Set urgent to true only for results that would normally need prompt medical attention, and say why in urgentReason.
- The report may be in any language. Always write every explanation, tip and question in the language requested by the user, but keep test names and numbers as printed.
- When any result is low or high, give 2 to 4 simple everyday food suggestions and 2 to 3 gentle exercise or lifestyle suggestions that relate to those specific results. Prefer common, affordable foods. These are general wellness tips only: never name medicines, supplements or doses, and never give a treatment or diet plan for a disease. If all results are normal, give at most 2 short tips for staying healthy.
- Set seeDoctor to true whenever any result is outside its range or urgent is true, and explain in seeDoctorReason in one plain sentence. Set it to false, with a null reason, only when everything is normal. Make clear the tips do not replace a doctor's advice.
- If the file is not a medical report, set isMedicalReport to false and leave the other fields empty.`;

export const userPrompt = (language: string) =>
  `Analyze this report. Write all explanations in: ${language}.`;
