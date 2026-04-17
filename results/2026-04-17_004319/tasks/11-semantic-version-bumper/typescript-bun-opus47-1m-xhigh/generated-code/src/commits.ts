// Conventional-commit parsing utilities.
//
// We intentionally parse only the surface structure required for version
// bumping: the commit type (feat/fix/...), whether a scope is present, whether
// the commit is a breaking change, and the subject line. Bodies are scanned
// for a BREAKING CHANGE footer but are otherwise discarded.

export interface Commit {
  /** Conventional-commit type ("feat", "fix", ...) or "other". */
  type: string;
  /** Optional scope: e.g. "api" for "feat(api): ...". */
  scope: string | null;
  /** True if the commit declares a breaking change. */
  breaking: boolean;
  /** Commit subject (first line after "type(scope)?!: "). */
  subject: string;
  /** Original (first-line) commit text for debugging / changelog use. */
  raw: string;
}

export interface ParseLogOptions {
  /**
   * Commit delimiter in the log stream. Defaults to a blank line ("") which
   * matches `git log --format=%B` with `-z` replaced by blank separators.
   */
  delimiter?: string;
}

// Subject grammar: "<type>(<scope>)?!?: <subject>"
const SUBJECT_RE = /^([a-zA-Z]+)(?:\(([^)]+)\))?(!)?:\s*(.+)$/;

// Parse a single commit subject line (no body).
export function parseCommit(line: string): Commit {
  const raw = line;
  const match = SUBJECT_RE.exec(line.trim());
  if (!match) {
    return {
      type: "other",
      scope: null,
      breaking: false,
      subject: line.trim(),
      raw,
    };
  }
  const [, type, scope, bang, subject] = match;
  return {
    type: type.toLowerCase(),
    scope: scope ?? null,
    breaking: Boolean(bang),
    subject: subject.trim(),
    raw,
  };
}

// Parse a full git-log-style buffer consisting of one or more commits
// separated by a delimiter.
//
// With a custom delimiter (e.g. "---"), commits are split strictly on
// full-line matches of that delimiter.
//
// With the default blank-line delimiter (""), a new commit begins only at a
// blank line that is followed by a line matching the conventional-commit
// subject pattern. This lets multi-line commit bodies — including blank
// paragraphs between the subject and a BREAKING CHANGE footer — stay grouped
// with the commit that owns them.
export function parseCommitLog(log: string, opts: ParseLogOptions = {}): Commit[] {
  const delimiter = opts.delimiter ?? "";
  if (log.trim() === "") return [];

  const lines = log.split(/\r?\n/);
  const blocks: string[][] = [];

  if (delimiter !== "") {
    let current: string[] = [];
    for (const line of lines) {
      if (line === delimiter) {
        if (current.length > 0) {
          blocks.push(current);
          current = [];
        }
      } else {
        current.push(line);
      }
    }
    if (current.length > 0) blocks.push(current);
  } else {
    // Blank-line-aware splitting with a lookahead: a blank line separates
    // commits only when the next non-blank line looks like a new subject.
    let current: string[] = [];
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (line.trim() === "") {
        // Look ahead past consecutive blanks to the next non-blank line.
        let j = i + 1;
        while (j < lines.length && lines[j].trim() === "") j++;
        const next = j < lines.length ? lines[j] : null;
        if (next !== null && SUBJECT_RE.test(next.trim()) && current.length > 0) {
          blocks.push(current);
          current = [];
          i = j - 1; // resume at (j-1); the loop increment moves us to j
          continue;
        }
        // Otherwise the blank line is part of the current commit's body.
        if (current.length > 0) current.push(line);
      } else {
        current.push(line);
      }
    }
    if (current.length > 0) blocks.push(current);
  }

  const commits: Commit[] = [];
  for (const block of blocks) {
    const firstIdx = block.findIndex((l) => l.trim() !== "");
    if (firstIdx === -1) continue;
    const subjectLine = block[firstIdx];
    const body = block.slice(firstIdx + 1).join("\n");

    const commit = parseCommit(subjectLine);
    if (/^\s*BREAKING[ -]CHANGE\s*:/im.test(body)) {
      commit.breaking = true;
    }
    commits.push(commit);
  }
  return commits;
}
