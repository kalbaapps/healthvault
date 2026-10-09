import assert from "node:assert/strict";
import { test } from "node:test";
import { detectMime } from "./mime.js";

const bytes = (...b: number[]) => Buffer.from(b);
const ascii = (s: string) => Buffer.from(s, "latin1");

test("recognises a PDF", () => {
  assert.equal(detectMime(ascii("%PDF-1.7\n...")), "application/pdf");
});

test("recognises PNG, JPEG and GIF", () => {
  assert.equal(detectMime(bytes(0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0)), "image/png");
  assert.equal(detectMime(bytes(0xff, 0xd8, 0xff, 0xe0, 0)), "image/jpeg");
  assert.equal(detectMime(ascii("GIF89a....")), "image/gif");
});

test("recognises WebP only when both RIFF and WEBP markers are present", () => {
  assert.equal(detectMime(Buffer.concat([ascii("RIFF"), bytes(1, 2, 3, 4), ascii("WEBPVP8 ")])), "image/webp");
  // A WAV file is RIFF too, but is not an image.
  assert.equal(detectMime(Buffer.concat([ascii("RIFF"), bytes(1, 2, 3, 4), ascii("WAVEfmt ")])), null);
});

test("rejects other files and empty or tiny buffers", () => {
  assert.equal(detectMime(ascii("MZ\u0090 an exe")), null);
  assert.equal(detectMime(ascii("<html></html>")), null);
  assert.equal(detectMime(Buffer.alloc(0)), null);
  assert.equal(detectMime(bytes(0x25, 0x50)), null);
});

test("a file with an image name but text inside is rejected", () => {
  assert.equal(detectMime(ascii("not really a picture")), null);
});
