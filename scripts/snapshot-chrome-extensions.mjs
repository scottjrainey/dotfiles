#!/usr/bin/env node
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const profile = process.argv[2] || "Default";
const includeComponents = process.argv.includes("--include-components");
const chromeExtensionsDir = path.join(
  os.homedir(),
  "Library/Application Support/Google/Chrome",
  profile,
  "Extensions",
);

const defaultUpdateUrl = "https://clients2.google.com/service/update2/crx";
const componentIds = new Set([
  "nmmhkkegccagdldgiimedpiccmgmieda", // Chrome Web Store Payments
]);

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, "utf8"));
}

function resolveMessage(extensionDir, manifest, value) {
  const match = value && value.match(/^__MSG_(.+)__$/i);
  if (!match) return value;

  const key = match[1].toLowerCase();
  const locales = [manifest.default_locale, "en", "en_US"].filter(Boolean);

  for (const locale of locales) {
    const messagesPath = path.join(extensionDir, "_locales", locale, "messages.json");
    if (!fs.existsSync(messagesPath)) continue;

    const messages = readJson(messagesPath);
    if (messages[key]?.message) return messages[key].message;
  }

  return value;
}

const extensions = [];

for (const id of fs.readdirSync(chromeExtensionsDir)) {
  if (!/^[a-p]{32}$/.test(id)) continue;
  if (!includeComponents && componentIds.has(id)) continue;

  const idDir = path.join(chromeExtensionsDir, id);
  const versions = fs
    .readdirSync(idDir)
    .filter((version) => fs.existsSync(path.join(idDir, version, "manifest.json")))
    .sort();

  const version = versions.at(-1);
  if (!version) continue;

  const extensionDir = path.join(idDir, version);
  const manifest = readJson(path.join(extensionDir, "manifest.json"));
  const name = resolveMessage(extensionDir, manifest, manifest.name);
  if (name.toLowerCase().includes("password manager")) continue;

  extensions.push({
    name,
    id,
    updateUrl: manifest.update_url || defaultUpdateUrl,
  });
}

extensions.sort((a, b) => a.name.localeCompare(b.name));
console.log(JSON.stringify(extensions, null, 2));
