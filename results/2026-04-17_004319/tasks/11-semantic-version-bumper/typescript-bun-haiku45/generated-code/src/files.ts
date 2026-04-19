// Reads the version from a package.json file
export async function readVersionFromPackageJson(
  filePath: string
): Promise<string> {
  try {
    const content = await Bun.file(filePath).text();
    const pkg = JSON.parse(content);
    if (!pkg.version) {
      throw new Error("No version field in package.json");
    }
    return pkg.version;
  } catch (error) {
    throw new Error(`Failed to read version from ${filePath}: ${error}`);
  }
}

// Updates the version in a package.json file
export async function updateVersionInPackageJson(
  filePath: string,
  newVersion: string
): Promise<void> {
  try {
    const content = await Bun.file(filePath).text();
    const pkg = JSON.parse(content);
    pkg.version = newVersion;
    await Bun.write(filePath, JSON.stringify(pkg, null, 2) + "\n");
  } catch (error) {
    throw new Error(`Failed to update version in ${filePath}: ${error}`);
  }
}
