// CLI entry point: reads a JSON config file and prints the matrix JSON.
// Usage: bun run generate-matrix.ts <config.json>
// Exit code 0 on success, 1 on error.

import { generateMatrix } from './matrix-generator';
import type { MatrixConfig } from './matrix-generator';

const args = process.argv.slice(2);
if (args.length === 0) {
  console.error(JSON.stringify({ success: false, error: 'Usage: bun run generate-matrix.ts <config.json>' }));
  process.exit(1);
}

try {
  const configText = await Bun.file(args[0]).text();
  const config: MatrixConfig = JSON.parse(configText);
  const result = generateMatrix(config);
  console.log(JSON.stringify(result, null, 2));
  if (!result.success) process.exit(1);
} catch (err) {
  console.error(JSON.stringify({ success: false, error: String(err) }));
  process.exit(1);
}
