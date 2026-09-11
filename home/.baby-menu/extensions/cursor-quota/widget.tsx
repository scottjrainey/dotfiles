import type { RefreshableBabyMenuWidget } from "@babymenu/contracts";
import { CursorQuotaView } from "./components";
import { refresh } from "./store";
export const cursorQuotaWidget: RefreshableBabyMenuWidget = { id: "cursor-quota", title: "CURSOR AGENT", render: () => <CursorQuotaView />, viewRefreshIntervalMs: 300_000, refreshView: refresh };
