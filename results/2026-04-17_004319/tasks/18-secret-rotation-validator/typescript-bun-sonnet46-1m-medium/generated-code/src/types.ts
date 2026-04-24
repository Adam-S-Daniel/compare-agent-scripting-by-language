// Core types for the secret rotation validator

export interface Secret {
  name: string;
  lastRotated: string; // ISO date string YYYY-MM-DD
  rotationPolicyDays: number;
  requiredBy: string[];
}

export type SecretStatus = "expired" | "warning" | "ok";

export interface SecretReport {
  name: string;
  lastRotated: string;
  rotationPolicyDays: number;
  requiredBy: string[];
  daysUntilExpiry: number; // negative means already expired
  status: SecretStatus;
}

export interface RotationReport {
  generatedAt: string;
  warningWindowDays: number;
  expired: SecretReport[];
  warning: SecretReport[];
  ok: SecretReport[];
}

export interface ValidatorConfig {
  warningWindowDays: number;
  secrets: Secret[];
}
