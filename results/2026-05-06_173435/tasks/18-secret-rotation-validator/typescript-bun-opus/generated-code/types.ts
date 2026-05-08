export interface SecretConfig {
  name: string;
  lastRotated: string;
  rotationPolicyDays: number;
  requiredBy: string[];
}

export interface ValidationConfig {
  secrets: SecretConfig[];
  warningWindowDays: number;
  referenceDate?: string;
}

export type Urgency = "expired" | "warning" | "ok";

export interface SecretStatus {
  name: string;
  urgency: Urgency;
  daysSinceRotation: number;
  daysUntilExpiry: number;
  expiryDate: string;
  requiredBy: string[];
  rotationPolicyDays: number;
  lastRotated: string;
}

export interface RotationReport {
  generatedAt: string;
  warningWindowDays: number;
  secrets: SecretStatus[];
  summary: {
    total: number;
    expired: number;
    warning: number;
    ok: number;
  };
}
