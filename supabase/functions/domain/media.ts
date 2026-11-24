import { fail } from "./contracts.ts";

/** The recording format, read from the bytes and not the file name. */
export function audioKind(bytes: Uint8Array) {
  const ascii = (offset: number, count: number) =>
    String.fromCharCode(...bytes.subarray(offset, offset + count));
  if (bytes.length < 24) return null;
  if (ascii(4, 4) === "ftyp") return { name: "meal.m4a", type: "audio/mp4" };
  if (bytes[0] === 0x1a && bytes[1] === 0x45 && bytes[2] === 0xdf && bytes[3] === 0xa3) {
    return { name: "meal.webm", type: "audio/webm" };
  }
  if (ascii(0, 4) === "RIFF" && ascii(8, 4) === "WAVE") return { name: "meal.wav", type: "audio/wav" };
  return null;
}

// The mobile app transcodes images. Direct API clients may upload other supported formats.
/** Drops everything but the picture itself, such as EXIF, text chunks and location. */
export function stripImageMetadata(bytes: Uint8Array, mime: string) {
  if (mime === "image/jpeg") return stripJpegMetadata(bytes);
  const png = mime === "image/png";
  const header = png ? 8 : 12;
  const kept = png
    ? new Set(["IHDR", "PLTE", "IDAT", "IEND", "tRNS", "sRGB", "gAMA", "cHRM"])
    : new Set(["VP8X", "VP8 ", "VP8L", "ALPH"]);
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const clean = new Uint8Array(bytes.length);
  clean.set(bytes.subarray(0, header));
  let written = header;
  let hasImage = false;
  let ended = false;
  for (let offset = header; offset + (png ? 12 : 8) <= bytes.length;) {
    const kindAt = offset + (png ? 4 : 0);
    const kind = String.fromCharCode(...bytes.subarray(kindAt, kindAt + 4));
    const length = view.getUint32(offset + (png ? 0 : 4), !png);
    const end = offset + length + (png ? 12 : 8 + Number(length % 2 !== 0));
    if (end > bytes.length || kind === "ANIM" || kind === "ANMF") {
      return fail("IMAGE_TYPE", "Choose a readable, still JPEG, PNG or WebP.");
    }
    if (kept.has(kind)) {
      clean.set(bytes.subarray(offset, end), written);
      if (kind === "VP8X" && length === 10) clean[written + 8] &= 0x10;
      written += end - offset;
    }
    hasImage ||= kind === "IDAT" || kind === "VP8 " || kind === "VP8L";
    offset = end;
    if (kind === "IEND" || offset === bytes.length) {
      ended = !png || kind === "IEND";
      break;
    }
  }
  if (!hasImage || !ended) return fail("IMAGE_TYPE", "This picture could not be read. Choose another image.");
  if (!png) new DataView(clean.buffer).setUint32(4, written - 8, true);
  return clean.subarray(0, written);
}

export function stripJpegMetadata(bytes: Uint8Array) {
  const result = new Uint8Array(bytes.length);
  result.set(bytes.subarray(0, 2));
  let read = 2;
  let write = 2;
  while (read + 3 < bytes.length && bytes[read] === 0xff) {
    const marker = bytes[read + 1];
    if (marker === 0xda) {
      result.set(bytes.subarray(read), write);
      return result.subarray(0, write + bytes.length - read);
    }
    const length = bytes[read + 2] * 256 + bytes[read + 3];
    const end = read + length + 2;
    if (length < 2 || end > bytes.length) break;
    if (!(marker >= 0xe0 && marker <= 0xef) && marker !== 0xfe) {
      result.set(bytes.subarray(read, end), write);
      write += end - read;
    }
    read = end;
  }
  return fail("IMAGE_TYPE", "This JPEG could not be read. Choose another image.");
}
