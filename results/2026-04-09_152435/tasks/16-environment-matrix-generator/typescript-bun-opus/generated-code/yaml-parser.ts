/**
 * Minimal YAML parser for workflow structure tests.
 * Uses Python's PyYAML via a temp script file to avoid escaping issues.
 */

import { execSync } from "child_process";
import { writeFileSync, unlinkSync } from "fs";
import { join } from "path";

const YAML = {
  parse(input: string): any {
    // Write a Python helper script to parse YAML without bool coercion of 'on'
    const pyPath = join(import.meta.dir, ".yaml_parse_helper.py");
    const pyScript = `import yaml, json, sys

class Loader(yaml.SafeLoader):
    pass

# Prevent 'on'/'off' from being parsed as booleans
Loader.yaml_implicit_resolvers = {
    k: [(tag, regexp) for tag, regexp in v if tag != 'tag:yaml.org,2002:bool']
    for k, v in yaml.SafeLoader.yaml_implicit_resolvers.copy().items()
}

data = yaml.load(sys.stdin.read(), Loader=Loader)
print(json.dumps(data))
`;
    writeFileSync(pyPath, pyScript);
    try {
      const result = execSync(`python3 "${pyPath}"`, {
        input,
        encoding: "utf-8",
        stdio: ["pipe", "pipe", "pipe"],
      });
      return JSON.parse(result);
    } finally {
      try { unlinkSync(pyPath); } catch {}
    }
  },
};

export default YAML;
