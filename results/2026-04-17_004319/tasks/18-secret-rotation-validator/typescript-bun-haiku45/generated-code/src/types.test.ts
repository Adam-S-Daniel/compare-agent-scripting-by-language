import { describe, it, expect } from "bun:test";
import { Secret, validateSecret, RotationStatus } from "./types";

describe("Secret types and validation", () => {
  it("should validate a properly formatted secret", () => {
    const secret: Secret = {
      name: "database-password",
      lastRotated: new Date("2026-01-01"),
      rotationPolicyDays: 90,
      requiredByServices: ["api", "worker"],
    };

    const result = validateSecret(secret);
    expect(result.isValid).toBe(true);
    expect(result.errors).toEqual([]);
  });

  it("should reject secret with missing name", () => {
    const secret = {
      lastRotated: new Date("2026-01-01"),
      rotationPolicyDays: 90,
      requiredByServices: ["api"],
    } as any;

    const result = validateSecret(secret);
    expect(result.isValid).toBe(false);
    expect(result.errors.some(e => e.includes("name"))).toBe(true);
  });

  it("should reject secret with invalid rotationPolicyDays", () => {
    const secret = {
      name: "test",
      lastRotated: new Date("2026-01-01"),
      rotationPolicyDays: -5,
      requiredByServices: ["api"],
    } as any;

    const result = validateSecret(secret);
    expect(result.isValid).toBe(false);
    expect(result.errors.some(e => e.includes("rotationPolicyDays"))).toBe(true);
  });
});
