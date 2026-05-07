import { describe, it, expect } from "bun:test";
import {
  Secret,
  RotationStatus,
  detectExpiredSecrets,
  generateMarkdownReport,
  generateJsonReport,
} from "./validator";

describe("Secret Rotation Validator", () => {
  describe("detectExpiredSecrets", () => {
    it("should identify a secret as expired when last-rotated is beyond rotation-policy days", () => {
      // Test fixture: secret rotated 45 days ago with 30-day policy
      const now = new Date("2026-05-06");
      const lastRotated = new Date("2026-03-22"); // 45 days before now

      const secret: Secret = {
        name: "db-password",
        lastRotated,
        rotationPolicyDays: 30,
        requiredBy: ["api-service", "web-app"],
      };

      const result = detectExpiredSecrets([secret], 7, now);

      expect(result.expired).toHaveLength(1);
      expect(result.expired[0].name).toBe("db-password");
      expect(result.expired[0].status).toBe(RotationStatus.EXPIRED);
    });

    it("should identify a secret as warning when within the warning window", () => {
      const now = new Date("2026-05-06");
      // Secret rotated 25 days ago with 30-day policy, 5 days until expiry
      const lastRotated = new Date("2026-04-11");

      const secret: Secret = {
        name: "api-key",
        lastRotated,
        rotationPolicyDays: 30,
        requiredBy: ["auth-service"],
      };

      const result = detectExpiredSecrets([secret], 7, now); // 7-day warning window

      expect(result.warning).toHaveLength(1);
      expect(result.warning[0].name).toBe("api-key");
      expect(result.warning[0].status).toBe(RotationStatus.WARNING);
      expect(result.warning[0].daysUntilExpiry).toBe(5);
    });

    it("should identify a secret as ok when not expiring soon", () => {
      const now = new Date("2026-05-06");
      // Secret rotated 10 days ago with 30-day policy, 20 days until expiry
      const lastRotated = new Date("2026-04-26");

      const secret: Secret = {
        name: "jwt-secret",
        lastRotated,
        rotationPolicyDays: 30,
        requiredBy: ["api-service"],
      };

      const result = detectExpiredSecrets([secret], 7, now); // 7-day warning window

      expect(result.ok).toHaveLength(1);
      expect(result.ok[0].name).toBe("jwt-secret");
      expect(result.ok[0].status).toBe(RotationStatus.OK);
      expect(result.ok[0].daysUntilExpiry).toBe(20);
    });

    it("should categorize multiple secrets correctly", () => {
      const now = new Date("2026-05-06");

      const secrets: Secret[] = [
        {
          name: "expired-secret",
          lastRotated: new Date("2026-03-22"), // 45 days old, 30-day policy = expired
          rotationPolicyDays: 30,
          requiredBy: ["service1"],
        },
        {
          name: "warning-secret",
          lastRotated: new Date("2026-04-11"), // 25 days old, 30-day policy, within 7-day window
          rotationPolicyDays: 30,
          requiredBy: ["service2"],
        },
        {
          name: "ok-secret",
          lastRotated: new Date("2026-04-26"), // 10 days old, 30-day policy
          rotationPolicyDays: 30,
          requiredBy: ["service3"],
        },
      ];

      const result = detectExpiredSecrets(secrets, 7, now);

      expect(result.expired).toHaveLength(1);
      expect(result.warning).toHaveLength(1);
      expect(result.ok).toHaveLength(1);
    });

    it("should correctly calculate daysOld", () => {
      const now = new Date("2026-05-06");
      const lastRotated = new Date("2026-05-01"); // 5 days ago

      const secret: Secret = {
        name: "test-secret",
        lastRotated,
        rotationPolicyDays: 30,
        requiredBy: ["service"],
      };

      const result = detectExpiredSecrets([secret], 7, now);
      const status = result.ok[0];

      expect(status.daysOld).toBe(5);
    });

    it("should include all required metadata in the report", () => {
      const now = new Date("2026-05-06");
      const lastRotated = new Date("2026-04-26");

      const secret: Secret = {
        name: "complete-secret",
        lastRotated,
        rotationPolicyDays: 30,
        requiredBy: ["service1", "service2"],
      };

      const result = detectExpiredSecrets([secret], 7, now);
      const status = result.ok[0];

      expect(status.name).toBe("complete-secret");
      expect(status.rotationPolicyDays).toBe(30);
      expect(status.requiredBy).toEqual(["service1", "service2"]);
      expect(status.lastRotated).toEqual(lastRotated);
    });
  });

  describe("generateMarkdownReport", () => {
    it("should generate markdown tables for each urgency category", () => {
      const now = new Date("2026-05-06");
      const secrets: Secret[] = [
        {
          name: "expired-secret",
          lastRotated: new Date("2026-03-22"),
          rotationPolicyDays: 30,
          requiredBy: ["service1"],
        },
        {
          name: "warning-secret",
          lastRotated: new Date("2026-04-11"),
          rotationPolicyDays: 30,
          requiredBy: ["service2"],
        },
        {
          name: "ok-secret",
          lastRotated: new Date("2026-04-26"),
          rotationPolicyDays: 30,
          requiredBy: ["service3"],
        },
      ];

      const report = detectExpiredSecrets(secrets, 7, now);
      const markdown = generateMarkdownReport(report);

      expect(markdown).toContain("## 🔴 Expired Secrets");
      expect(markdown).toContain("## 🟡 Warning");
      expect(markdown).toContain("## 🟢 OK");
      expect(markdown).toContain("expired-secret");
      expect(markdown).toContain("warning-secret");
      expect(markdown).toContain("ok-secret");
    });

    it("should include proper markdown table headers and separators", () => {
      const now = new Date("2026-05-06");
      const secret: Secret = {
        name: "test-secret",
        lastRotated: new Date("2026-04-26"),
        rotationPolicyDays: 30,
        requiredBy: ["service"],
      };

      const report = detectExpiredSecrets([secret], 7, now);
      const markdown = generateMarkdownReport(report);

      expect(markdown).toContain("| Name");
      expect(markdown).toContain("| Days Old");
      expect(markdown).toContain("| Days Until Expiry");
      expect(markdown).toContain("|---");
    });

    it("should only show sections with secrets", () => {
      const now = new Date("2026-05-06");
      const secret: Secret = {
        name: "ok-secret",
        lastRotated: new Date("2026-04-26"),
        rotationPolicyDays: 30,
        requiredBy: ["service"],
      };

      const report = detectExpiredSecrets([secret], 7, now);
      const markdown = generateMarkdownReport(report);

      expect(markdown).not.toContain("## 🔴 Expired Secrets");
      expect(markdown).not.toContain("## 🟡 Warning");
      expect(markdown).toContain("## 🟢 OK");
    });
  });

  describe("generateJsonReport", () => {
    it("should serialize report to JSON with proper structure", () => {
      const now = new Date("2026-05-06");
      const secrets: Secret[] = [
        {
          name: "test-secret",
          lastRotated: new Date("2026-04-26"),
          rotationPolicyDays: 30,
          requiredBy: ["service1", "service2"],
        },
      ];

      const report = detectExpiredSecrets(secrets, 7, now);
      const jsonStr = generateJsonReport(report);
      const parsed = JSON.parse(jsonStr);

      expect(parsed.ok).toBeDefined();
      expect(parsed.ok[0].name).toBe("test-secret");
      expect(parsed.ok[0].requiredBy).toEqual(["service1", "service2"]);
    });

    it("should include generatedAt timestamp in JSON", () => {
      const now = new Date("2026-05-06T12:00:00Z");
      const secret: Secret = {
        name: "test-secret",
        lastRotated: new Date("2026-04-26"),
        rotationPolicyDays: 30,
        requiredBy: ["service"],
      };

      const report = detectExpiredSecrets([secret], 7, now);
      const jsonStr = generateJsonReport(report);
      const parsed = JSON.parse(jsonStr);

      expect(parsed.generatedAt).toBeDefined();
      expect(typeof parsed.generatedAt).toBe("string");
    });

    it("should produce valid JSON that can be round-tripped", () => {
      const now = new Date("2026-05-06");
      const secrets: Secret[] = [
        {
          name: "secret1",
          lastRotated: new Date("2026-03-22"),
          rotationPolicyDays: 30,
          requiredBy: ["svc1"],
        },
        {
          name: "secret2",
          lastRotated: new Date("2026-04-26"),
          rotationPolicyDays: 30,
          requiredBy: ["svc2"],
        },
      ];

      const report = detectExpiredSecrets(secrets, 7, now);
      const jsonStr = generateJsonReport(report);

      expect(() => JSON.parse(jsonStr)).not.toThrow();
      const parsed = JSON.parse(jsonStr);
      expect(parsed.expired.length + parsed.warning.length + parsed.ok.length).toBe(2);
    });
  });
});
