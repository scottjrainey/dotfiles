import { execFile } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);
type Window = { id: string; label: string; percentUsed: number; resetAt?: string };
type Snapshot = { source: "oauth"; plan?: string; models: string[]; windows: Window[]; refreshedAt: string; stale: boolean };
let lastGood: Snapshot | undefined;

const clamp = (value: number) => Math.max(0, Math.min(100, value));
const windowLabels: Record<string, string> = { five_hour: "five hour", seven_day: "weekly", seven_day_sonnet: "sonnet weekly", seven_day_opus: "opus weekly" };

async function candidates() {
  const values: Array<{ token: string; plan?: string; expiresAt?: number; keychain: boolean }> = [];
  const parse = (raw: string, keychain: boolean) => {
    try {
      const body = JSON.parse(raw); const auth = body.claudeAiOauth ?? body;
      const token = auth.accessToken ?? auth.access_token;
      if (typeof token === "string" && (!auth.expiresAt || Number(auth.expiresAt) > Date.now())) values.push({ token, plan: auth.subscriptionType, expiresAt: Number(auth.expiresAt), keychain });
    } catch { /* unusable credential */ }
  };
  await Promise.all([readFile(join(homedir(), ".claude", ".credentials.json"), "utf8").then((raw) => parse(raw, false)).catch(() => undefined), execFileAsync("security", ["find-generic-password", "-s", "Claude Code-credentials", "-w"], { timeout: 5_000 }).then(({ stdout }) => parse(stdout, true)).catch(() => undefined)]);
  return values.sort((a, b) => Number(b.keychain) - Number(a.keychain) || (b.expiresAt ?? 0) - (a.expiresAt ?? 0));
}

export const actions = {
  async getQuota() {
    const creds = await candidates();
    if (!creds.length) return { ok: false, error: "Claude sign-in required", sourceTried: ["credentials", "keychain"] };
    for (const credential of creds) {
      try {
        const response = await fetch("https://api.anthropic.com/api/oauth/usage", { headers: { Authorization: `Bearer ${credential.token}`, "anthropic-beta": "oauth-2025-04-20" }, signal: AbortSignal.timeout(15_000) });
        if (!response.ok) continue;
        const body = await response.json() as Record<string, any>;
        const windows = Object.entries(windowLabels).flatMap(([id, label]) => {
          const item = body[id]; const used = typeof item?.utilization === "number" ? item.utilization : Number.NaN;
          return Number.isFinite(used) ? [{ id, label, percentUsed: clamp(used), resetAt: typeof item?.resets_at === "string" ? item.resets_at : undefined }] : [];
        });
        for (const limit of Array.isArray(body.limits) ? body.limits : []) {
          const id = typeof limit?.kind === "string" ? limit.kind : undefined;
          const used = typeof limit?.percent === "number" ? limit.percent : Number.NaN;
          if (!id || id === "session" || id === "weekly_all" || !Number.isFinite(used) || windows.some((window) => window.id === id)) continue;
          const label = id === "weekly_scoped" ? "fable weekly" : id.replaceAll("_", " ");
          windows.push({ id, label, percentUsed: clamp(used), resetAt: typeof limit.resets_at === "string" ? limit.resets_at : undefined });
        }
        const extraUsage = body.extra_usage;
        if (extraUsage?.is_enabled && typeof extraUsage.utilization === "number") windows.push({ id: "extra_usage", label: "extra usage", percentUsed: clamp(extraUsage.utilization) });
        if (!windows.length) continue;
        const models = [
          windows.some((window) => window.id === "weekly_scoped") ? "fable" : undefined,
          windows.some((window) => window.id === "seven_day_sonnet") ? "sonnet" : undefined,
          windows.some((window) => window.id === "seven_day_opus") ? "opus" : undefined,
        ].filter((model): model is string => Boolean(model));
        lastGood = { source: "oauth", plan: credential.plan, models, windows, refreshedAt: new Date().toISOString(), stale: false };
        return { ok: true, data: lastGood };
      } catch { /* try remaining credential */ }
    }
    return lastGood ? { ok: true, data: { ...lastGood, stale: true } } : { ok: false, error: "Claude quota unavailable", sourceTried: ["oauth"] };
  },
};
