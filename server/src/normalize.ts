import type { ReportAnalysis } from "./types.js";

const MONTHS = [
  "january", "february", "march", "april", "may", "june",
  "july", "august", "september", "october", "november", "december",
];

const monthNumber = (word: string): number | null => {
  const w = word.toLowerCase().replace(/\.$/, "");
  const index = MONTHS.findIndex((m) => m === w || (w.length >= 3 && m.startsWith(w)));
  return index === -1 ? null : index + 1;
};

const iso = (year: number, month: number, day: number): string | null => {
  const date = new Date(Date.UTC(year, month - 1, day));
  // Reject impossible dates such as 31 February.
  if (date.getUTCFullYear() !== year || date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    return null;
  }
  return `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
};

/**
 * Turns the report date into YYYY-MM-DD when it is unambiguous: already ISO,
 * "August 23, 2026" or "23 August 2026". Numeric day/month orders such as
 * 03/04/2026 are ambiguous (3 April or March 4) and are left as they are, so
 * the app falls back to the day the report was saved instead of guessing.
 */
export function normalizeReportDate(text: string | null): string | null {
  if (text === null) return null;
  const s = text.trim();

  let m = /^(\d{4})-(\d{1,2})-(\d{1,2})(?:[T ].*)?$/.exec(s);
  if (m) return iso(Number(m[1]), Number(m[2]), Number(m[3])) ?? text;

  m = /^([A-Za-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})$/.exec(s);
  if (m) {
    const month = monthNumber(m[1]);
    if (month) return iso(Number(m[3]), month, Number(m[2])) ?? text;
  }

  m = /^(\d{1,2})(?:st|nd|rd|th)?\s+([A-Za-z]{3,9})\.?,?\s+(\d{4})$/.exec(s);
  if (m) {
    const month = monthNumber(m[2]);
    if (month) return iso(Number(m[3]), month, Number(m[1])) ?? text;
  }

  return text;
}

/** A follow-up suggestion is a whole number of months from 1 to 24, or null. */
export function clampFollowUpMonths(value: unknown): number | null {
  if (typeof value !== "number" || !Number.isFinite(value)) return null;
  const months = Math.round(value);
  return months >= 1 && months <= 24 ? months : null;
}

export function normalizeAnalysis(analysis: ReportAnalysis): ReportAnalysis {
  analysis.reportDate = normalizeReportDate(analysis.reportDate);
  analysis.followUpMonths = clampFollowUpMonths(analysis.followUpMonths);
  return analysis;
}
