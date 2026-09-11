import { useEffect, useState } from "react";
export type Snapshot = { plan?: string; windows: Array<{ id: string; label: string; percentUsed: number; resetAt?: string }>; stale: boolean };
let result: { ok: boolean; data?: Snapshot; error?: string } | undefined; const listeners = new Set<() => void>();
export async function refresh() { result = await window.babyMenu?.capabilities.invoke("cursor-quota", "getQuota") as typeof result; listeners.forEach((listener) => listener()); }
export function useQuota() { const [, rerender] = useState(0); useEffect(() => { const listener = () => rerender((n) => n + 1); listeners.add(listener); void refresh(); return () => listeners.delete(listener); }, []); return result; }
