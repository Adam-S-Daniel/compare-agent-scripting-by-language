// Minimal YAML parser for workflow structure tests.
// Uses Python's yaml module to parse, preserving string keys like 'on'.

import { execSync } from "child_process";
import { writeFileSync, unlinkSync } from "fs";
import { join } from "path";

/**
 * Parse YAML by converting to JSON via Python.
 * Writes a helper script to avoid shell escaping issues.
 */
function parse(yamlStr: string): any {
  const scriptPath = join(import.meta.dir, ".yaml_parse_helper.py");
  writeFileSync(
    scriptPath,
    [
      "import sys, json, yaml",
      "",
      "class StringKeyLoader(yaml.SafeLoader):",
      "    pass",
      "",
      "# Keep 'on','off','yes','no' as strings instead of booleans",
      "for ch in 'oOyYnN':",
      "    StringKeyLoader.yaml_implicit_resolvers.pop(ch, None)",
      "",
      "data = yaml.load(sys.stdin.read(), Loader=StringKeyLoader)",
      "print(json.dumps(data))",
    ].join("\n")
  );

  try {
    const result = execSync("python3 .yaml_parse_helper.py", {
      input: yamlStr,
      encoding: "utf-8",
      cwd: import.meta.dir,
      stdio: ["pipe", "pipe", "pipe"],
    });
    return JSON.parse(result.trim());
  } finally {
    try { unlinkSync(scriptPath); } catch {}
  }
}

export default { parse };
