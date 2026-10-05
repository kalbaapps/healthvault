import Anthropic from "@anthropic-ai/sdk";
import express from "express";
import multer from "multer";
import { analyzeReport } from "./analyze.js";

const ALLOWED = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
]);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
});

const app = express();

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/analyze", upload.single("file"), async (req, res) => {
  const file = req.file;
  if (!file) {
    res.status(400).json({ error: "Attach a report as multipart field 'file'." });
    return;
  }
  if (!ALLOWED.has(file.mimetype)) {
    res.status(415).json({ error: "Upload a PDF or an image (JPEG, PNG, WebP)." });
    return;
  }
  const language = String(req.body?.language ?? "English").slice(0, 40);

  try {
    res.json(await analyzeReport(file.buffer, file.mimetype, language));
  } catch (error) {
    if (error instanceof Anthropic.RateLimitError) {
      res.status(503).json({ error: "Busy right now, please try again shortly." });
    } else if (error instanceof Anthropic.APIError) {
      console.error(`Claude API error ${error.status}:`, error.message);
      res.status(502).json({ error: "Analysis service error." });
    } else {
      console.error(error);
      res.status(500).json({ error: "Could not analyze this report." });
    }
  }
});

const port = Number(process.env.PORT ?? 8080);
app.listen(port, () => console.log(`HealthVault server on :${port}`));
