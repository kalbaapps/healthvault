import Anthropic from "@anthropic-ai/sdk";
import { SCHEMA, SYSTEM, userPrompt } from "../types.js";
import type { AnalysisProvider, ReportAnalysis } from "../types.js";

const MODEL = process.env.CLAUDE_MODEL ?? "claude-opus-5-5";

export function claudeProvider(): AnalysisProvider {
  const client = new Anthropic();

  return {
    async analyze(file, mimeType, language): Promise<ReportAnalysis> {
      const data = file.toString("base64");

      const fileBlock =
        mimeType === "application/pdf"
          ? ({
              type: "document",
              source: { type: "base64", media_type: "application/pdf", data },
            } as const)
          : ({
              type: "image",
              source: {
                type: "base64",
                media_type: mimeType as "image/jpeg" | "image/png" | "image/webp" | "image/gif",
                data,
              },
            } as const);

      const response = await client.beta.messages.create({
        model: MODEL,
        max_tokens: 16000,
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        system: SYSTEM,
        output_config: {
          effort: "medium",
          format: { type: "json_schema", schema: SCHEMA as unknown as Record<string, unknown> },
        },
        messages: [
          {
            role: "user",
            content: [fileBlock, { type: "text", text: userPrompt(language) }],
          },
        ],
      });

      if (response.stop_reason === "refusal") {
        throw new Error("The report could not be analyzed.");
      }
      if (response.stop_reason === "max_tokens") {
        throw new Error("The report is too large to analyze in one go.");
      }

      const text = response.content.find((b) => b.type === "text");
      if (!text || text.type !== "text") {
        throw new Error("No analysis returned.");
      }
      return JSON.parse(text.text) as ReportAnalysis;
    },
  };
}
