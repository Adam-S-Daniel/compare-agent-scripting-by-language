// Core domain types for the secret rotation validator

export interface SecretConfig {
  name: string;
  lastRotated: string; // ISO date string YYYY-MM-DD
  rotationPolicyDays: number;
  requiredBy: string[];
}

export interface SecretsConfigFile {
  warningWindowDays?: number; // defaults to 7
  secrets: SecretConfig[];
}

export type Urgency = "expired" | "warning" | "ok";

export interface SecretStatus {
  secret: SecretConfig;
  daysSinceRotation: number;
  daysUntilExpiry: number; // negative = already expired
  urgency: Urgency;
}

export interface RotationReport {
  generatedAt: string; // ISO timestamp
  referenceDate: string; // YYYY-MM-DD used for calculations
  warningWindowDays: number;
  expired: SecretStatus[];
  warning: SecretStatus[];
  ok: SecretStatus[];
}

export type OutputFormat = "markdown" | "json";
