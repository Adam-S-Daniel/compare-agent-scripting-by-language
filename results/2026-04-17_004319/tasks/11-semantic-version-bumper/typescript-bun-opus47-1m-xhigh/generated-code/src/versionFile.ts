// Version-file I/O. Supports both `package.json` (JSON with a top-level
// "version" field) and a plain "VERSION" file whose entire contents are the
// version string.
//
// We detect the format by the path's basename ending in ".json"; everything
// else is treated as plain text.

import { readFile, writeFile } from "node:fs/promises";
import { basename } from "node:path";

function isJson(path: string): boolean {
  return basename(path).endsWith(".json");
}

export async function readVersionFile(path: string): Promise<string> {
  const raw = await readFile(path, "utf8");
  if (isJson(path)) {
    const parsed = JSON.parse(raw) as { version?: unknown };
    if (typeof parsed.version !== "string") {
      throw new Error(`package.json at ${path} has no "version" field`);
    }
    return parsed.version;
  }
  return raw.trim();
}

export async function writeVersionFile(path: string, version: string): Promise<void> {
  if (isJson(path)) {
    const raw = await readFile(path, "utf8");
    const parsed = JSON.parse(raw);
    parsed.version = version;
    // Preserve a two-space indent (npm convention) and a trailing newline.
    await writeFile(path, JSON.stringify(parsed, null, 2) + "\n");
    return;
  }
  await writeFile(path, `${version}\n`);
}
