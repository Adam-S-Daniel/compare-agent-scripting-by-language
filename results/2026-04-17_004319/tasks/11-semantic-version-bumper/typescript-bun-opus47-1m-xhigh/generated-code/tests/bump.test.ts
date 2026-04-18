// End-to-end tests for the orchestrator `runBump`, which glues together all
// the other modules. These also double as tests for the CLI's behavior since
// the CLI is a thin wrapper around `runBump`.

import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { runBump } from "../src/bump.ts";

let workDir: string;
beforeEach(async () => {
  workDir = await mkdtemp(join(tmpdir(), "svb-e2e-"));
});
afterEach(async () => {
  await rm(workDir, { recursive: true, force: true });
});

async function setup(version: string, kind: "json" | "plain" = "json"): Promise<{ versionPath: string; changelogPath: string }> {
  const versionPath = kind === "json" ? join(workDir, "package.json") : join(workDir, "VERSION");
  const changelogPath = join(workDir, "CHANGELOG.md");
  if (kind === "json") {
    await writeFile(versionPath, JSON.stringify({ name: "test", version }, null, 2));
  } else {
    await writeFile(versionPath, `${version}\n`);
  }
  return { versionPath, changelogPath };
}

describe("runBump (end-to-end)", () => {
  test("feat commit on 1.1.0 produces 1.2.0 and prepends changelog", async () => {
    const { versionPath, changelogPath } = await setup("1.1.0");
    const commitLog = "feat: add login\n\nfix: trivial tweak";
    const result = await runBump({
      versionPath,
      changelogPath,
      commitLog,
      date: "2026-04-17",
    });
    expect(result.oldVersion).toBe("1.1.0");
    expect(result.newVersion).toBe("1.2.0");
    expect(result.bump).toBe("minor");

    const pkg = JSON.parse(await readFile(versionPath, "utf8"));
    expect(pkg.version).toBe("1.2.0");

    const changelog = await readFile(changelogPath, "utf8");
    expect(changelog).toContain("## [1.2.0] - 2026-04-17");
    expect(changelog).toContain("### Features");
    expect(changelog).toContain("- add login");
    expect(changelog).toContain("### Bug fixes");
    expect(changelog).toContain("- trivial tweak");
  });

  test("fix-only commits on 1.1.0 produce 1.1.1 (patch)", async () => {
    const { versionPath, changelogPath } = await setup("1.1.0");
    const result = await runBump({
      versionPath,
      changelogPath,
      commitLog: "fix: correct typo",
      date: "2026-04-17",
    });
    expect(result.newVersion).toBe("1.1.1");
    expect(result.bump).toBe("patch");
  });

  test("a '!' commit on 2.3.4 produces 3.0.0 (major)", async () => {
    const { versionPath, changelogPath } = await setup("2.3.4");
    const result = await runBump({
      versionPath,
      changelogPath,
      commitLog: "feat!: drop legacy API",
      date: "2026-04-17",
    });
    expect(result.newVersion).toBe("3.0.0");
    expect(result.bump).toBe("major");
    const changelog = await readFile(changelogPath, "utf8");
    expect(changelog).toContain("### Breaking changes");
  });

  test("no meaningful commits leaves version unchanged and does not write", async () => {
    const { versionPath, changelogPath } = await setup("0.5.0");
    const result = await runBump({
      versionPath,
      changelogPath,
      commitLog: "chore: bump deps\n\ndocs: add notes",
      date: "2026-04-17",
    });
    expect(result.newVersion).toBe("0.5.0");
    expect(result.bump).toBe("none");
    const pkg = JSON.parse(await readFile(versionPath, "utf8"));
    expect(pkg.version).toBe("0.5.0");

    // No changelog file should be created in no-op mode.
    const changelogExists = await readFile(changelogPath).then(() => true).catch(() => false);
    expect(changelogExists).toBe(false);
  });

  test("plain VERSION file works too", async () => {
    const { versionPath, changelogPath } = await setup("0.1.0", "plain");
    const result = await runBump({
      versionPath,
      changelogPath,
      commitLog: "fix: minor tweak",
      date: "2026-04-17",
    });
    expect(result.newVersion).toBe("0.1.1");
    expect(await readFile(versionPath, "utf8")).toBe("0.1.1\n");
  });

  test("prepends to an existing CHANGELOG.md without clobbering its header", async () => {
    const { versionPath, changelogPath } = await setup("1.0.0");
    const existing =
      "# Changelog\n\nAll notable changes to this project.\n\n## [0.9.0] - 2026-01-01\n- legacy entry\n";
    await writeFile(changelogPath, existing);

    await runBump({
      versionPath,
      changelogPath,
      commitLog: "feat: new thing",
      date: "2026-04-17",
    });
    const updated = await readFile(changelogPath, "utf8");
    expect(updated.startsWith("# Changelog\n")).toBe(true);
    expect(updated).toContain("## [1.1.0] - 2026-04-17");
    expect(updated).toContain("## [0.9.0] - 2026-01-01");
    // New entry must appear before the old entry.
    expect(updated.indexOf("## [1.1.0]")).toBeLessThan(updated.indexOf("## [0.9.0]"));
  });
});
