import { claudeProvider } from "./providers/claude.js";
import { geminiProvider } from "./providers/gemini.js";
import type { AnalysisProvider } from "./types.js";

export type { LabValue, ReportAnalysis } from "./types.js";

/** Picks the AI backend from the PROVIDER env var ("gemini" by default, or "claude"). */
export function createProvider(): AnalysisProvider {
  const name = (process.env.PROVIDER ?? "gemini").toLowerCase();
  switch (name) {
    case "gemini":
      return geminiProvider();
    case "claude":
      return claudeProvider();
    default:
      throw new Error(`Unknown PROVIDER "${name}". Use "gemini" or "claude".`);
  }
}
