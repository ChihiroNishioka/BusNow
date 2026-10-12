import { loadKawasakiApproach } from "./kawasaki-approach";
import { loadKawasakiDepartures } from "./kawasaki-timetable";
import { loadTokyuApproach } from "./tokyu-approach";
import { loadTokyuTimetable, tokyuTrips } from "./tokyu-timetable";
import { addDays, dayKind, tokyoParts } from "./tokyo-time";
import type { ApproachBus, ApproachPayload, DeparturePayload, SourceStatus } from "./types";
import { selectUpcoming, type TimedTrip } from "./upcoming";

function readableError(error: unknown): string {
  const message = error instanceof Error ? error.message : "";
  if (/timeout|timed out|abort/i.test(message)) {
    return "公式ページが時間内に応答しませんでした";
  }
  if (message.startsWith("HTTP ")) return "公式ページから取れませんでした";
  if (message.length > 0 && message.length <= 80) return message;
  return "うまく取れませんでした";
}

export async function loadApproach(now = new Date()): Promise<ApproachPayload> {
  const [tokyu, kawasaki] = await Promise.all([
    loadTokyuApproach(),
    loadKawasakiApproach(),
  ]);
  const buses = [...tokyu.buses, ...kawasaki.buses].sort(byArrival);
  return {
    stop: "富士見台",
    toward: "溝の口",
    fetchedAt: now.toISOString(),
    buses,
    sources: [tokyu.source, kawasaki.source],
  };
}

function byArrival(a: ApproachBus, b: ApproachBus): number {
  const am = a.minutes ?? 10_000;
  const bm = b.minutes ?? 10_000;
  return am - bm || a.route.localeCompare(b.route, "ja");
}

export async function loadDepartures(now = new Date()): Promise<DeparturePayload> {
  const today = tokyoParts(now);
  const tomorrow = addDays(today.ymd, 1);
  const kinds = [...new Set([dayKind(today.ymd), dayKind(tomorrow)])];
  const trips: TimedTrip[] = [];
  const sources: SourceStatus[] = [];

  const [tokyu, kawasaki] = await Promise.allSettled([
    loadTokyuTimetable(),
    loadKawasakiDepartures(kinds),
  ]);

  if (tokyu.status === "fulfilled") {
    trips.push(...tokyuTrips(tokyu.value.columns, kinds));
    sources.push({
      operator: "東急バス",
      ok: true,
      message: tokyu.value.note,
      updatedAt: null,
    });
  } else {
    sources.push({
      operator: "東急バス",
      ok: false,
      message: readableError(tokyu.reason),
      updatedAt: null,
    });
  }

  if (kawasaki.status === "fulfilled") {
    trips.push(...kawasaki.value);
    sources.push({
      operator: "川崎市バス",
      ok: true,
      message: null,
      updatedAt: null,
    });
  } else {
    sources.push({
      operator: "川崎市バス",
      ok: false,
      message: readableError(kawasaki.reason),
      updatedAt: null,
    });
  }

  const selected = selectUpcoming(now, trips, 3);
  return {
    stop: "溝の口駅南口",
    toward: "富士見台",
    fetchedAt: now.toISOString(),
    today: selected.today,
    serviceFinishedToday: selected.serviceFinishedToday,
    departures: selected.departures,
    sources,
  };
}
