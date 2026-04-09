// Minimal YAML parser for workflow structure tests.
// Uses a line-by-line approach to parse the subset of YAML used in GitHub Actions workflows.

export function parse(yaml: string): Record<string, any> {
  // Use bun's built-in YAML support or fall back to manual parsing
  // Bun does not have built-in YAML, so we shell out to a quick parse
  const { execSync } = require("child_process");
  const { writeFileSync, readFileSync, unlinkSync } = require("fs");
  const { join } = require("path");
  const { tmpdir } = require("os");

  const tmpFile = join(tmpdir(), `yaml-parse-${Date.now()}.json`);
  const scriptFile = join(tmpdir(), `yaml-parse-${Date.now()}.ts`);

  // Write a small bun script that parses YAML using a JSON-compatible approach
  // Since we need to parse YAML without external deps, we'll use node's JSON
  // and a simple manual approach for our known workflow structure

  return parseWorkflowYaml(yaml);
}

/**
 * Simple YAML parser sufficient for GitHub Actions workflow files.
 * Handles maps, arrays (- items), multi-line strings (|), and scalar values.
 */
function parseWorkflowYaml(yaml: string): Record<string, any> {
  const lines = yaml.split("\n");
  return parseBlock(lines, 0, 0).value as Record<string, any>;
}

interface ParseResult {
  value: any;
  nextLine: number;
}

function getIndent(line: string): number {
  const match = line.match(/^(\s*)/);
  return match ? match[1].length : 0;
}

function parseBlock(lines: string[], startLine: number, baseIndent: number): ParseResult {
  const result: Record<string, any> = {};
  let i = startLine;

  while (i < lines.length) {
    const line = lines[i];

    // Skip empty lines and comments
    if (line.trim() === "" || line.trim().startsWith("#")) {
      i++;
      continue;
    }

    const indent = getIndent(line);

    // If we've dedented past our base, we're done with this block
    if (indent < baseIndent) {
      break;
    }

    // Skip lines at deeper indent (they belong to a child)
    if (indent > baseIndent) {
      break;
    }

    const trimmed = line.trim();

    // Array item
    if (trimmed.startsWith("- ")) {
      // This block is an array, parse it differently
      return parseArray(lines, i, baseIndent);
    }

    // Key: value pair
    const colonIdx = trimmed.indexOf(":");
    if (colonIdx === -1) {
      i++;
      continue;
    }

    const key = trimmed.substring(0, colonIdx).trim();
    const afterColon = trimmed.substring(colonIdx + 1).trim();

    if (afterColon === "" || afterColon === "|") {
      // Check if next line is deeper (nested block) or a multi-line string
      const nextNonEmpty = findNextNonEmpty(lines, i + 1);
      if (nextNonEmpty < lines.length) {
        const nextIndent = getIndent(lines[nextNonEmpty]);
        if (nextIndent > indent) {
          if (afterColon === "|") {
            // Multi-line string
            const { value, nextLine } = parseMultilineString(lines, i + 1, nextIndent);
            result[key] = value;
            i = nextLine;
          } else {
            // Check if next content is an array
            if (lines[nextNonEmpty].trim().startsWith("- ")) {
              const { value, nextLine } = parseArray(lines, nextNonEmpty, nextIndent);
              result[key] = value;
              i = nextLine;
            } else {
              const { value, nextLine } = parseBlock(lines, nextNonEmpty, nextIndent);
              result[key] = value;
              i = nextLine;
            }
          }
        } else {
          result[key] = null;
          i++;
        }
      } else {
        result[key] = null;
        i++;
      }
    } else {
      // Inline value
      result[key] = parseScalar(afterColon);
      i++;
    }
  }

  return { value: result, nextLine: i };
}

function parseArray(lines: string[], startLine: number, baseIndent: number): ParseResult {
  const result: any[] = [];
  let i = startLine;

  while (i < lines.length) {
    const line = lines[i];

    if (line.trim() === "" || line.trim().startsWith("#")) {
      i++;
      continue;
    }

    const indent = getIndent(line);
    if (indent < baseIndent) break;
    if (indent > baseIndent) {
      i++;
      continue;
    }

    const trimmed = line.trim();
    if (!trimmed.startsWith("- ")) break;

    const itemContent = trimmed.substring(2);

    // Check if this is a simple value or a map
    const colonIdx = itemContent.indexOf(":");
    if (colonIdx > 0 && !itemContent.startsWith('"') && !itemContent.startsWith("'")) {
      // It's a map item starting with key: value
      const itemMap: Record<string, any> = {};
      const key = itemContent.substring(0, colonIdx).trim();
      const val = itemContent.substring(colonIdx + 1).trim();

      if (val === "" || val === "|") {
        const nextNonEmpty = findNextNonEmpty(lines, i + 1);
        if (nextNonEmpty < lines.length) {
          const nextIndent = getIndent(lines[nextNonEmpty]);
          if (nextIndent > indent) {
            if (val === "|") {
              const { value, nextLine } = parseMultilineString(lines, i + 1, nextIndent);
              itemMap[key] = value;
              i = nextLine;
            } else {
              const { value, nextLine } = parseBlock(lines, nextNonEmpty, nextIndent);
              itemMap[key] = value;
              i = nextLine;
            }
          } else {
            itemMap[key] = null;
            i++;
          }
        } else {
          itemMap[key] = null;
          i++;
        }
      } else {
        itemMap[key] = parseScalar(val);
        i++;
      }

      // Continue reading sibling keys at deeper indent
      while (i < lines.length) {
        const nextLine = lines[i];
        if (nextLine.trim() === "" || nextLine.trim().startsWith("#")) {
          i++;
          continue;
        }
        const nextIndent = getIndent(nextLine);
        // Sibling keys are at indent + 2 (continuation of this array item)
        if (nextIndent <= indent || nextLine.trim().startsWith("- ")) break;

        const nt = nextLine.trim();
        const nc = nt.indexOf(":");
        if (nc > 0) {
          const nk = nt.substring(0, nc).trim();
          const nv = nt.substring(nc + 1).trim();
          if (nv === "" || nv === "|") {
            const nn = findNextNonEmpty(lines, i + 1);
            if (nn < lines.length && getIndent(lines[nn]) > nextIndent) {
              if (nv === "|") {
                const { value, nextLine: nl } = parseMultilineString(lines, i + 1, getIndent(lines[nn]));
                itemMap[nk] = value;
                i = nl;
              } else {
                const { value, nextLine: nl } = parseBlock(lines, nn, getIndent(lines[nn]));
                itemMap[nk] = value;
                i = nl;
              }
            } else {
              itemMap[nk] = null;
              i++;
            }
          } else {
            itemMap[nk] = parseScalar(nv);
            i++;
          }
        } else {
          i++;
        }
      }

      result.push(itemMap);
    } else {
      // Simple array item
      result.push(parseScalar(itemContent));
      i++;
    }
  }

  return { value: result, nextLine: i };
}

function parseMultilineString(lines: string[], startLine: number, blockIndent: number): ParseResult {
  const parts: string[] = [];
  let i = startLine;

  while (i < lines.length) {
    const line = lines[i];
    if (line.trim() === "") {
      parts.push("");
      i++;
      continue;
    }
    const indent = getIndent(line);
    if (indent < blockIndent) break;
    parts.push(line.substring(blockIndent));
    i++;
  }

  return { value: parts.join("\n"), nextLine: i };
}

function findNextNonEmpty(lines: string[], startLine: number): number {
  let i = startLine;
  while (i < lines.length && (lines[i].trim() === "" || lines[i].trim().startsWith("#"))) {
    i++;
  }
  return i;
}

function parseScalar(value: string): any {
  // Remove quotes
  if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
    return value.slice(1, -1);
  }
  if (value === "true") return true;
  if (value === "false") return false;
  if (value === "null") return null;
  if (/^-?\d+$/.test(value)) return parseInt(value, 10);
  if (/^-?\d+\.\d+$/.test(value)) return parseFloat(value);

  // Handle arrays like [main, master]
  if (value.startsWith("[") && value.endsWith("]")) {
    return value
      .slice(1, -1)
      .split(",")
      .map((s) => parseScalar(s.trim()));
  }

  return value;
}
