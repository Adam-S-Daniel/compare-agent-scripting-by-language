/**
 * Minimal YAML parser for workflow structure tests.
 * Handles the subset of YAML needed for GitHub Actions workflows:
 * maps, sequences, scalars, multi-line strings.
 *
 * For production use you'd want js-yaml, but this avoids external deps.
 */

interface YamlLine {
  indent: number;
  key?: string;
  value?: string;
  isListItem: boolean;
  raw: string;
}

function tokenize(yaml: string): YamlLine[] {
  return yaml
    .split("\n")
    .filter((line) => {
      const trimmed = line.trim();
      return trimmed.length > 0 && !trimmed.startsWith("#");
    })
    .map((line) => {
      const indent = line.length - line.trimStart().length;
      const trimmed = line.trimStart();
      const isListItem = trimmed.startsWith("- ");
      const content = isListItem ? trimmed.slice(2) : trimmed;

      const colonIdx = content.indexOf(": ");
      const endsWithColon = content.endsWith(":");
      let key: string | undefined;
      let value: string | undefined;

      if (colonIdx > 0 && !content.startsWith("|")) {
        key = content.slice(0, colonIdx).trim();
        value = content.slice(colonIdx + 2).trim();
        if (value === "") value = undefined;
      } else if (endsWithColon && !content.includes(" ")) {
        key = content.slice(0, -1);
      } else if (!isListItem) {
        // bare scalar or complex key
        key = content;
      } else {
        value = content;
      }

      return { indent, key, value, isListItem, raw: line };
    });
}

/**
 * Parse a YAML string into a nested JS object.
 * Good enough for GHA workflow files — not a full YAML spec implementation.
 */
export function parse(yaml: string): Record<string, unknown> {
  const lines = tokenize(yaml);
  const result: Record<string, unknown> = {};
  parseBlock(lines, 0, 0, result);
  return result;
}

function parseBlock(
  lines: YamlLine[],
  start: number,
  baseIndent: number,
  target: Record<string, unknown>
): number {
  let i = start;

  while (i < lines.length) {
    const line = lines[i];

    if (line.indent < baseIndent) break;

    if (line.isListItem) break; // lists handled by parent

    if (line.key) {
      const key = cleanKey(line.key);

      if (line.value !== undefined) {
        // Simple key: value
        target[key] = cleanValue(line.value);
        i++;
      } else {
        // Key with nested content — look at next line
        if (i + 1 < lines.length) {
          const next = lines[i + 1];
          if (next.indent > line.indent && next.isListItem) {
            // List
            const arr: unknown[] = [];
            i = parseList(lines, i + 1, next.indent, arr);
            target[key] = arr;
          } else if (next.indent > line.indent) {
            // Check for multi-line string marker
            if (line.raw.trimEnd().endsWith("|")) {
              // Collect multi-line string
              let str = "";
              i++;
              while (i < lines.length && lines[i].indent > line.indent) {
                str += (str ? "\n" : "") + lines[i].raw.trimStart();
                i++;
              }
              target[key] = str;
            } else {
              // Nested map
              const child: Record<string, unknown> = {};
              i = parseBlock(lines, i + 1, next.indent, child);
              target[key] = child;
            }
          } else {
            target[key] = null;
            i++;
          }
        } else {
          target[key] = null;
          i++;
        }
      }
    } else {
      i++;
    }
  }

  return i;
}

function parseList(
  lines: YamlLine[],
  start: number,
  baseIndent: number,
  target: unknown[]
): number {
  let i = start;

  while (i < lines.length) {
    const line = lines[i];
    if (line.indent < baseIndent) break;
    if (!line.isListItem) break;

    if (line.key && line.value !== undefined) {
      // List item is a map entry like "- name: Checkout"
      const obj: Record<string, unknown> = {};
      obj[cleanKey(line.key)] = cleanValue(line.value);
      // Check for more keys at deeper indent
      if (i + 1 < lines.length && lines[i + 1].indent > line.indent && !lines[i + 1].isListItem) {
        i = parseBlock(lines, i + 1, lines[i + 1].indent, obj);
      } else {
        i++;
      }
      target.push(obj);
    } else if (line.key && line.value === undefined) {
      // List item is a map key with nested content
      const obj: Record<string, unknown> = {};
      if (i + 1 < lines.length && lines[i + 1].indent > line.indent) {
        const child: Record<string, unknown> = {};
        i = parseBlock(lines, i + 1, lines[i + 1].indent, child);
        obj[cleanKey(line.key)] = child;
      } else {
        obj[cleanKey(line.key)] = null;
        i++;
      }
      target.push(obj);
    } else if (line.value !== undefined) {
      target.push(cleanValue(line.value));
      i++;
    } else {
      i++;
    }
  }

  return i;
}

function cleanKey(key: string): string {
  // Remove surrounding quotes
  if ((key.startsWith('"') && key.endsWith('"')) || (key.startsWith("'") && key.endsWith("'"))) {
    return key.slice(1, -1);
  }
  return key;
}

function cleanValue(val: string): string | number | boolean {
  if (val === "true") return true;
  if (val === "false") return false;
  if (/^\d+$/.test(val)) return parseInt(val, 10);
  if (/^\d+\.\d+$/.test(val)) return parseFloat(val);
  // Remove surrounding quotes
  if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
    return val.slice(1, -1);
  }
  return val;
}
