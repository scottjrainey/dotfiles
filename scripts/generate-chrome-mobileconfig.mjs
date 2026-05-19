#!/usr/bin/env node
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const extensionsPath = path.join(root, "chrome", "extensions.json");
const templatePath = path.join(root, "chrome", "chrome.mobileconfig.template");
const outputPath = path.join(root, "chrome", "chrome.mobileconfig");

const extensions = JSON.parse(fs.readFileSync(extensionsPath, "utf8"));
const template = fs.readFileSync(templatePath, "utf8");

const defaultUpdateUrl = "https://clients2.google.com/service/update2/crx";
const forcelist = extensions
  .map((extension) => {
    const updateUrl = extension.updateUrl || defaultUpdateUrl;
    return `        <string>${extension.id};${updateUrl}</string>`;
  })
  .join("\n");

fs.writeFileSync(
  outputPath,
  template.replace("{{EXTENSION_INSTALL_FORCELIST}}", forcelist),
);

console.log(`Wrote ${outputPath}`);
