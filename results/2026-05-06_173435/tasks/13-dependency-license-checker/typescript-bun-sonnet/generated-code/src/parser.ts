import type { Dependency } from './types';

// Parse a package.json string and extract all dependencies + devDependencies
export function parsePackageJson(content: string): Dependency[] {
  const pkg = JSON.parse(content); // throws SyntaxError on invalid JSON
  const deps: Dependency[] = [];

  for (const section of ['dependencies', 'devDependencies', 'peerDependencies']) {
    const block = pkg[section];
    if (block && typeof block === 'object') {
      for (const [name, version] of Object.entries(block)) {
        deps.push({ name, version: String(version) });
      }
    }
  }

  return deps;
}
