import { useEffect, useState } from "react";
export type Snapshot = { label?: string; limit?: number; limitRemaining?: number; usage?: number; usageDaily?: number; usageWeekly?: number; usageMonthly?: number; credits?: { total: number; used: number }; stale: boolean };
let result: { ok: boolean; data?: Snapshot; error?: string } | undefined; const listeners = new Set<() => void>();
export async function refresh() { result = await window.babyMenu?.capabilities.invoke("openrouter-quota", "getQuota") as typeof result; listeners.forEach((listener) => listener()); }
export function useQuota() { const [, rerender] = useState(0); useEffect(() => { const listener = () => rerender((n) => n + 1); listeners.add(listener); void refresh(); return () => listeners.delete(listener); }, []); return result; }
