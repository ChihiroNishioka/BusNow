import snapshot from "../data/tokyu-mizonokuchi.json";
import { fetchText } from "./http";
import { parseNavitimeDiagram, type TimetableColumns } from "./navitime";
import type { DayKind } from "./tokyo-time";

/**
 * 溝の口駅南口は溝22の始発。富士見台・蟹ヶ谷方面。
 * 公式ページ:
 * - https://transfer.navitime.biz/tokyubus/pc/diagram/BusDiagram?course=0004600046&orvCode=00240668&stopNo=1
 * - https://transfer.navitime.biz/tokyubus/pc/extif/DiagramIF?busstopCode=1750403&poleCode=05&routeCode=703101
 * 見出しは「溝22＜新作・千年・子母口住宅前経由＞ 蟹ヶ谷ゆき」、改定日は 2025-07-01。
 */
export const TOKYU_TIMETABLE_URL =
  "https://transfer.navitime.biz/tokyubus/pc/diagram/BusDiagram?course=0004600046&orvCode=00240668&stopNo=1";

const LIVE_URLS = [
  TOKYU_TIMETABLE_URL,
  "https://transfer.navitime.biz/tokyubus/pc/extif/DiagramIF?busstopCode=1750403&poleCode=05&routeCode=703101",
];

export type TokyuTimetableResult = {
  columns: TimetableColumns;
  mode: "live" | "snapshot";
  note: string | null;
};

const SNAPSHOT: TimetableColumns = {
  weekday: snapshot.weekday,
  saturday: snapshot.saturday,
  holiday: snapshot.holiday,
};

let cache: { at: number; value: TokyuTimetableResult } | null = null;

export async function loadTokyuTimetable(): Promise<TokyuTimetableResult> {
  if (cache && Date.now() - cache.at < 10 * 60 * 1000) return cache.value;
  for (const url of LIVE_URLS) {
    try {
      const html = await fetchText(url);
      if (/403 ERROR|Request blocked|cloudfront/i.test(html)) continue;
      const columns = parseNavitimeDiagram(html);
      if (columns.weekday.length < 20) continue;
      const value: TokyuTimetableResult = {
        columns,
        mode: "live",
        note: null,
      };
      cache = { at: Date.now(), value };
      return value;
    } catch {
      // try the next official URL
    }
  }
  const value: TokyuTimetableResult = {
    columns: SNAPSHOT,
    mode: "snapshot",
    note: "東急バスの時刻表サイトに接続できなかったため、公式ページ（2025年7月1日改定）から取り込んだ時刻を表示しています",
  };
  cache = { at: Date.now(), value };
  return value;
}

export function tokyuTrips(columns: TimetableColumns, kinds: DayKind[]) {
  return kinds.flatMap((dayKind) =>
    columns[dayKind].map((time) => ({
      operator: "東急バス" as const,
      route: "溝22",
      destination: "蟹ヶ谷行き",
      dayKind,
      time,
    })),
  );
}
