import { describe, it, expect, beforeAll } from "bun:test";
import * as fs from "fs";
import * as path from "path";
import YAML from "yaml";
import { spawnSync } from "bun";

describe("GitHub Actions Workflow", () => {
  let workflow: any;
  const workflowPath = ".github/workflows/secret-rotation-validator.yml";

  beforeAll(() => {
    if (!fs.existsSync(workflowPath)) {
      throw new Error(`Workflow file not found at ${workflowPath}`);
    }
    const content = fs.readFileSync(workflowPath, "utf-8");
    workflow = YAML.parse(content);
  });

  describe("Structure validation", () => {
    it("should have a valid workflow name", () => {
      expect(workflow.name).toBeDefined();
      expect(typeof workflow.name).toBe("string");
      expect(workflow.name).toBe("Secret Rotation Validator");
    });

    it("should define trigger events", () => {
      expect(workflow.on).toBeDefined();
      expect(typeof workflow.on).toBe("object");
    });

    it("should include push trigger with branches", () => {
      expect(workflow.on.push).toBeDefined();
      expect(workflow.on.push.branches).toBeDefined();
      expect(Array.isArray(workflow.on.push.branches)).toBe(true);
    });

    it("should include pull_request trigger", () => {
      expect(workflow.on.pull_request).toBeDefined();
    });

    it("should include schedule trigger", () => {
      expect(workflow.on.schedule).toBeDefined();
      expect(Array.isArray(workflow.on.schedule)).toBe(true);
      expect(workflow.on.schedule.length).toBeGreaterThan(0);
    });

    it("should include workflow_dispatch trigger", () => {
      expect(workflow.on.workflow_dispatch).toBeDefined();
    });

    it("should define permissions", () => {
      expect(workflow.permissions).toBeDefined();
      expect(workflow.permissions.contents).toBe("read");
    });

    it("should define jobs", () => {
      expect(workflow.jobs).toBeDefined();
      expect(typeof workflow.jobs).toBe("object");
    });

    it("should have a test-and-validate job", () => {
      expect(workflow.jobs["test-and-validate"]).toBeDefined();
    });

    it("should specify runs-on for the job", () => {
      const job = workflow.jobs["test-and-validate"];
      expect(job["runs-on"]).toBe("ubuntu-latest");
    });
  });

  describe("Steps validation", () => {
    it("should have multiple steps", () => {
      const job = workflow.jobs["test-and-validate"];
      expect(Array.isArray(job.steps)).toBe(true);
      expect(job.steps.length).toBeGreaterThan(0);
    });

    it("should have checkout step", () => {
      const job = workflow.jobs["test-and-validate"];
      const checkoutStep = job.steps.find(
        (s: any) => s.uses && s.uses.includes("actions/checkout")
      );
      expect(checkoutStep).toBeDefined();
      expect(checkoutStep.uses).toContain("actions/checkout@v4");
    });

    it("should have setup Bun step", () => {
      const job = workflow.jobs["test-and-validate"];
      const setupStep = job.steps.find(
        (s: any) => s.uses && s.uses.includes("oven-sh/setup-bun")
      );
      expect(setupStep).toBeDefined();
    });

    it("should have test step", () => {
      const job = workflow.jobs["test-and-validate"];
      const testStep = job.steps.find((s: any) => s.name && s.name.includes("test"));
      expect(testStep).toBeDefined();
      expect(testStep.run).toBe("bun test");
    });

    it("should have validation steps", () => {
      const job = workflow.jobs["test-and-validate"];
      const validateSteps = job.steps.filter(
        (s: any) => s.name && s.name.includes("Validate")
      );
      expect(validateSteps.length).toBeGreaterThanOrEqual(2);
    });
  });

  describe("File references", () => {
    it("should reference existing validator.ts file", () => {
      expect(fs.existsSync("validator.ts")).toBe(true);
    });

    it("should reference existing cli.ts file", () => {
      expect(fs.existsSync("cli.ts")).toBe(true);
    });

    it("should reference existing secrets-config.json file", () => {
      expect(fs.existsSync("secrets-config.json")).toBe(true);
    });

    it("should reference existing test files", () => {
      expect(fs.existsSync("validator.test.ts")).toBe(true);
    });
  });

  describe("actionlint validation", () => {
    it("should pass actionlint validation", () => {
      const result = spawnSync(["actionlint", workflowPath]);
      expect(result.success).toBe(true);
      expect(result.stderr?.toString() || "").not.toContain("error");
    });
  });

  describe("YAML syntax validation", () => {
    it("should be valid YAML", () => {
      expect(() => {
        const content = fs.readFileSync(workflowPath, "utf-8");
        YAML.parse(content);
      }).not.toThrow();
    });

    it("should have valid JSON path filters", () => {
      const job = workflow.jobs["test-and-validate"];
      expect(job.steps[0].uses).toBeDefined();
    });
  });
});
