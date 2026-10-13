import { addDays, formatTokyoClock, tokyoDateAt, tokyoParts } from "./tokyo-time";
import type { ApproachBus, ApproachSighting, Operator, SourceStatus } from "./types";

const TWO_HOURS = 2 * 60 * 60 * 1000;

/** How long a bus stays after its estimated arrival before it leaves the board. */
export const ARRIVAL_GRACE_MS = 60_000;

export type Countdown =
  | { kind: "minutes"; minutes: number }
  | { kind: "soon" }
  | { kind: "past" }
  | { kind: "unknown" };

/**
 * The operator clock is only HH:MM. Place it on today's Tokyo date, and on
 * yesterday when that would put the clock more than two hours ahead of now
 * (the page was read just after midnight).
 */
export function observedInstant(now: Date, clock: string | null): Date {
  const match = clock?.match(/^(\d{1,2}):(\d{2})$/);
  if (!match) return now;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return now;
  const today = tokyoParts(now);
  let basis = tokyoDateAt(today.ymd, hour, minute);
  if (basis.getTime() - now.getTime() > TWO_HOURS) {
    basis = tokyoDateAt(addDays(today.ymd, -1), hour, minute);
  }
  return basis;
}

export function stampSightings(
  sightings: ApproachSighting[],
  observedAt: Date,
): ApproachBus[] {
  return sightings.map((bus) => ({
    ...bus,
    observedAt: observedAt.toISOString(),
    arrivesAt:
      bus.minutes == null
        ? null
        : new Date(observedAt.getTime() + bus.minutes * 60_000).toISOString(),
  }));
}

export function countdownAt(
  arrivesAt: string | null,
  now: Date,
  graceMs = ARRIVAL_GRACE_MS,
): Countdown {
  if (!arrivesAt) return { kind: "unknown" };
  const remaining = new Date(arrivesAt).getTime() - now.getTime();
  if (Number.isNaN(remaining)) return { kind: "unknown" };
  if (remaining <= -graceMs) return { kind: "past" };
  if (remaining <= 0) return { kind: "soon" };
  return { kind: "minutes", minutes: Math.ceil(remaining / 60_000) };
}

export function basisCaption(
  sources: SourceStatus[],
): string | null {
  const clocks = new Map<Operator, string>();
  for (const source of sources) {
    if (!source.ok || !source.observedAt) continue;
    clocks.set(source.operator, formatTokyoClock(new Date(source.observedAt)));
  }
  if (clocks.size === 0) return null;
  const unique = [...new Set(clocks.values())];
  if (unique.length === 1) return `${unique[0]}時点の情報`;
  return [...clocks.entries()].map(([operator, clock]) => `${operator} ${clock}時点`).join(" · ");
}
