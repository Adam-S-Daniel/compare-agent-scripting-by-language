// Conventional Commits parser. Implements just enough to:
//   - identify type/scope/description/breaking
//   - decide whether a commit set warrants major/minor/patch
//
// We support two log formats:
//   1. Single-line commits separated by blank lines (simple fixtures).
//   2. Multi-line commits delimited by a literal "---" line, so that
//      bodies (e.g. "BREAKING CHANGE:" footers) can span multiple lines.

import type { BumpKind } from "./semver.ts";

export interface ParsedCommit {
  type: string;
  scope: string | null;
  breaking: boolean;
  description: string;
  raw: string;
}

const HEADER_RE = /^(?<type>[a-zA-Z]+)(?:\((?<scope>[^)]+)\))?(?<bang>!)?:\s+(?<desc>.+)$/;

export function parseCommit(message: string): ParsedCommit | null {
  if (!message.trim()) return null;
  const lines = message.split(/\r?\n/);
  const header = lines[0] ?? "";
  const m = HEADER_RE.exec(header);
  if (!m || !m.groups) return null;
  const breakingFooter = /^BREAKING CHANGE:\s+/m.test(message);
  return {
    type: m.groups.type.toLowerCase(),
    scope: m.groups.scope ?? null,
    breaking: Boolean(m.groups.bang) || breakingFooter,
    description: m.groups.desc.trim(),
    raw: message,
  };
}

export function parseCommitLog(log: string): ParsedCommit[] {
  const trimmed = log.replace(/\r\n/g, "\n").trim();
  if (!trimmed) return [];

  // If a "---" delimiter line exists, split on those (supports multi-line bodies).
  // Otherwise fall back to blank-line-delimited single-line commits.
  const chunks = trimmed.includes("\n---\n") || trimmed.startsWith("---\n") || trimmed.endsWith("\n---")
    ? trimmed.split(/\n---\n?/)
    : trimmed.split(/\n\s*\n/);

  const out: ParsedCommit[] = [];
  for (const chunk of chunks) {
    const c = parseCommit(chunk.trim());
    if (c) out.push(c);
  }
  return out;
}

export function determineBump(commits: ParsedCommit[]): BumpKind {
  let kind: BumpKind = "none";
  for (const c of commits) {
    if (c.breaking) return "major";
    if (c.type === "feat") {
      kind = "minor";
    } else if (c.type === "fix" && kind !== "minor") {
      kind = "patch";
    }
  }
  return kind;
}
