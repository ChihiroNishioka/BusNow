export type DayKind = "weekday" | "saturday" | "holiday";

export const DAY_LABEL: Record<DayKind, "平日" | "土曜" | "休日"> = {
  weekday: "平日",
  saturday: "土曜",
  holiday: "休日",
};

export type TokyoParts = {
  ymd: string;
  year: number;
  month: number;
  day: number;
  hour: number;
  minute: number;
  minutesOfDay: number;
};

export function tokyoParts(date: Date): TokyoParts {
  const fmt = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Tokyo",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  });
  const bag = Object.fromEntries(
    fmt.formatToParts(date).map((part) => [part.type, part.value]),
  );
  let hour = Number(bag.hour);
  if (hour === 24) hour = 0;
  const minute = Number(bag.minute);
  return {
    ymd: `${bag.year}-${bag.month}-${bag.day}`,
    year: Number(bag.year),
    month: Number(bag.month),
    day: Number(bag.day),
    hour,
    minute,
    minutesOfDay: hour * 60 + minute,
  };
}

export function addDays(ymd: string, days: number): string {
  const [year, month, day] = ymd.split("-").map(Number);
  const next = new Date(Date.UTC(year, month - 1, day + days));
  const y = next.getUTCFullYear();
  const m = String(next.getUTCMonth() + 1).padStart(2, "0");
  const d = String(next.getUTCDate()).padStart(2, "0");
  return `${y}-${m}-${d}`;
}

export function weekdayIndex(ymd: string): number {
  const [year, month, day] = ymd.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, day)).getUTCDay();
}

const WEEKDAY_JA = ["日", "月", "火", "水", "木", "金", "土"];

export function relativeDayLabel(today: string, ymd: string): string {
  if (ymd === today) return "今日";
  if (ymd === addDays(today, 1)) return "明日";
  const [, month, day] = ymd.split("-");
  return `${Number(month)}/${Number(day)}（${WEEKDAY_JA[weekdayIndex(ymd)]}）`;
}

export function formatTokyoClock(date: Date): string {
  const parts = tokyoParts(date);
  return `${parts.hour}:${String(parts.minute).padStart(2, "0")}`;
}

function nthMonday(year: number, month: number, n: number): number {
  const first = new Date(Date.UTC(year, month - 1, 1)).getUTCDay();
  const untilMonday = (1 - first + 7) % 7;
  return 1 + untilMonday + (n - 1) * 7;
}

function pad(value: number): string {
  return String(value).padStart(2, "0");
}

function ymd(year: number, month: number, day: number): string {
  return `${year}-${pad(month)}-${pad(day)}`;
}

/** Approximate vernal/autumnal equinox days used by the Japanese calendar. */
function vernalEquinoxDay(year: number): number {
  return Math.floor(
    20.8431 + 0.242194 * (year - 1980) - Math.floor((year - 1980) / 4),
  );
}

function autumnalEquinoxDay(year: number): number {
  return Math.floor(
    23.2488 + 0.242194 * (year - 1980) - Math.floor((year - 1980) / 4),
  );
}

function baseHolidays(year: number): Set<string> {
  const days = new Set<string>([
    ymd(year, 1, 1),
    ymd(year, 1, nthMonday(year, 1, 2)),
    ymd(year, 2, 11),
    ymd(year, 2, 23),
    ymd(year, 3, vernalEquinoxDay(year)),
    ymd(year, 4, 29),
    ymd(year, 5, 3),
    ymd(year, 5, 4),
    ymd(year, 5, 5),
    ymd(year, 7, nthMonday(year, 7, 3)),
    ymd(year, 8, 11),
    ymd(year, 9, nthMonday(year, 9, 3)),
    ymd(year, 9, autumnalEquinoxDay(year)),
    ymd(year, 10, nthMonday(year, 10, 2)),
    ymd(year, 11, 3),
    ymd(year, 11, 23),
  ]);
  if (year === 2019) days.add("2019-05-01");
  if (year === 2019) days.add("2019-10-22");
  if (year === 2020) days.add("2020-07-23");
  if (year === 2020) days.add("2020-07-24");
  if (year === 2021) days.add("2021-07-22");
  if (year === 2021) days.add("2021-07-23");
  return days;
}

const holidayCache = new Map<number, Set<string>>();

export function holidaysForYear(year: number): Set<string> {
  const cached = holidayCache.get(year);
  if (cached) return cached;
  const days = baseHolidays(year);
  const substituted = new Set<string>();
  let changed = true;
  let guard = 0;
  while (changed && guard < 16) {
    guard += 1;
    changed = false;
    for (const day of [...days]) {
      if (weekdayIndex(day) !== 0 || substituted.has(day)) continue;
      let cursor = addDays(day, 1);
      let steps = 0;
      while (days.has(cursor) && steps < 14) {
        cursor = addDays(cursor, 1);
        steps += 1;
      }
      if (!days.has(cursor)) days.add(cursor);
      substituted.add(day);
      changed = true;
    }
    const sorted = [...days].sort();
    for (let index = 0; index < sorted.length - 1; index += 1) {
      const between = addDays(sorted[index], 1);
      if (between === sorted[index + 1]) continue;
      if (addDays(between, 1) !== sorted[index + 1]) continue;
      if (days.has(between)) continue;
      days.add(between);
      changed = true;
    }
  }
  holidayCache.set(year, days);
  return days;
}

export function isHoliday(dateYmd: string): boolean {
  const year = Number(dateYmd.slice(0, 4));
  return holidaysForYear(year).has(dateYmd);
}

export function dayKind(dateYmd: string): DayKind {
  if (isHoliday(dateYmd) || weekdayIndex(dateYmd) === 0) return "holiday";
  if (weekdayIndex(dateYmd) === 6) return "saturday";
  return "weekday";
}
