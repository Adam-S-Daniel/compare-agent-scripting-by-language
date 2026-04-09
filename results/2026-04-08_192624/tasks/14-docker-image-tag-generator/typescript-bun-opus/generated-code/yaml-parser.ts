/**
 * Thin wrapper around js-yaml for parsing GitHub Actions workflow files.
 * Handles the YAML "on" key (which js-yaml can parse as boolean true).
 */

import jsYaml from "js-yaml";

/** Parse a YAML string into a JS object. */
export function parse(content: string): any {
  return jsYaml.load(content);
}
