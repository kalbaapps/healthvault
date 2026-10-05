import { GoogleGenAI } from "@google/genai";
import { SCHEMA, SYSTEM, userPrompt } from "../types.js";
import type { AnalysisProvider, ReportAnalysis } from "../types.js";

const MODEL = process.env.GEMINI_MODEL ?? "gemini-3.8-flash";

export function geminiProvider(): AnalysisProvider {
  const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

  return {
    async analyze(file, mimeType, language): Promise<ReportAnalysis> {
      const response = await ai.models.generateContent({
        model: MODEL,
        contents: [
          {
            role: "user",
            parts: [
              { inlineData: { mimeType, data: file.toString("base64") } },
              { text: userPrompt(language) },
            ],
          },
        ],
        config: {
          systemInstruction: SYSTEM,
          responseMimeType: "application/json",
          responseJsonSchema: SCHEMA,
        },
      });

      if (!response.text) {
        throw new Error("No analysis returned.");
      }
      return JSON.parse(response.text) as ReportAnalysis;
    },
  };
}
