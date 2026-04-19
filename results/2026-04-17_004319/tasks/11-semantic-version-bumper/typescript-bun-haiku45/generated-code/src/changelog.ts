import { parseCommitMessage, getCommitTypes } from "./commits";
import { CommitType } from "./bumper";

// Generates a changelog entry for a version based on commits
export function generateChangelogEntry(
  version: string,
  commits: string[]
): string {
  const commitTypes = getCommitTypes(commits);
  const feats: string[] = [];
  const fixes: string[] = [];
  const others: string[] = [];

  for (let i = 0; i < commits.length; i++) {
    const commit = commits[i];
    const type = commitTypes[i];
    const message = extractMessage(commit);

    if (type === CommitType.FEAT) {
      feats.push(message);
    } else if (type === CommitType.FIX) {
      fixes.push(message);
    } else if (type !== CommitType.CHORE) {
      others.push(message);
    }
  }

  let entry = `## [${version}]\n\n`;

  if (feats.length > 0) {
    entry += "### Features\n\n";
    feats.forEach((feat) => {
      entry += `- ${feat}\n`;
    });
    entry += "\n";
  }

  if (fixes.length > 0) {
    entry += "### Bug Fixes\n\n";
    fixes.forEach((fix) => {
      entry += `- ${fix}\n`;
    });
    entry += "\n";
  }

  if (others.length > 0) {
    entry += "### Other\n\n";
    others.forEach((other) => {
      entry += `- ${other}\n`;
    });
    entry += "\n";
  }

  return entry;
}

// Extracts the message part from a conventional commit
function extractMessage(commit: string): string {
  // Remove commit type prefix (feat:, fix:, etc.)
  const match = commit.match(/^[a-z]+(?:\(.+\))?!?:\s*(.+)/);
  if (match) {
    return match[1];
  }
  return commit;
}
