// Gets commit messages since a given version tag
export async function getCommitsSinceTag(tag: string): Promise<string[]> {
  try {
    // Use git log to get commits since tag (or all if tag doesn't exist)
    const cmd = `git log ${tag ? `${tag}..HEAD` : "HEAD"} --oneline --format=%s`;
    const result = await runCommand(cmd);
    return result
      .trim()
      .split("\n")
      .filter((line) => line.length > 0);
  } catch (error) {
    console.warn(`Warning: Could not fetch git commits: ${error}`);
    return [];
  }
}

// Runs a shell command and returns the output
async function runCommand(cmd: string): Promise<string> {
  const proc = Bun.spawn({
    cmd: ["sh", "-c", cmd],
    stdout: "pipe",
    stderr: "pipe",
  });

  const output = await new Response(proc.stdout).text();
  const exitCode = await proc.exited;

  if (exitCode !== 0) {
    const error = await new Response(proc.stderr).text();
    throw new Error(`Command failed: ${error}`);
  }

  return output;
}
