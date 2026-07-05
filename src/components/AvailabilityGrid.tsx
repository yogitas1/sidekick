"use client";

import { DAY_NAMES, TIME_BLOCKS, type AvailabilitySlot, type TimeBlock } from "@/lib/types";

const BLOCK_LABELS: Record<TimeBlock, string> = {
  morning: "🌅 Morning",
  afternoon: "☀️ Afternoon",
  evening: "🌆 Evening",
};

export default function AvailabilityGrid({
  value,
  onChange,
}: {
  value: AvailabilitySlot[];
  onChange: (slots: AvailabilitySlot[]) => void;
}) {
  const has = (d: number, b: TimeBlock) =>
    value.some((s) => s.day_of_week === d && s.time_block === b);

  const toggle = (d: number, b: TimeBlock) => {
    if (has(d, b)) {
      onChange(value.filter((s) => !(s.day_of_week === d && s.time_block === b)));
    } else {
      onChange([...value, { day_of_week: d, time_block: b }]);
    }
  };

  return (
    <div className="overflow-x-auto">
      <table className="w-full border-separate border-spacing-1">
        <thead>
          <tr>
            <th className="w-28" />
            {DAY_NAMES.map((d) => (
              <th key={d} className="pb-1 text-xs font-medium text-ink/60">
                {d}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {TIME_BLOCKS.map((block) => (
            <tr key={block}>
              <td className="pr-2 text-left text-xs font-medium whitespace-nowrap text-ink/60">
                {BLOCK_LABELS[block]}
              </td>
              {DAY_NAMES.map((_, day) => (
                <td key={day}>
                  <button
                    type="button"
                    aria-pressed={has(day, block)}
                    onClick={() => toggle(day, block)}
                    className={`h-10 w-full rounded-lg border transition ${
                      has(day, block)
                        ? "border-tan bg-tan text-white"
                        : "border-ink/10 bg-white hover:border-tan/40"
                    }`}
                  >
                    {has(day, block) ? "✓" : ""}
                  </button>
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
