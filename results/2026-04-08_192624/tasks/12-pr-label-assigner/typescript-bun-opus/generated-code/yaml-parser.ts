/**
 * Minimal YAML parser for workflow structure tests.
 * Uses js-yaml if available, otherwise falls back to a simple regex-based approach.
 * We install js-yaml as a dev dependency.
 */

import jsYaml from "js-yaml";

export function parse(content: string): unknown {
  return jsYaml.load(content);
}
