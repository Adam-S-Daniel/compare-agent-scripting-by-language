// Conventional-commit parsing.
// Supports:  type(scope)!: description   +  "BREAKING CHANGE:" footer.
// Anything that doesn't match the header regex is considered non-conventional
// and returns null so the caller can ignore it.

export interface Commit {
  type: string;
  scope: string | undefined;
  breaking: boolean;
  description: string;
}

// Header form:  <type>(<scope>)?!?: <description>
const HEADER_RE = /^(?<type>[a-zA-Z]+)(?:\((?<scope>[^)]+)\))?(?<bang>!)?:\s*(?<desc>.+)$/;

export function parseCommit(message: string): Commit | null {
  // We only need the first line for the header; footers are scanned below.
  const lines = message.split(/\r?\n/);
  const header = lines[0] ?? "";
  const m = HEADER_RE.exec(header);
  if (!m || !m.groups) return null;

  const breakingInFooter = /(^|\n)BREAKING[ -]CHANGE:/.test(message);

  return {
    type: m.groups.type!.toLowerCase(),
    scope: m.groups.scope ?? undefined,
    breaking: Boolean(m.groups.bang) || breakingInFooter,
    description: m.groups.desc!.trim(),
  };
}

// Fixture log format: commits separated by a "---" line on its own.
// Each commit body may span multiple lines.  Unparseable entries are dropped.
export function parseCommitLog(log: string): Commit[] {
  const chunks = log
    .split(/^---\s*$/m)
    .map((s) => s.trim())
    .filter((s) => s.length > 0);

  const out: Commit[] = [];
  for (const chunk of chunks) {
    const c = parseCommit(chunk);
    if (c) out.push(c);
  }
  return out;
}
