import express from "express";
import multer from "multer";
import { createProvider } from "./analyze.js";

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
  if (!ALLOWED.has(file.mimetype)) {
    res.status(415).json({ error: "Upload a PDF or an image (JPEG, PNG, WebP)." });
    return;
  }
  const language = String(req.body?.language ?? "English").slice(0, 40);

  try {
    res.json(await provider.analyze(file.buffer, file.mimetype, language));
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

const port = Number(process.env.PORT ?? 8080);
app.listen(port, () => console.log(`HealthVault server on :${port}`));
