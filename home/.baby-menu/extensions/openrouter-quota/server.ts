import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";

type Snapshot = { label?: string; limit?: number; limitRemaining?: number; usage?: number; usageDaily?: number; usageWeekly?: number; usageMonthly?: number; credits?: { total: number; used: number }; refreshedAt: string; stale: boolean };
let lastGood: Snapshot | undefined;
const number = (value: unknown) => typeof value === "number" && Number.isFinite(value) ? value : undefined;
async function openRouterToken() {
  if (process.env.OPENROUTER_API_KEY) return process.env.OPENROUTER_API_KEY;
  try {
    const line = (await readFile(join(homedir(), ".env"), "utf8")).split(/\r?\n/).find((entry) => /^\s*(?:export\s+)?OPENROUTER_API_KEY\s*=/.test(entry));
    if (!line) return undefined;
    const value = line.slice(line.indexOf("=") + 1).trim().replace(/^(?:"([\s\S]*)"|'([\s\S]*)')$/, "$1$2");
    return value || undefined;
  } catch { return undefined; }
}
export const actions = { async getQuota() {
  const token = await openRouterToken();
  if (!token) return { ok: false, error: "Add OPENROUTER_API_KEY to ~/.env", sourceTried: ["environment", "~/.env"] };
  try {
    const headers = { Authorization: `Bearer ${token}` };
    const keyResponse = await fetch("https://openrouter.ai/api/v1/key", { headers, signal: AbortSignal.timeout(15_000) });
    if (!keyResponse.ok) return lastGood ? { ok: true, data: { ...lastGood, stale: true } } : { ok: false, error: keyResponse.status === 401 || keyResponse.status === 403 ? "OpenRouter key rejected" : "OpenRouter quota unavailable", sourceTried: ["api"] };
    const key = (await keyResponse.json() as any).data ?? {};
    const creditResponse = await fetch("https://openrouter.ai/api/v1/credits", { headers, signal: AbortSignal.timeout(15_000) }).catch(() => undefined);
    const credit = creditResponse?.ok ? ((await creditResponse.json() as any).data ?? {}) : undefined;
    lastGood = { label: typeof key.label === "string" ? key.label : undefined, limit: number(key.limit), limitRemaining: number(key.limit_remaining), usage: number(key.usage), usageDaily: number(key.usage_daily), usageWeekly: number(key.usage_weekly), usageMonthly: number(key.usage_monthly), credits: number(credit?.total_credits) !== undefined && number(credit?.total_usage) !== undefined ? { total: number(credit.total_credits)!, used: number(credit.total_usage)! } : undefined, refreshedAt: new Date().toISOString(), stale: false };
    return { ok: true, data: lastGood };
  } catch { return lastGood ? { ok: true, data: { ...lastGood, stale: true } } : { ok: false, error: "OpenRouter quota unavailable", sourceTried: ["api"] }; }
} };
