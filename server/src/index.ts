import express from "express";
import multer from "multer";
import { parseAskRequest } from "./ask.js";
import { createProvider } from "./analyze.js";
import { cleanNames } from "./clean.js";
import { detectMime } from "./mime.js";
import { normalizeAnalysis } from "./normalize.js";

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 20 * 1024 * 1024 },
});

const provider = createProvider();
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
  const mimeType = detectMime(file.buffer);
  if (!mimeType) {
    res.status(415).json({ error: "Upload a PDF or an image (JPEG, PNG, WebP)." });
    return;
  }
  const language = String(req.body?.language ?? "English").slice(0, 40);

  try {
    const analysis = await provider.analyze(file.buffer, mimeType, language);
    res.json(normalizeAnalysis(cleanNames(analysis, language)));
  } catch (error) {
    const status = (error as { status?: number }).status;
    console.error("Analysis failed:", error);
    if (status === 429 || status === 503) {
      res.status(503).json({ error: "Busy right now, please try again shortly." });
    } else {
      res.status(500).json({ error: "Could not analyze this report." });
    }
  }
});

app.post("/ask", express.json({ limit: "300kb" }), async (req, res) => {
  const request = parseAskRequest(req.body);
  if (typeof request === "string") {
    res.status(400).json({ error: request });
    return;
  }

  try {
    res.json({ answer: await provider.ask(request) });
  } catch (error) {
    const status = (error as { status?: number }).status;
    console.error("Ask failed:", error);
    if (status === 429 || status === 503) {
      res.status(503).json({ error: "Busy right now, please try again shortly." });
    } else {
      res.status(500).json({ error: "Could not answer that. Please try again." });
    }
  }
});

const port = Number(process.env.PORT ?? 8080);
app.listen(port, () => console.log(`HealthVault server on :${port}`));
