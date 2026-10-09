export type SupportedMime =
  | "application/pdf"
  | "image/png"
  | "image/jpeg"
  | "image/gif"
  | "image/webp";

const startsWith = (buf: Buffer, bytes: number[], offset = 0) =>
  buf.length >= offset + bytes.length && bytes.every((b, i) => buf[offset + i] === b);

/**
 * Identifies an uploaded file from its first bytes. The type a client declares
 * is not trusted: phones often send "application/octet-stream" for photos
 * picked from the gallery, and a declared type says nothing about the content.
 */
export function detectMime(buf: Buffer): SupportedMime | null {
  if (startsWith(buf, [0x25, 0x50, 0x44, 0x46])) return "application/pdf"; // %PDF
  if (startsWith(buf, [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return "image/png";
  if (startsWith(buf, [0xff, 0xd8, 0xff])) return "image/jpeg";
  if (startsWith(buf, [0x47, 0x49, 0x46, 0x38])) return "image/gif"; // GIF8
  if (startsWith(buf, [0x52, 0x49, 0x46, 0x46]) && startsWith(buf, [0x57, 0x45, 0x42, 0x50], 8)) {
    return "image/webp"; // RIFF....WEBP
  }
  return null;
}
