import type { ReportAnalysis } from "./types.js";

/** Non-Latin scripts a result language may legitimately use for test names. */
const LANGUAGE_SCRIPTS: [RegExp, RegExp][] = [
  [/sinhala|සිංහල/i, /\p{Script=Sinhala}/u],
  [/tamil|தமிழ்/i, /\p{Script=Tamil}/u],
  [/hindi|हिन्दी/i, /\p{Script=Devanagari}/u],
  [/arabic|العربية/i, /\p{Script=Arabic}/u],
  [/chinese|中文/i, /\p{Script=Han}/u],
];

const IS_LETTER = /\p{L}/u;
const IS_LATIN = /\p{Script=Latin}/u;

/**
 * Vision models sometimes transcribe one Indic script as a visually similar
 * one (Sinhala printed, Kannada returned). A test name may only use Latin
 * letters or the requested language's script; anything else is replaced by
 * the standard English name so the user never sees garbled text.
 */
export function cleanNames(analysis: ReportAnalysis, language: string): ReportAnalysis {
  const allowed = LANGUAGE_SCRIPTS.find(([label]) => label.test(language))?.[1];

  for (const value of analysis.values) {
    const hasForeignScript = [...value.name].some(
      (ch) => IS_LETTER.test(ch) && !IS_LATIN.test(ch) && !(allowed && allowed.test(ch)),
    );
    if (hasForeignScript && value.canonicalName) {
      value.name = value.canonicalName;
    }
  }
  return analysis;
}
