// Merge workflow inputs into fixture config for CI run
import { readFileSync, writeFileSync } from "fs";
import type { ValidatorConfig } from "./types";

const raw = readFileSync("fixtures/secrets-mixed.json", "utf-8");
const cfg = JSON.parse(raw) as ValidatorConfig;
const ww = parseInt(process.env.WARNING_WINDOW ?? "7", 10);
cfg.warningWindowDays = ww;
writeFileSync("fixtures/run-config.json", JSON.stringify(cfg, null, 2));
console.log(`Prepared config with warningWindowDays=${ww}`);
