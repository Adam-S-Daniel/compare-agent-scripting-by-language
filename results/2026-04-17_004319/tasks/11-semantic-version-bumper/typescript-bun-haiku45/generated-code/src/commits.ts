import { CommitType } from "./bumper";

// Parses a conventional commit message and returns its type
export function parseCommitMessage(message: string): CommitType {
  // Check for breaking change indicator in subject or footer
  if (message.includes("!:") || message.includes("BREAKING CHANGE:")) {
    return CommitType.BREAKING;
  }

  // Extract commit type from conventional commit format (type: subject)
  const match = message.match(/^(\w+)(\(.+\))?!?:/);
  if (!match) {
    return CommitType.CHORE;
  }

  const type = match[1].toLowerCase();

  switch (type) {
    case "feat":
      return CommitType.FEAT;
    case "fix":
      return CommitType.FIX;
    case "chore":
      return CommitType.CHORE;
    default:
      return CommitType.CHORE;
  }
}

// Extracts commit types from an array of commit messages
export function getCommitTypes(messages: string[]): CommitType[] {
  return messages.map(parseCommitMessage);
}
