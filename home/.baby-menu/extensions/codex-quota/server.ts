import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
type Window = { id: string; label: string; percentUsed: number; resetAt?: string };
type Snapshot = { plan?: string; accountEmail?: string; windows: Window[]; refreshedAt: string; stale: boolean };
let lastGood: Snapshot | undefined;
const clamp = (value: number) => Math.max(0, Math.min(100, value));

export const actions = {
  async getQuota() {
    let auth: Record<string, any>;
    try { auth = JSON.parse(await readFile(join(process.env.CODEX_HOME || join(homedir(), ".codex"), "auth.json"), "utf8")); } catch { return { ok: false, error: "Run codex to log in.", sourceTried: ["auth.json"] }; }
    const token = auth.OPENAI_API_KEY || auth.tokens?.access_token || auth.tokens?.accessToken;
    if (typeof token !== "string" || !token) return { ok: false, error: "Run codex to log in.", sourceTried: ["auth.json"] };
    try {
      const headers: Record<string, string> = { Authorization: `Bearer ${token}` };
      if (typeof auth.tokens?.account_id === "string") headers["ChatGPT-Account-Id"] = auth.tokens.account_id;
      const response = await fetch("https://chatgpt.com/backend-api/wham/usage", { headers, signal: AbortSignal.timeout(15_000) });
      if (!response.ok) return lastGood ? { ok: true, data: { ...lastGood, stale: true } } : { ok: false, error: response.status === 401 || response.status === 403 ? "Codex sign-in required" : "Codex quota unavailable", sourceTried: ["oauth"] };
      const body = await response.json() as any;
      const rateLimit = body.rate_limit;
      const windows = [["primary_window", "five hour", "five_hour"], ["secondary_window", "weekly", "weekly"]].flatMap(([key, label, id]) => {
        const item = rateLimit?.[key]; const used = typeof item?.used_percent === "number" ? item.used_percent : Number.NaN;
        return Number.isFinite(used) ? [{ id, label, percentUsed: clamp(used), resetAt: typeof item.reset_at === "number" ? new Date(item.reset_at * 1000).toISOString() : undefined }] : [];
      });
      if (!windows.length) throw new Error("No quota windows");
      lastGood = { plan: typeof body.plan_type === "string" ? body.plan_type : undefined, accountEmail: typeof body.email === "string" ? body.email : undefined, windows, refreshedAt: new Date().toISOString(), stale: false };
      return { ok: true, data: lastGood };
    } catch { return lastGood ? { ok: true, data: { ...lastGood, stale: true } } : { ok: false, error: "Codex quota unavailable", sourceTried: ["oauth"] }; }
  },
};
