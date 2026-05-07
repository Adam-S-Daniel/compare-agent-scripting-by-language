export interface MatrixConfig {
  matrix: Record<string, (string | number | boolean)[]>;
  include?: Record<string, string | number | boolean>[];
  exclude?: Record<string, string | number | boolean>[];
  "fail-fast"?: boolean;
  "max-parallel"?: number;
  "max-combinations"?: number;
}

export type MatrixEntry = Record<string, string | number | boolean>;

export interface MatrixOutput {
  strategy: {
    "fail-fast": boolean;
    "max-parallel"?: number;
    matrix: {
      include: MatrixEntry[];
    };
  };
  total_combinations: number;
  dimensions: Record<string, number>;
}
