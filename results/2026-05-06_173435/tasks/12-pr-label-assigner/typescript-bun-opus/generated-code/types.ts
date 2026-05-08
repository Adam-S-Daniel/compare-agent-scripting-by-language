export interface LabelRule {
  pattern: string;
  label: string;
  priority: number;
}

export interface LabelConfig {
  rules: LabelRule[];
  maxLabelsPerFile?: number;
}

export interface LabelResult {
  labels: string[];
  fileMatches: Record<string, string[]>;
}
