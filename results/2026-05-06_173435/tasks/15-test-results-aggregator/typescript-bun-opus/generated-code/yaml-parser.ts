import yaml from "js-yaml";

export function parse(content: string): any {
  return yaml.load(content);
}
