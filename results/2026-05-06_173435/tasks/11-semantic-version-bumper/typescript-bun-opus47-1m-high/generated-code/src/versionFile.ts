// Reads/writes the project version. Two flavours:
//   - package.json (JSON, version key) — preserves other fields & 2-space indent
//   - plain text file (e.g. VERSION) — first non-empty line is the version

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { basename } from "node:path";

function isPackageJson(path: string): boolean {
  return basename(path).toLowerCase() === "package.json";
}

export function readVersionFile(path: string): string {
  if (!existsSync(path)) {
    throw new Error(`version file not found: ${path}`);
  }
  const raw = readFileSync(path, "utf8");

  if (isPackageJson(path)) {
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch (err) {
      throw new Error(`failed to parse ${path} as JSON: ${(err as Error).message}`);
    }
    if (
      !parsed ||
      typeof parsed !== "object" ||
      typeof (parsed as { version?: unknown }).version !== "string"
    ) {
      throw new Error(`package.json at ${path} has no string "version" field`);
    }
    return (parsed as { version: string }).version.trim();
  }

  const trimmed = raw.trim();
  if (!trimmed) {
    throw new Error(`version file ${path} is empty`);
  }
  return trimmed;
}

export function writeVersionFile(path: string, newVersion: string): void {
  if (isPackageJson(path)) {
    const raw = readFileSync(path, "utf8");
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    parsed.version = newVersion;
    // Preserve a stable 2-space indent (matches the most common convention,
    // and matches what `npm version` writes).
    writeFileSync(path, JSON.stringify(parsed, null, 2) + "\n", "utf8");
    return;
  }
  writeFileSync(path, `${newVersion}\n`, "utf8");
}
