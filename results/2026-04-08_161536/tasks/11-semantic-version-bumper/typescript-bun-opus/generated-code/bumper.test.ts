// Integration tests for the bumper orchestrator

import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { mkdtemp, rm } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { runBumper } from "./bumper";
import {
  FIXTURE_PATCH_ONLY,
  FIXTURE_MINOR_WITH_FIXES,
  FIXTURE_MAJOR_BREAKING,
  FIXTURE_EMPTY,
} from "./fixtures";

let tempDir: string;

beforeEach(async () => {
  tempDir = await mkdtemp(join(tmpdir(), "bumper-test-"));
});

afterEach(async () => {
  await rm(tempDir, { recursive: true, force: true });
});

describe("runBumper with package.json", () => {
  test("bumps patch version for fix commits", async () => {
    await Bun.write(
      join(tempDir, "package.json"),
      JSON.stringify({ name: "test", version: "1.0.0" }, null, 2)
    );
    const result = await runBumper({
      dir: tempDir,
      dryRun: false,
      commitLog: FIXTURE_PATCH_ONLY,
    });
    expect(result.previousVersion).toBe("1.0.0");
    expect(result.newVersion).toBe("1.0.1");
    expect(result.bumpType).toBe("patch");

    // Verify file was updated
    const pkg = JSON.parse(await Bun.file(join(tempDir, "package.json")).text());
    expect(pkg.version).toBe("1.0.1");
  });

  test("bumps minor version for feat commits", async () => {
    await Bun.write(
      join(tempDir, "package.json"),
      JSON.stringify({ name: "test", version: "2.1.5" }, null, 2)
    );
    const result = await runBumper({
      dir: tempDir,
      dryRun: false,
      commitLog: FIXTURE_MINOR_WITH_FIXES,
    });
    expect(result.newVersion).toBe("2.2.0");
    expect(result.bumpType).toBe("minor");
  });

  test("bumps major version for breaking changes", async () => {
    await Bun.write(
      join(tempDir, "package.json"),
      JSON.stringify({ name: "test", version: "1.5.3" }, null, 2)
    );
    const result = await runBumper({
      dir: tempDir,
      dryRun: false,
      commitLog: FIXTURE_MAJOR_BREAKING,
    });
    expect(result.newVersion).toBe("2.0.0");
    expect(result.bumpType).toBe("major");
  });

  test("creates CHANGELOG.md with entry", async () => {
    await Bun.write(
      join(tempDir, "package.json"),
      JSON.stringify({ name: "test", version: "1.0.0" }, null, 2)
    );
    await runBumper({
      dir: tempDir,
      dryRun: false,
      commitLog: FIXTURE_MINOR_WITH_FIXES,
    });
    const changelog = await Bun.file(join(tempDir, "CHANGELOG.md")).text();
    expect(changelog).toContain("## 1.1.0");
    expect(changelog).toContain("### Features");
    expect(changelog).toContain("dark mode toggle");
  });

  test("dry run does not modify files", async () => {
    await Bun.write(
      join(tempDir, "package.json"),
      JSON.stringify({ name: "test", version: "1.0.0" }, null, 2)
    );
    const result = await runBumper({
      dir: tempDir,
      dryRun: true,
      commitLog: FIXTURE_PATCH_ONLY,
    });
    expect(result.newVersion).toBe("1.0.1");

    // File should still have old version
    const pkg = JSON.parse(await Bun.file(join(tempDir, "package.json")).text());
    expect(pkg.version).toBe("1.0.0");
  });

  test("throws when no bumpable commits exist", async () => {
    await Bun.write(
      join(tempDir, "package.json"),
      JSON.stringify({ name: "test", version: "1.0.0" }, null, 2)
    );
    await expect(
      runBumper({ dir: tempDir, dryRun: false, commitLog: FIXTURE_EMPTY })
    ).rejects.toThrow("No version-bumping commits found");
  });
});

describe("runBumper with VERSION file", () => {
  test("reads and writes a plain VERSION file", async () => {
    const versionFile = join(tempDir, "VERSION");
    await Bun.write(versionFile, "3.2.1\n");
    // Need package.json for changelog dir context but version from VERSION file
    await Bun.write(join(tempDir, "package.json"), "{}");

    const result = await runBumper({
      dir: tempDir,
      versionFile,
      dryRun: false,
      commitLog: FIXTURE_PATCH_ONLY,
    });
    expect(result.previousVersion).toBe("3.2.1");
    expect(result.newVersion).toBe("3.2.2");

    const updated = (await Bun.file(versionFile).text()).trim();
    expect(updated).toBe("3.2.2");
  });
});
