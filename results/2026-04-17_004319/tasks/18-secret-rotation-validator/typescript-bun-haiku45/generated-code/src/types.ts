// Core types for secret rotation validation
export interface Secret {
  name: string;
  lastRotated: Date;
  rotationPolicyDays: number;
  requiredByServices: string[];
}

export interface ValidationResult {
  isValid: boolean;
  errors: string[];
}

export interface RotationStatus {
  secret: Secret;
  status: "expired" | "warning" | "ok";
  daysUntilExpiration: number;
  expirationDate: Date;
}

export interface RotationReport {
  generated: Date;
  summary: {
    expired: number;
    warning: number;
    ok: number;
  };
  secrets: RotationStatus[];
}

// Validation function with complete error checking
export function validateSecret(secret: any): ValidationResult {
  const errors: string[] = [];

  if (!secret || typeof secret !== "object") {
    return { isValid: false, errors: ["Secret must be an object"] };
  }

  if (!secret.name || typeof secret.name !== "string") {
    errors.push("name is required and must be a string");
  }

  if (!(secret.lastRotated instanceof Date) && typeof secret.lastRotated !== "string") {
    errors.push("lastRotated must be a Date or ISO string");
  }

  if (typeof secret.rotationPolicyDays !== "number" || secret.rotationPolicyDays <= 0) {
    errors.push("rotationPolicyDays must be a positive number");
  }

  if (!Array.isArray(secret.requiredByServices) || secret.requiredByServices.length === 0) {
    errors.push("requiredByServices must be a non-empty array");
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}
