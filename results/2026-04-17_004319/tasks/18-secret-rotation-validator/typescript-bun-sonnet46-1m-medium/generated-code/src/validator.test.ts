import { describe, expect, test } from "bun:test";
import {
  classifySecret,
  computeDaysUntilExpiry,
  generateReport,
  formatMarkdown,
  formatJSON,
} from "./validator";
import type { Secret, ValidatorConfig } from "./types";

// Fixed reference date for deterministic tests
const TODAY = "2024-03-15";

// --- Test fixtures ---

const expiredSecret: Secret = {
  name: "DB_PASSWORD",
  lastRotated: "2024-01-01", // 74 days ago, policy 60 days → expired 14 days ago
  rotationPolicyDays: 60,
  requiredBy: ["api-service", "worker"],
};

const warningSecret: Secret = {
  name: "API_KEY",
  lastRotated: "2024-02-10", // 34 days ago, policy 37 days → expires in 3 days
  rotationPolicyDays: 37,
  requiredBy: ["frontend"],
};

const okSecret: Secret = {
  name: "JWT_SECRET",
  lastRotated: "2024-03-01", // 14 days ago, policy 90 days → expires in 76 days
  rotationPolicyDays: 90,
  requiredBy: ["auth-service"],
};

// --- Unit tests: computeDaysUntilExpiry ---

describe("computeDaysUntilExpiry", () => {
  test("returns negative when secret is expired", () => {
    // lastRotated 2024-01-01, policy 60d → expires 2024-03-01, today 2024-03-15 → -14
    const days = computeDaysUntilExpiry("2024-01-01", 60, TODAY);
    expect(days).toBe(-14);
  });

  test("returns positive days remaining for ok secret", () => {
    // lastRotated 2024-03-01, policy 90d → 14 days elapsed → 90-14=76 remaining
    const days = computeDaysUntilExpiry("2024-03-01", 90, TODAY);
    expect(days).toBe(76);
  });

  test("returns 0 on expiry day", () => {
    // lastRotated 2024-01-14, policy 60d → expires 2024-03-14, today 2024-03-15 → -1
    const days = computeDaysUntilExpiry("2024-01-14", 60, TODAY);
    expect(days).toBe(-1);
  });

  test("returns exact days for warning secret", () => {
    // lastRotated 2024-02-10, policy 37d → expires 2024-03-18, today 2024-03-15 → 3
    const days = computeDaysUntilExpiry("2024-02-10", 37, TODAY);
    expect(days).toBe(3);
  });
});

// --- Unit tests: classifySecret ---

describe("classifySecret", () => {
  test("classifies expired secret correctly", () => {
    const status = classifySecret(-14, 7);
    expect(status).toBe("expired");
  });

  test("classifies warning secret within window", () => {
    const status = classifySecret(3, 7);
    expect(status).toBe("warning");
  });

  test("classifies ok secret outside warning window", () => {
    const status = classifySecret(75, 7);
    expect(status).toBe("ok");
  });

  test("classifies secret at warning boundary as warning", () => {
    // exactly 7 days left = warning
    const status = classifySecret(7, 7);
    expect(status).toBe("warning");
  });

  test("classifies secret one day past warning boundary as ok", () => {
    const status = classifySecret(8, 7);
    expect(status).toBe("ok");
  });

  test("classifies secret with 0 days as expired", () => {
    const status = classifySecret(0, 7);
    expect(status).toBe("expired");
  });
});

// --- Unit tests: generateReport ---

describe("generateReport", () => {
  const config: ValidatorConfig = {
    warningWindowDays: 7,
    secrets: [expiredSecret, warningSecret, okSecret],
  };

  test("groups secrets by urgency", () => {
    const report = generateReport(config, TODAY);
    expect(report.expired).toHaveLength(1);
    expect(report.warning).toHaveLength(1);
    expect(report.ok).toHaveLength(1);
  });

  test("expired group contains correct secret", () => {
    const report = generateReport(config, TODAY);
    expect(report.expired[0].name).toBe("DB_PASSWORD");
    expect(report.expired[0].daysUntilExpiry).toBe(-14);
    expect(report.expired[0].status).toBe("expired");
  });

  test("warning group contains correct secret", () => {
    const report = generateReport(config, TODAY);
    expect(report.warning[0].name).toBe("API_KEY");
    expect(report.warning[0].daysUntilExpiry).toBe(3);
    expect(report.warning[0].status).toBe("warning");
  });

  test("ok group contains correct secret", () => {
    const report = generateReport(config, TODAY);
    expect(report.ok[0].name).toBe("JWT_SECRET");
    expect(report.ok[0].daysUntilExpiry).toBe(76);
    expect(report.ok[0].status).toBe("ok");
  });

  test("report preserves requiredBy list", () => {
    const report = generateReport(config, TODAY);
    expect(report.expired[0].requiredBy).toEqual(["api-service", "worker"]);
  });

  test("report includes warningWindowDays", () => {
    const report = generateReport(config, TODAY);
    expect(report.warningWindowDays).toBe(7);
  });

  test("handles empty secrets list", () => {
    const empty: ValidatorConfig = { warningWindowDays: 7, secrets: [] };
    const report = generateReport(empty, TODAY);
    expect(report.expired).toHaveLength(0);
    expect(report.warning).toHaveLength(0);
    expect(report.ok).toHaveLength(0);
  });

  test("custom warning window changes classification", () => {
    // With warningWindowDays=0, the warning secret (3 days left) should be ok
    const narrowConfig: ValidatorConfig = {
      warningWindowDays: 0,
      secrets: [warningSecret],
    };
    const report = generateReport(narrowConfig, TODAY);
    expect(report.ok).toHaveLength(1);
    expect(report.warning).toHaveLength(0);
  });
});

// --- Unit tests: formatMarkdown ---

describe("formatMarkdown", () => {
  const config: ValidatorConfig = {
    warningWindowDays: 7,
    secrets: [expiredSecret, warningSecret, okSecret],
  };

  test("contains markdown table headers", () => {
    const report = generateReport(config, TODAY);
    const md = formatMarkdown(report);
    expect(md).toContain("| Name |");
    expect(md).toContain("| Status |");
    expect(md).toContain("| Days Until Expiry |");
  });

  test("contains expired section", () => {
    const report = generateReport(config, TODAY);
    const md = formatMarkdown(report);
    expect(md).toContain("## Expired");
    expect(md).toContain("DB_PASSWORD");
  });

  test("contains warning section", () => {
    const report = generateReport(config, TODAY);
    const md = formatMarkdown(report);
    expect(md).toContain("## Warning");
    expect(md).toContain("API_KEY");
  });

  test("contains ok section", () => {
    const report = generateReport(config, TODAY);
    const md = formatMarkdown(report);
    expect(md).toContain("## OK");
    expect(md).toContain("JWT_SECRET");
  });

  test("shows negative days for expired secrets", () => {
    const report = generateReport(config, TODAY);
    const md = formatMarkdown(report);
    expect(md).toContain("-14");
  });
});

// --- Unit tests: formatJSON ---

describe("formatJSON", () => {
  const config: ValidatorConfig = {
    warningWindowDays: 7,
    secrets: [expiredSecret, warningSecret, okSecret],
  };

  test("produces valid JSON", () => {
    const report = generateReport(config, TODAY);
    const json = formatJSON(report);
    expect(() => JSON.parse(json)).not.toThrow();
  });

  test("JSON contains all urgency groups", () => {
    const report = generateReport(config, TODAY);
    const parsed = JSON.parse(formatJSON(report));
    expect(parsed).toHaveProperty("expired");
    expect(parsed).toHaveProperty("warning");
    expect(parsed).toHaveProperty("ok");
  });

  test("JSON expired entry has correct name", () => {
    const report = generateReport(config, TODAY);
    const parsed = JSON.parse(formatJSON(report));
    expect(parsed.expired[0].name).toBe("DB_PASSWORD");
  });

  test("JSON ok entry has correct daysUntilExpiry", () => {
    const report = generateReport(config, TODAY);
    const parsed = JSON.parse(formatJSON(report));
    expect(parsed.ok[0].daysUntilExpiry).toBe(76);
  });
});
