import type { RefreshableBabyMenuWidget } from "@babymenu/contracts";
import { ClaudeQuotaView } from "./components";
import { refresh } from "./store";
export const claudeCodeQuotaWidget: RefreshableBabyMenuWidget = { id: "claude-code-quota", title: "CLAUDE CODE", render: () => <ClaudeQuotaView />, viewRefreshIntervalMs: 300_000, refreshView: refresh };
