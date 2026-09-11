import type { RefreshableBabyMenuWidget } from "@babymenu/contracts";
import { OpenRouterQuotaView } from "./components";
import { refresh } from "./store";
export const openRouterQuotaWidget: RefreshableBabyMenuWidget = { id: "openrouter-quota", title: "OPENROUTER", render: () => <OpenRouterQuotaView />, viewRefreshIntervalMs: 300_000, refreshView: refresh };
