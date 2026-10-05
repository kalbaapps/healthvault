import { GoogleGenAI } from "@google/genai";
import { SCHEMA, SYSTEM, userPrompt } from "../types.js";
import type { AnalysisProvider, ReportAnalysis } from "../types.js";

/**
 * Models to try, in order. GEMINI_MODEL may hold a comma-separated list.
 * Google's free tier often reports "high demand" on one model while another
 * is fine, so a busy model falls through to the next one.
 */
const MODELS = (process.env.GEMINI_MODEL ?? "gemini-3.1-flash-lite,gemini-3.7-flash")
  .split(",")
  .map((m) => m.trim())
  .filter(Boolean);

const BUSY = new Set([429, 500, 503, 504]);
const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

const statusOf = (error: unknown) => (error as { status?: number }).status;

export function geminiProvider(): AnalysisProvider {
  const ai = new GoogleGenAI({ apiKey: process.env.GEMINI_API_KEY });

  return {
    async analyze(file, mimeType, language): Promise<ReportAnalysis> {
      const contents = [
        {
          role: "user",
          parts: [
            { inlineData: { mimeType, data: file.toString("base64") } },
            { text: userPrompt(language) },
          ],
        },
      ];

      let lastError: unknown;
      for (const model of MODELS) {
        // Two quick tries per model before moving on to the next one.
        for (let attempt = 1; attempt <= 2; attempt++) {
          try {
            const response = await ai.models.generateContent({
              model,
              contents,
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
          } catch (error) {
            lastError = error;
            const status = statusOf(error);
            // A retired or unknown model (404) should also fall through.
            if (status !== 404 && (status === undefined || !BUSY.has(status))) {
              throw error;
            }
            if (status === 404) break;
            if (attempt === 1) await sleep(1500);
          }
        }
      }
      throw lastError;
    },
  };
}
