import type { RefreshableBabyMenuWidget } from "@babymenu/contracts";
import { CodexQuotaView } from "./components";
import { refresh } from "./store";
export const codexQuotaWidget: RefreshableBabyMenuWidget = { id: "codex-quota", title: "CODEX", render: () => <CodexQuotaView />, viewRefreshIntervalMs: 300_000, refreshView: refresh };
