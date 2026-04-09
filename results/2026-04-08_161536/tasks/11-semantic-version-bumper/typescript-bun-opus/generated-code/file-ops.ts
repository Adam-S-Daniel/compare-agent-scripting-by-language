// File I/O operations for reading and writing version information

import { join } from "node:path";

/** Read the version field from package.json in the given directory */
export async function readVersionFromPackageJson(dir: string): Promise<string> {
  const filePath = join(dir, "package.json");
  const file = Bun.file(filePath);
  const content = await file.json();
  if (!content.version) {
    throw new Error(`No version field found in ${filePath}`);
  }
  return content.version;
}

/** Write a new version to package.json, preserving all other fields */
export async function writeVersionToPackageJson(
  dir: string,
  version: string
): Promise<void> {
  const filePath = join(dir, "package.json");
  const content = JSON.parse(await Bun.file(filePath).text());
  content.version = version;
  await Bun.write(filePath, JSON.stringify(content, null, 2) + "\n");
}

/** Read version from a plain text VERSION file */
export async function readVersionFile(filePath: string): Promise<string> {
  const content = await Bun.file(filePath).text();
  return content.trim();
}

/** Write version to a plain text VERSION file */
export async function writeVersionFile(
  filePath: string,
  version: string
): Promise<void> {
  await Bun.write(filePath, version + "\n");
}
