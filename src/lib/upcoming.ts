import type { Departure } from "./types";
import {
  DAY_LABEL,
  addDays,
  dayKind,
  relativeDayLabel,
  tokyoParts,
  type DayKind,
} from "./tokyo-time";

export type TimedTrip = {
  operator: "東急バス" | "川崎市バス";
  route: string;
  destination: string;
  dayKind: DayKind;
  time: string;
};

function timeToMinutes(time: string): number {
  const [hour, minute] = time.split(":").map(Number);
  return hour * 60 + minute;
}

export function selectUpcoming(
  now: Date,
  trips: TimedTrip[],
  limit = 3,
): { today: string; serviceFinishedToday: boolean; departures: Departure[] } {
  const today = tokyoParts(now);
  const chosen: Departure[] = [];
  let sawLaterToday = false;

  for (let offset = 0; offset < 4 && chosen.length < limit; offset += 1) {
    const date = addDays(today.ymd, offset);
    const kind = dayKind(date);
    const sameDay = trips
      .filter((trip) => trip.dayKind === kind)
      .slice()
      .sort((a, b) => timeToMinutes(a.time) - timeToMinutes(b.time) || a.route.localeCompare(b.route, "ja"));
    for (const trip of sameDay) {
      if (offset === 0 && timeToMinutes(trip.time) < today.minutesOfDay) continue;
      if (offset === 0) sawLaterToday = true;
      const whenLabel = relativeDayLabel(today.ymd, date);
      chosen.push({
        id: `${date}-${trip.operator}-${trip.route}-${trip.time}-${trip.destination}`,
        operator: trip.operator,
        route: trip.route,
        destination: trip.destination,
        time: trip.time,
        date,
        dayLabel: DAY_LABEL[kind],
        whenLabel,
      });
      if (chosen.length >= limit) break;
    }
  }

  return {
    today: today.ymd,
    serviceFinishedToday: !sawLaterToday,
    departures: chosen,
  };
}
