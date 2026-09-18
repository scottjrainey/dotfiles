import { execFile } from "node:child_process";
import { access } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { promisify } from "node:util";
const execFileAsync = promisify(execFile);
type Snapshot = { plan?: string; accountEmail?: string; windows: Array<{ id: string; label: string; percentUsed: number; resetAt?: string }>; refreshedAt: string; stale: boolean };
let lastGood: Snapshot | undefined;
const clamp = (value: number) => Math.max(0, Math.min(100, value));
const toIsoDate = (value: unknown) => {
  const date = new Date(typeof value === "number" ? value : String(value));
  return Number.isNaN(date.valueOf()) ? undefined : date.toISOString();
};
async function readAuth() {
  const db = join(homedir(), "Library", "Application Support", "Cursor", "User", "globalStorage", "state.vscdb"); await access(db);
  let stdout = ""; let lastError: unknown;
  for (const binary of ["sqlite3", "/usr/bin/sqlite3", "/opt/homebrew/bin/sqlite3", "/usr/local/bin/sqlite3"]) try { ({ stdout } = await execFileAsync(binary, ["-readonly", "-cmd", ".timeout 1000", db, "SELECT key, value FROM ItemTable WHERE key IN ('cursorAuth/accessToken', 'cursorAuth/cachedEmail', 'cursorAuth/stripeMembershipType');"], { timeout: 5_000 })); lastError = undefined; break; } catch (error) { lastError = error; }
  if (lastError) throw lastError;
  return Object.fromEntries(stdout.trim().split("\n").filter(Boolean).map((line) => { const at = line.indexOf("|"); return [line.slice(0, at), line.slice(at + 1)]; }));
}
async function getGrokbotWindow(token: string) {
  const payload = token.split(".")[1];
  if (!payload) return undefined;
  let subject: unknown;
  try { subject = JSON.parse(Buffer.from(payload, "base64url").toString("utf8")).sub; } catch { return undefined; }
  if (typeof subject !== "string" || !subject) return undefined;
  const response = await fetch("https://cursor.com/api/dashboard/get-sand-usage-status", {
    method: "POST",
    headers: {
      Cookie: `WorkosCursorSessionToken=${encodeURIComponent(`${subject}::${token}`)}`,
      Origin: "https://cursor.com",
      Accept: "application/json",
      "content-type": "application/json",
    },
    body: "{}",
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) return undefined;
  const usage = await response.json() as { usagePercent?: unknown; nextResetTimestampUtc?: unknown };
  return typeof usage.usagePercent === "number" && Number.isFinite(usage.usagePercent)
    ? { id: "grokbot_usage", label: "grok bot usage", percentUsed: clamp(usage.usagePercent), resetAt: toIsoDate(usage.nextResetTimestampUtc) }
    : undefined;
}
export const actions = { async getQuota() {
  let auth: Record<string, string>; try { auth = await readAuth(); } catch { return lastGood ? { ok: true, data: { ...lastGood, stale: true } } : { ok: false, error: "Cursor quota unavailable", sourceTried: ["local-db"] }; }
  const token = auth["cursorAuth/accessToken"]; if (!token) return { ok: false, error: "Cursor sign-in required", sourceTried: ["local-db"] };
  try {
    const headers = { Authorization: `Bearer ${token}`, "content-type": "application/json", "connect-protocol-version": "1" };
    const usageResponse = await fetch("https://api2.cursor.sh/aiserver.v1.DashboardService/GetCurrentPeriodUsage", { method: "POST", headers, body: "{}", signal: AbortSignal.timeout(15_000) });
    if (!usageResponse.ok) return lastGood ? { ok: true, data: { ...lastGood, stale: true } } : { ok: false, error: usageResponse.status === 401 || usageResponse.status === 403 ? "Cursor sign-in required" : "Cursor quota unavailable", sourceTried: ["api"] };
    const usage = await usageResponse.json() as any; const planResponse = await fetch("https://api2.cursor.sh/aiserver.v1.DashboardService/GetPlanInfo", { method: "POST", headers, body: "{}", signal: AbortSignal.timeout(15_000) }).catch(() => undefined); const planBody = planResponse?.ok ? await planResponse.json() as any : undefined;
    const resetAt = toIsoDate(Number(usage.billingCycleEnd));
    const windows = [["totalPercentUsed", "included usage", "included_usage"], ["autoPercentUsed", "auto usage", "auto_usage"], ["apiPercentUsed", "api usage", "api_usage"]].flatMap(([key, label, id]) => { const value = usage.planUsage?.[key]; return typeof value === "number" && Number.isFinite(value) ? [{ id, label, percentUsed: clamp(value), resetAt }] : []; });
    const grokbotWindow = await getGrokbotWindow(token).catch(() => undefined); if (grokbotWindow) windows.push(grokbotWindow);
    if (!windows.length) throw new Error("No quota windows");
    lastGood = { accountEmail: auth["cursorAuth/cachedEmail"], plan: planBody?.planInfo?.planName ?? auth["cursorAuth/stripeMembershipType"], windows, refreshedAt: new Date().toISOString(), stale: false }; return { ok: true, data: lastGood };
  } catch { return lastGood ? { ok: true, data: { ...lastGood, stale: true } } : { ok: false, error: "Cursor quota unavailable", sourceTried: ["api"] }; }
} };
