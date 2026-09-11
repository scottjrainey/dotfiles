import type { BabyMenuLayoutProps } from "@babymenu/contracts";

const preferredOrder = [
  "claude-code-quota",
  "codex-quota",
  "cursor-quota",
  "openrouter-quota",
];

export default function Layout({ widgets, renderWidget }: BabyMenuLayoutProps) {
  const ordered = [...widgets].sort((left, right) => {
    const leftIndex = preferredOrder.indexOf(left.id);
    const rightIndex = preferredOrder.indexOf(right.id);
    return (leftIndex < 0 ? preferredOrder.length : leftIndex) - (rightIndex < 0 ? preferredOrder.length : rightIndex);
  });

  return (
    <div className="flex w-[504px] max-h-[640px] flex-col gap-3 overflow-y-auto p-3 pr-2">
      {ordered.map((widget) => (
        <div key={widget.id}>{renderWidget(widget.id)}</div>
      ))}
    </div>
  );
}
