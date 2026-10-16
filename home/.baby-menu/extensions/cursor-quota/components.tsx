import { Progress, StatusDot } from "@babymenu/ui";
import { useQuota } from "./store";

const plan = (value?: string) => value?.toLowerCase() === "pro+" ? "pro+ · $60/mo" : value?.toLowerCase() === "pro" ? "pro · $20/mo" : value?.toLowerCase() === "ultra" ? "ultra · $200/mo" : value;
const endAt = (value?: string) => {
  if (!value) return undefined;
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? undefined : new Intl.DateTimeFormat(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }).format(date);
};

export function CursorQuotaView() {
  const result = useQuota();
  const data = result?.data;
  const primary = data?.windows.find((window) => window.id === "included_usage") ?? data?.windows[0];
  return <details className="group"><summary className="flex cursor-pointer list-none items-center justify-between text-xxs uppercase tracking-caps text-ink-label"><span className="flex items-center"><span className="mr-2 group-open:hidden">▸</span><span className="mr-2 hidden group-open:inline">▾</span>cursor agent{plan(data?.plan) ? ` · ${plan(data?.plan)}` : ""}<span className={data?.stale ? "ml-4 text-signal-warn" : "ml-4 text-signal-live"}><StatusDot tone={data?.stale ? "warn" : "live"} /> {data?.stale ? "stale" : "live"}</span></span><span>{primary ? `${primary.percentUsed.toFixed(1)}% included` : result?.error ?? "loading"}</span></summary><div className="mt-3 flex flex-col gap-2">{data?.windows.map((window) => { const end = endAt(window.resetAt); return <div key={window.id}><div className="flex justify-between gap-3 text-sm text-ink"><span>{window.label}</span><span className="shrink-0 text-right">{window.percentUsed.toFixed(1)}% used{end ? <span className="text-ink-label"> · ends {end}</span> : ""}</span></div><Progress value={window.percentUsed} /></div>; })}</div></details>;
}
