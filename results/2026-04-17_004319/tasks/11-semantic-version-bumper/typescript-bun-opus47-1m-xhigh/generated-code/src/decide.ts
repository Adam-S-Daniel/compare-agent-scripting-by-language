// Decide the semver bump type for a set of conventional commits.
//
// Precedence (highest first): breaking > feat > fix > none.
// Unknown commit types (docs, chore, style, test, ...) do not trigger a bump.

import type { Commit } from "./commits.ts";
import type { BumpType } from "./semver.ts";

export function decideBump(commits: Commit[]): BumpType {
  let bump: BumpType = "none";
  for (const commit of commits) {
    if (commit.breaking) return "major";
    if (commit.type === "feat" && bump !== "major") {
      bump = "minor";
    } else if (commit.type === "fix" && bump === "none") {
      bump = "patch";
    }
  }
  return bump;
}
